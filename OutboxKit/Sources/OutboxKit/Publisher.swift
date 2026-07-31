import Foundation

/// File-first publishing: every post is written to the local archive before any
/// network call, and updated in place with the receipt after syndication.
public struct Publisher: Sendable {
  private let adapters: [Network: any SocialServiceAdapter]
  private let now: @Sendable () -> Date
  private let store: PostStore

  public init(
    adapters: [Network: any SocialServiceAdapter],
    now: @escaping @Sendable () -> Date = { Date() },
    store: PostStore
  ) {
    self.adapters = adapters
    self.now = now
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
  /// always exists even when the network fails.
  public func publish(body: String, to targets: [Target]) async -> [TargetResult] {
    var results: [TargetResult] = []
    for target in targets {
      results.append(await publish(body: body, to: target))
    }
    return results
  }

  private func publish(body: String, to target: Target) async -> TargetResult {
    var file = PostFile(
      body: body,
      metadata: PostMetadata(
        account: target.account.handle,
        createdAt: now(),
        network: target.account.network
      )
    )

    let fileURL: URL
    do {
      fileURL = try store.save(file)
    } catch {
      return TargetResult(account: target.account, fileURL: nil, outcome: .failure(error))
    }

    guard let adapter = adapters[target.account.network] else {
      let outcome = PublishOutcome.skipped(reason: "No adapter for \(target.account.network.displayName).")
      return TargetResult(account: target.account, fileURL: fileURL, outcome: .success(outcome))
    }

    do {
      let outcome = try await adapter.publish(body: body, account: target.account, credential: target.credential)
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
}
