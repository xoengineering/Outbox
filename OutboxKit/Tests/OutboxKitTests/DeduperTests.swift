import Foundation
import Testing

@testable import OutboxKit

@Suite struct DeduperTests {
  let baseDirectory: URL
  let store: PostStore

  init() {
    baseDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("DeduperTests-\(UUID().uuidString)", isDirectory: true)
    store = PostStore(baseDirectory: baseDirectory, timeZone: TimeZone(identifier: "UTC")!)
  }

  @Test func findsAndMergesSameContentPosts() throws {
    let mastodonCopy = Syndication(
      account: "@veganstraightedge@ruby.social",
      network: .mastodon,
      publishedAt: Date.iso8601("2026-07-31T19:28:27Z"),
      remoteID: "117"
    )
    try store.save(
      PostFile(
        body: "Same words here.\n",
        metadata: PostMetadata(
          createdAt: Date.iso8601("2026-07-31T19:28:26Z"),
          syndication: [mastodonCopy]
        )
      ))
    try store.save(
      PostFile(
        body: "Same words here.\n",
        metadata: PostMetadata(
          createdAt: Date.iso8601("2026-07-31T20:00:00Z"),
          isFavorite: true,
          targets: [Endpoint(account: "@veganstraightedge.com", network: .bluesky)]
        )
      ))
    try store.save(
      PostFile(
        body: "Different words entirely.\n",
        metadata: PostMetadata(createdAt: Date.iso8601("2026-07-31T21:00:00Z"))
      ))

    let deduper = Deduper(store: store)
    let groups = try deduper.candidateGroups()
    #expect(groups.count == 1)
    #expect(groups[0].posts.count == 2)

    let merged = try #require(try deduper.merge(groups[0]))

    #expect(merged.file.metadata.syndication.map(\.remoteID) == ["117"])
    #expect(merged.file.metadata.targets == [Endpoint(account: "@veganstraightedge.com", network: .bluesky)])
    #expect(merged.file.metadata.isFavorite)
    #expect(merged.file.metadata.createdAt == Date.iso8601("2026-07-31T19:28:26Z"))
    #expect(try store.allPosts().count == 2)
    #expect(try deduper.candidateGroups().isEmpty)
  }
}
