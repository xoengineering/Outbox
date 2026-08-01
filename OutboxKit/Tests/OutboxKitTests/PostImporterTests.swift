import Foundation
import Testing

@testable import OutboxKit

@Suite struct PostImporterTests {
  let baseDirectory: URL
  let store: PostStore

  init() {
    baseDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ImporterTests-\(UUID().uuidString)", isDirectory: true)
    store = PostStore(baseDirectory: baseDirectory, timeZone: TimeZone(identifier: "UTC")!)
  }

  let mastodonAccount = Account(
    handle: "@veganstraightedge@ruby.social",
    network: .mastodon,
    serverURL: URL(string: "https://ruby.social")!
  )

  @Test func importsMastodonStatusesMergingIntoMatchingPosts() async throws {
    // One archived post matches the second remote status by body.
    try store.save(
      PostFile(
        body: "Mr Hammond, the phones are working. ☎️\n",
        metadata: PostMetadata(createdAt: Date.iso8601("2026-07-31T19:28:26Z"))
      ))

    let transport = FixtureTransport(stubs: [
      .init(fixtureName: "mastodon-verify-credentials.json", statusCode: 200),
      .init(fixtureName: "mastodon-account-statuses.json", statusCode: 200),
      .init(fixtureName: "mastodon-statuses-empty.json", statusCode: 200),
    ])
    let importer = PostImporter(store: store, transport: transport)

    let report = try await importer.importPosts(for: mastodonAccount, credential: .accessToken("token"))

    #expect(report.created == 1, "the P vs NP status becomes a new Post")
    #expect(report.merged == 1, "the Mr Hammond status merges into the archived Post")
    #expect(report.skipped == 0)

    let posts = try store.allPosts()
    #expect(posts.count == 2)
    let hammond = try #require(posts.first { $0.file.body.contains("Mr Hammond") })
    #expect(hammond.file.metadata.syndication.first?.remoteID == "117016238964723243")

    // Second run: everything already tracked.
    let repeatTransport = FixtureTransport(stubs: [
      .init(fixtureName: "mastodon-verify-credentials.json", statusCode: 200),
      .init(fixtureName: "mastodon-account-statuses.json", statusCode: 200),
      .init(fixtureName: "mastodon-statuses-empty.json", statusCode: 200),
    ])
    let repeatImporter = PostImporter(store: store, transport: repeatTransport)
    let repeatReport = try await repeatImporter.importPosts(
      for: mastodonAccount, credential: .accessToken("token"))
    #expect(repeatReport.skipped == 2)
    #expect(try store.allPosts().count == 2)
  }

  @Test func importsBlueskyFeedExcludingReposts() async throws {
    let account = Account(
      handle: "@veganstraightedge.com",
      network: .bluesky,
      serverURL: URL(string: "https://bsky.social")!
    )
    let transport = FixtureTransport(stubs: [
      .init(fixtureName: "bluesky-create-session.json", statusCode: 200),
      .init(fixtureName: "bluesky-author-feed.json", statusCode: 200),
    ])
    let importer = PostImporter(store: store, transport: transport)

    let report = try await importer.importPosts(
      for: account,
      credential: .appPassword(identifier: "veganstraightedge.com", password: "pw")
    )

    #expect(report.created == 1)
    let posts = try store.allPosts()
    #expect(posts.count == 1)
    #expect(posts[0].file.body == "Two by two, hands of blue 🙌🏻🟦\n")
    let copy = try #require(posts[0].file.metadata.syndication.first)
    #expect(copy.remoteURL?.absoluteString.hasSuffix("post/3mrxphbwwuf22") == true)
  }
}
