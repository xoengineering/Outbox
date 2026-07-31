import Foundation

/// File-first publishing: every post is written to the local archive before any
/// network call, and updated in place with the receipt after syndication.
public struct Publisher: Sendable {
  private let adapters: [Network: any SocialServiceAdapter]
  private let makeCompositionID: @Sendable () -> UUID
  private let now: @Sendable () -> Date
  private let replyResolver: any ReplyResolving
  private let store: PostStore

  public init(
    adapters: [Network: any SocialServiceAdapter],
    makeCompositionID: @escaping @Sendable () -> UUID = { UUID() },
    now: @escaping @Sendable () -> Date = { Date() },
    replyResolver: any ReplyResolving = ReplyResolver(),
    store: PostStore
  ) {
    self.adapters = adapters
    self.makeCompositionID = makeCompositionID
    self.now = now
    self.replyResolver = replyResolver
    self.store = store
  }

  public struct Target: Sendable {
    public var account: Account
    public var credential: Credential

    public init(account: Account, credential: Credential) {
      self.account = account
      self.credential = credential
    }
  }

  public struct TargetResult: Sendable {
    public var account: Account
    public var fileURL: URL?
    public var outcome: Result<PublishOutcome, any Error>
  }

  /// Publishes one body of text to every target.
  ///
  /// A failure on one target never blocks the others, and the local file
  /// always exists even when the network fails. When there are multiple
  /// targets, every file shares one composition ID.
  public func publish(body: String, replyTo replyURL: URL? = nil, to targets: [Target]) async -> [TargetResult] {
    let compositionID = targets.count > 1 ? makeCompositionID() : nil
    var results: [TargetResult] = []
    for target in targets {
      results.append(await publish(body: body, compositionID: compositionID, replyURL: replyURL, to: target))
    }
    return results
  }

  /// Writes drafts for every target without touching the network.
  public func saveDrafts(body: String, replyTo replyURL: URL? = nil, for targets: [Target]) -> [TargetResult] {
    let compositionID = targets.count > 1 ? makeCompositionID() : nil
    return targets.map { target in
      let file = draftFile(body: body, compositionID: compositionID, replyURL: replyURL, target: target)
      do {
        let fileURL = try store.save(file)
        return TargetResult(account: target.account, fileURL: fileURL, outcome: .success(.skipped(reason: "Saved as draft.")))
      } catch {
        return TargetResult(account: target.account, fileURL: nil, outcome: .failure(error))
      }
    }
  }

  /// Publishes a post that already exists on disk (a draft), updating it in place.
  public func publishExisting(_ stored: StoredPost, target: Target) async -> TargetResult {
    await syndicate(file: stored.file, at: stored.fileURL, target: target)
  }

  private func publish(
    body: String,
    compositionID: UUID?,
    replyURL: URL?,
    to target: Target
  ) async -> TargetResult {
    let file = draftFile(body: body, compositionID: compositionID, replyURL: replyURL, target: target)

    let fileURL: URL
    do {
      fileURL = try store.save(file)
    } catch {
      return TargetResult(account: target.account, fileURL: nil, outcome: .failure(error))
    }

    return await syndicate(file: file, at: fileURL, target: target)
  }

  private func syndicate(file: PostFile, at fileURL: URL, target: Target) async -> TargetResult {
    var file = file
    guard let adapter = adapters[target.account.network] else {
      let outcome = PublishOutcome.skipped(reason: "No adapter for \(target.account.network.displayName).")
      return TargetResult(account: target.account, fileURL: fileURL, outcome: .success(outcome))
    }

    do {
      var resolvedReply: ResolvedReply?
      if let replyURL = file.metadata.inReplyTo {
        resolvedReply = try await replyResolver.resolve(
          replyURL,
          account: target.account,
          credential: target.credential
        )
      }

      let outgoing = OutgoingPost(body: file.body, replyTo: resolvedReply)
      let outcome = try await adapter.publish(outgoing, account: target.account, credential: target.credential)
      if case .published(let receipt) = outcome {
        file.metadata.publishedAt = receipt.publishedAt
        file.metadata.remoteID = receipt.remoteID
        file.metadata.remoteURL = receipt.remoteURL
        try store.save(file, to: fileURL)
      }
      return TargetResult(account: target.account, fileURL: fileURL, outcome: .success(outcome))
    } catch {
      return TargetResult(account: target.account, fileURL: fileURL, outcome: .failure(error))
    }
  }

  private func draftFile(body: String, compositionID: UUID?, replyURL: URL?, target: Target) -> PostFile {
    PostFile(
      body: body,
      metadata: PostMetadata(
        account: target.account.handle,
        compositionID: compositionID,
        createdAt: now(),
        inReplyTo: replyURL,
        network: target.account.network
      )
    )
  }
}
