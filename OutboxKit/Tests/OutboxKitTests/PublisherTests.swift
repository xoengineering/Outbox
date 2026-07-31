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
    let publisher = makePublisher(
      adapters: [.bluesky: StubAdapter(network: .bluesky, result: .success(.published(receipt)))]
    )

    let results = await publisher.publish(body: "Happy bday to me. 🎂\n", to: [blueskyTarget])

    #expect(results.count == 1)
    let fileURL = try #require(results[0].fileURL)
    let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(file.metadata.publishedAt == receipt.publishedAt)
    #expect(file.metadata.remoteID == receipt.remoteID)
    #expect(file.metadata.remoteURL == receipt.remoteURL)
    #expect(file.metadata.compositionID == nil)
  }

  @Test func keepsLocalFileWhenNetworkFails() async throws {
    let publisher = makePublisher(
      adapters: [.bluesky: StubAdapter(network: .bluesky, result: .failure(AdapterError.invalidResponse))]
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
    let publisher = makePublisher(
      adapters: [
        .bluesky: StubAdapter(network: .bluesky, result: .failure(AdapterError.invalidResponse)),
        .mastodon: StubAdapter(network: .mastodon, result: .success(.published(receipt))),
      ]
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

  @Test func crosspostsShareOneCompositionID() async throws {
    let receipt = PublishReceipt(publishedAt: Date.iso8601("2026-09-18T17:32:05Z"), remoteID: "1")
    let sharedID = UUID(uuidString: "0B426700-2C1A-4E9F-8D5B-111122223333")!
    let publisher = makePublisher(
      adapters: [
        .bluesky: StubAdapter(network: .bluesky, result: .success(.published(receipt))),
        .mastodon: StubAdapter(network: .mastodon, result: .success(.published(receipt))),
      ],
      makeCompositionID: { sharedID }
    )

    let results = await publisher.publish(body: "hi\n", to: [blueskyTarget, mastodonTarget])

    for result in results {
      let fileURL = try #require(result.fileURL)
      let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
      #expect(file.metadata.compositionID == sharedID)
    }
  }

  @Test func resolvesReplyURLAndPassesItToAdapter() async throws {
    let receipt = PublishReceipt(publishedAt: Date.iso8601("2026-09-18T17:32:05Z"), remoteID: "1")
    let adapter = StubAdapter(network: .mastodon, result: .success(.published(receipt)))
    let replyURL = URL(string: "https://ruby.social/@someone/115000000000000001")!
    let publisher = makePublisher(
      adapters: [.mastodon: adapter],
      replyResolver: StubResolver(resolved: .mastodon(statusID: "115000000000000001"))
    )

    let results = await publisher.publish(body: "Replying!\n", replyTo: replyURL, to: [mastodonTarget])

    let fileURL = try #require(results[0].fileURL)
    let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(file.metadata.inReplyTo == replyURL)
    #expect(adapter.receivedPosts.first?.replyTo == .mastodon(statusID: "115000000000000001"))
  }

  @Test func savesDraftsWithoutTouchingAdapters() throws {
    let publisher = makePublisher(adapters: [:])

    let results = publisher.saveDrafts(body: "Draft only\n", for: [blueskyTarget, mastodonTarget])

    #expect(results.count == 2)
    for result in results {
      let fileURL = try #require(result.fileURL)
      let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
      #expect(file.metadata.publishedAt == nil)
      #expect(file.metadata.compositionID != nil)
    }
  }

  @Test func publishExistingUpdatesTheDraftInPlace() async throws {
    let publisher = makePublisher(adapters: [:])
    let draftURL = try #require(publisher.saveDrafts(body: "Draft first\n", for: [blueskyTarget])[0].fileURL)
    let stored = StoredPost(
      file: try PostFile.parse(String(contentsOf: draftURL, encoding: .utf8)),
      fileURL: draftURL
    )

    let receipt = PublishReceipt(
      publishedAt: Date.iso8601("2026-09-18T17:32:05Z"),
      remoteID: "at://did:plc:abc/app.bsky.feed.post/3k7q"
    )
    let publishing = makePublisher(
      adapters: [.bluesky: StubAdapter(network: .bluesky, result: .success(.published(receipt)))]
    )

    let result = await publishing.publishExisting(stored, target: blueskyTarget)

    #expect(result.fileURL == draftURL)
    let file = try PostFile.parse(String(contentsOf: draftURL, encoding: .utf8))
    #expect(file.metadata.publishedAt == receipt.publishedAt)
    #expect(file.metadata.remoteID == receipt.remoteID)
  }

  private func makePublisher(
    adapters: [Network: any SocialServiceAdapter],
    makeCompositionID: @escaping @Sendable () -> UUID = { UUID() },
    replyResolver: any ReplyResolving = StubResolver(resolved: nil)
  ) -> Publisher {
    Publisher(
      adapters: adapters,
      makeCompositionID: makeCompositionID,
      now: { Date.iso8601("2026-09-18T17:32:00Z") },
      replyResolver: replyResolver,
      store: store
    )
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

  private var mastodonTarget: Publisher.Target {
    Publisher.Target(
      account: Account(
        handle: "@veganstraightedge@ruby.social",
        network: .mastodon,
        serverURL: URL(string: "https://ruby.social")!
      ),
      credential: .accessToken("token")
    )
  }
}

private final class StubAdapter: SocialServiceAdapter, @unchecked Sendable {
  let network: Network
  let result: Result<PublishOutcome, AdapterError>
  private(set) var receivedPosts: [OutgoingPost] = []

  init(network: Network, result: Result<PublishOutcome, AdapterError>) {
    self.network = network
    self.result = result
  }

  func publish(_ post: OutgoingPost, account: Account, credential: Credential) async throws -> PublishOutcome {
    receivedPosts.append(post)
    return try result.get()
  }
}

private struct StubResolver: ReplyResolving {
  var resolved: ResolvedReply?

  func resolve(_ url: URL, account: Account, credential: Credential) async throws -> ResolvedReply? {
    resolved
  }
}
