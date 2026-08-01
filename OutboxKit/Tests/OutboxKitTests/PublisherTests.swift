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

  @Test func writesOneFileAndAppendsSyndicationPerTarget() async throws {
    let blueskyReceipt = PublishReceipt(
      publishedAt: Date.iso8601("2026-09-18T17:32:05Z"),
      remoteID: "at://did:plc:abc/app.bsky.feed.post/3k7q",
      remoteURL: URL(string: "https://bsky.app/profile/veganstraightedge.com/post/3k7q")
    )
    let mastodonReceipt = PublishReceipt(
      publishedAt: Date.iso8601("2026-09-18T17:32:06Z"),
      remoteID: "115234567890123456",
      remoteURL: URL(string: "https://ruby.social/@veganstraightedge/115234567890123456")
    )
    let publisher = makePublisher(adapters: [
      .bluesky: StubAdapter(network: .bluesky, result: .success(.published(blueskyReceipt))),
      .mastodon: StubAdapter(network: .mastodon, result: .success(.published(mastodonReceipt))),
    ])

    let output = await publisher.publish(body: "Happy bday to me. 🎂\n", to: [blueskyTarget, mastodonTarget])

    let fileURL = try #require(output.fileURL)
    #expect(output.results.count == 2)
    let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(file.metadata.syndication.count == 2)
    #expect(file.metadata.targets.isEmpty)
    #expect(file.metadata.syndication[0].remoteID == blueskyReceipt.remoteID)
    #expect(file.metadata.syndication[1].remoteID == mastodonReceipt.remoteID)

    // Exactly one file exists in the whole archive.
    #expect(try store.allPosts().count == 1)
  }

  @Test func failedTargetStaysPendingSoRepublishRetriesIt() async throws {
    let receipt = PublishReceipt(publishedAt: Date.iso8601("2026-09-18T17:32:05Z"), remoteID: "1")
    let publisher = makePublisher(adapters: [
      .bluesky: StubAdapter(network: .bluesky, result: .failure(AdapterError.invalidResponse)),
      .mastodon: StubAdapter(network: .mastodon, result: .success(.published(receipt))),
    ])

    let output = await publisher.publish(body: "hi\n", to: [blueskyTarget, mastodonTarget])

    let fileURL = try #require(output.fileURL)
    let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(file.metadata.syndication.map(\.network) == [.mastodon])
    #expect(file.metadata.targets == [Endpoint(account: "@veganstraightedge.com", network: .bluesky)])

    // Retry just the pending target.
    let retryPublisher = makePublisher(adapters: [
      .bluesky: StubAdapter(network: .bluesky, result: .success(.published(receipt)))
    ])
    let stored = StoredPost(file: file, fileURL: fileURL)
    let retry = await retryPublisher.publishExisting(stored, to: [blueskyTarget])

    #expect(retry.results.count == 1)
    let updated = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(updated.metadata.syndication.count == 2)
    #expect(updated.metadata.targets.isEmpty)
  }

  @Test func skippedTargetStaysPending() async throws {
    let publisher = makePublisher(adapters: [.threads: ThreadsAdapter()])
    let threadsTarget = Publisher.Target(
      account: Account(
        handle: "@veganstraightedge",
        network: .threads,
        serverURL: URL(string: "https://www.threads.net")!
      ),
      credential: .none
    )

    let output = await publisher.publish(body: "hi\n", to: [threadsTarget])

    let fileURL = try #require(output.fileURL)
    let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(file.metadata.syndication.isEmpty)
    #expect(file.metadata.targets == [Endpoint(account: "@veganstraightedge", network: .threads)])
    guard case .success(.skipped) = output.results[0].outcome else {
      Issue.record("Expected .skipped outcome")
      return
    }
  }

  @Test func resolvesPerTargetReplyParents() async throws {
    let receipt = PublishReceipt(publishedAt: Date.iso8601("2026-09-18T17:32:05Z"), remoteID: "1")
    let adapter = StubAdapter(network: .mastodon, result: .success(.published(receipt)))
    let parentURL = URL(string: "https://ruby.social/@veganstraightedge/115000000000000001")!
    let publisher = makePublisher(
      adapters: [.mastodon: adapter],
      replyResolver: StubResolver(resolved: .mastodon(statusID: "115000000000000001"))
    )

    var target = mastodonTarget
    target.replyParentURL = parentURL
    let output = await publisher.publish(
      body: "One more thing.\n",
      inReplyToPost: "2026/09/18/01-happy-bday-to-me.md",
      to: [target]
    )

    let fileURL = try #require(output.fileURL)
    let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(file.metadata.inReplyToPost == "2026/09/18/01-happy-bday-to-me.md")
    #expect(adapter.receivedPosts.first?.replyTo == .mastodon(statusID: "115000000000000001"))
  }

  @Test func saveDraftWritesOneFileWithoutAdapters() throws {
    let publisher = makePublisher(adapters: [:])

    let output = publisher.saveDraft(body: "Draft only\n", for: [blueskyTarget, mastodonTarget])

    let fileURL = try #require(output.fileURL)
    let file = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(file.metadata.syndication.isEmpty)
    #expect(file.metadata.targets.count == 2)
    #expect(try store.allPosts().count == 1)
  }

  private func makePublisher(
    adapters: [Network: any SocialServiceAdapter],
    replyResolver: any ReplyResolving = StubResolver(resolved: nil)
  ) -> Publisher {
    Publisher(
      adapters: adapters,
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
