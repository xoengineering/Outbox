import Foundation

/// File-first publishing: one canonical Post file is written before any network
/// call, then each successful copy moves from `targets` into `syndication`.
public struct Publisher: Sendable {
  private let adapters: [Network: any SocialServiceAdapter]
  private let now: @Sendable () -> Date
  private let replyResolver: any ReplyResolving
  private let store: PostStore

  public init(
    adapters: [Network: any SocialServiceAdapter],
    now: @escaping @Sendable () -> Date = { Date() },
    replyResolver: any ReplyResolving = ReplyResolver(),
    store: PostStore
  ) {
    self.adapters = adapters
    self.now = now
    self.replyResolver = replyResolver
    self.store = store
  }

  public struct Target: Sendable {
    public var account: Account
    public var credential: Credential
    /// The remote post this target's copy replies to, already network-matched.
    public var replyParentURL: URL?

    public init(account: Account, credential: Credential, replyParentURL: URL? = nil) {
      self.account = account
      self.credential = credential
      self.replyParentURL = replyParentURL
    }
  }

  public struct TargetResult: Sendable {
    public var account: Account
    public var fileURL: URL?
    public var outcome: Result<PublishOutcome, any Error>
  }

  public struct Output: Sendable {
    public var fileURL: URL?
    public var results: [TargetResult]
  }

  /// Writes one Post file, then syndicates it to every target.
  ///
  /// A failure on one target never blocks the others; failed targets stay in
  /// `targets`, so re-publishing retries exactly what's missing.
  public func publish(
    body: String,
    inReplyTo: URL? = nil,
    inReplyToPost: String? = nil,
    inReplyToSnapshot: ReplySnapshot? = nil,
    to targets: [Target]
  ) async -> Output {
    var file = draftFile(
      body: body,
      inReplyTo: inReplyTo,
      inReplyToPost: inReplyToPost,
      inReplyToSnapshot: inReplyToSnapshot,
      targets: targets
    )

    let fileURL: URL
    do {
      fileURL = try store.save(file)
    } catch {
      let results = targets.map {
        TargetResult(account: $0.account, fileURL: nil, outcome: .failure(error))
      }
      return Output(fileURL: nil, results: results)
    }

    let results = await syndicate(file: &file, at: fileURL, to: targets)
    return Output(fileURL: fileURL, results: results)
  }

  /// Writes one draft Post file without touching the network.
  public func saveDraft(
    body: String,
    inReplyTo: URL? = nil,
    inReplyToPost: String? = nil,
    inReplyToSnapshot: ReplySnapshot? = nil,
    for targets: [Target]
  ) -> Output {
    let file = draftFile(
      body: body,
      inReplyTo: inReplyTo,
      inReplyToPost: inReplyToPost,
      inReplyToSnapshot: inReplyToSnapshot,
      targets: targets
    )
    do {
      let fileURL = try store.save(file)
      let results = targets.map {
        TargetResult(
          account: $0.account, fileURL: fileURL, outcome: .success(.skipped(reason: "Saved as draft.")))
      }
      return Output(fileURL: fileURL, results: results)
    } catch {
      let results = targets.map {
        TargetResult(account: $0.account, fileURL: nil, outcome: .failure(error))
      }
      return Output(fileURL: nil, results: results)
    }
  }

  /// Syndicates an existing Post (a draft, or one with pending targets),
  /// updating the file in place as copies land.
  public func publishExisting(_ stored: StoredPost, to targets: [Target]) async -> Output {
    var file = stored.file
    let results = await syndicate(file: &file, at: stored.fileURL, to: targets)
    return Output(fileURL: stored.fileURL, results: results)
  }

  // MARK: - Internals

  private func syndicate(file: inout PostFile, at fileURL: URL, to targets: [Target]) async -> [TargetResult] {
    var results: [TargetResult] = []

    for target in targets {
      let endpoint = Endpoint(account: target.account.handle, network: target.account.network)
      guard let adapter = adapters[target.account.network] else {
        let outcome = PublishOutcome.skipped(reason: "No adapter for \(target.account.network.displayName).")
        results.append(TargetResult(account: target.account, fileURL: fileURL, outcome: .success(outcome)))
        continue
      }

      do {
        var resolvedReply: ResolvedReply?
        if let replyParentURL = target.replyParentURL {
          resolvedReply = try await replyResolver.resolve(
            replyParentURL,
            account: target.account,
            credential: target.credential
          )
        }

        let outgoing = OutgoingPost(body: file.body, replyTo: resolvedReply)
        let outcome = try await adapter.publish(outgoing, account: target.account, credential: target.credential)
        if case .published(let receipt) = outcome {
          file.metadata.syndication.append(
            Syndication(
              account: target.account.handle,
              network: target.account.network,
              publishedAt: receipt.publishedAt,
              remoteID: receipt.remoteID,
              remoteURL: receipt.remoteURL
            ))
          file.metadata.targets.removeAll { $0 == endpoint }
          try store.save(file, to: fileURL)
        }
        results.append(TargetResult(account: target.account, fileURL: fileURL, outcome: .success(outcome)))
      } catch {
        results.append(TargetResult(account: target.account, fileURL: fileURL, outcome: .failure(error)))
      }
    }
    return results
  }

  private func draftFile(
    body: String,
    inReplyTo: URL?,
    inReplyToPost: String?,
    inReplyToSnapshot: ReplySnapshot?,
    targets: [Target]
  ) -> PostFile {
    PostFile(
      body: body,
      metadata: PostMetadata(
        createdAt: now(),
        inReplyTo: inReplyTo,
        inReplyToPost: inReplyToPost,
        inReplyToSnapshot: inReplyToSnapshot,
        targets: targets.map { Endpoint(account: $0.account.handle, network: $0.account.network) }
      )
    )
  }
}
