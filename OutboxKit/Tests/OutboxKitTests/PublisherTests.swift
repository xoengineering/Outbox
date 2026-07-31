import Foundation
import Testing

@testable import OutboxKit

@Suite struct PublisherTests {
  let baseDirectory: URL
  let store: PostStore

  init() {
    baseDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PublisherTests-\(UUID().uuidString)", isDirectory: true)
    store = PostStore(baseDirectory: baseDirectory, timeZone: TimeZone(identifier: "UTC")!)
  }

  @Test func writesFileThenUpdatesItWithReceipt() async throws {
    let receipt = PublishReceipt(
      publishedAt: Date.iso8601("2026-09-18T17:32:05Z"),
      remoteID: "at://did:plc:abc/app.bsky.feed.post/3k7q",
      remoteURL: URL(string: "https://bsky.app/profile/veganstraightedge.com/post/3k7q")
    )
    let publisher = Publisher(
      adapters: [.bluesky: StubAdapter(network: .bluesky, result: .success(.published(receipt)))],
      now: { Date.iso8601("2026-09-18T17:32:00Z") },
      store: store
    )

    let results = await publisher.publish(body: "Happy bday to me. 🎂\n", to: [blueskyTarget])

    #expect(results.count == 1)
    let fileURL = try #require(results[0].fileURL)
    let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(file.metadata.publishedAt == receipt.publishedAt)
    #expect(file.metadata.remoteID == receipt.remoteID)
    #expect(file.metadata.remoteURL == receipt.remoteURL)
  }

  @Test func keepsLocalFileWhenNetworkFails() async throws {
    let publisher = Publisher(
      adapters: [.bluesky: StubAdapter(network: .bluesky, result: .failure(AdapterError.invalidResponse))],
      now: { Date.iso8601("2026-09-18T17:32:00Z") },
      store: store
    )

    let results = await publisher.publish(body: "Happy bday to me. 🎂\n", to: [blueskyTarget])

    let fileURL = try #require(results[0].fileURL)
    let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(file.metadata.publishedAt == nil)
    guard case .failure = results[0].outcome else {
      Issue.record("Expected .failure outcome")
      return
    }
  }

  @Test func oneFailingTargetDoesNotBlockOthers() async throws {
    let receipt = PublishReceipt(publishedAt: Date.iso8601("2026-09-18T17:32:05Z"), remoteID: "1")
    let publisher = Publisher(
      adapters: [
        .bluesky: StubAdapter(network: .bluesky, result: .failure(AdapterError.invalidResponse)),
        .mastodon: StubAdapter(network: .mastodon, result: .success(.published(receipt))),
      ],
      now: { Date.iso8601("2026-09-18T17:32:00Z") },
      store: store
    )

    let mastodonTarget = Publisher.Target(
      account: Account(
        handle: "@veganstraightedge@ruby.social",
        network: .mastodon,
        serverURL: URL(string: "https://ruby.social")!
      ),
      credential: .accessToken("token")
    )

    let results = await publisher.publish(body: "hi\n", to: [blueskyTarget, mastodonTarget])

    guard case .failure = results[0].outcome else {
      Issue.record("Expected first target to fail")
      return
    }
    guard case .success(.published) = results[1].outcome else {
      Issue.record("Expected second target to publish")
      return
    }
  }

  private var blueskyTarget: Publisher.Target {
    Publisher.Target(
      account: Account(
        handle: "@veganstraightedge.com",
        network: .bluesky,
        serverURL: URL(string: "https://bsky.social")!
      ),
      credential: .appPassword(identifier: "veganstraightedge.com", password: "pw")
    )
  }
}

private struct StubAdapter: SocialServiceAdapter {
  var network: Network
  var result: Result<PublishOutcome, AdapterError>

  func publish(body: String, account: Account, credential: Credential) async throws -> PublishOutcome {
    try result.get()
  }
}
