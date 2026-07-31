/// Stub for Threads. The UI shows the endpoint, but publishing no-ops:
/// the local file is still written; nothing is sent anywhere.
public struct ThreadsAdapter: SocialServiceAdapter {
  public init() {}

  public var network: Network { .threads }

  public func publish(body: String, account: Account, credential: Credential) async throws -> PublishOutcome {
    .skipped(reason: "Threads publishing is not wired up yet — the post was saved locally only.")
  }
}
