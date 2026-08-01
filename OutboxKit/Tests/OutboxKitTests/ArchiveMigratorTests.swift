import Foundation
import Testing

@testable import OutboxKit

@Suite struct ArchiveMigratorTests {
  let baseDirectory: URL
  let store: PostStore

  init() {
    baseDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MigratorTests-\(UUID().uuidString)", isDirectory: true)
    store = PostStore(baseDirectory: baseDirectory, timeZone: TimeZone(identifier: "UTC")!)
  }

  @Test func mergesLegacyCopiesIntoSinglePosts() throws {
    // Lay out the legacy tree: one published crosspost (2 copies, no composition
    // ID, same minute), one 2-copy draft composition, one solo draft.
    try copyLegacyFixture("legacy-mastodon-published.md", to: "Mastodon/@veganstraightedge@ruby.social/2026/07/31/two-by-two-hands-of-blue-5.md")
    try copyLegacyFixture("legacy-bluesky-published.md", to: "Bluesky/@veganstraightedge.com/2026/07/31/two-by-two-hands-of-blue-1.md")
    try copyLegacyFixture("legacy-draft-bluesky.md", to: "Bluesky/@veganstraightedge.com/2026/07/31/draft-3.md")
    try copyLegacyFixture("legacy-draft-mastodon.md", to: "Mastodon/@veganstraightedge@ruby.social/2026/07/31/draft-7.md")
    try copyLegacyFixture("legacy-solo-draft.md", to: "Mastodon/@veganstraightedge@ruby.social/2026/07/31/mr-hammond-the-phones-are-working-1.md")

    let migrator = ArchiveMigrator(baseDirectory: baseDirectory, store: store)
    let written = try migrator.migrateIfNeeded()

    #expect(written == 3)
    let posts = try store.allPosts()
    #expect(posts.count == 3)

    let crosspost = try #require(posts.first { $0.file.body.contains("Two by two") })
    #expect(crosspost.status == .published)
    #expect(crosspost.file.metadata.syndication.count == 2)
    #expect(crosspost.file.metadata.targets.isEmpty)
    let divergentCopy = crosspost.file.metadata.syndication.first { $0.text != nil }
    #expect(divergentCopy != nil, "the copy whose body differed keeps its sent text")

    let draft = try #require(posts.first { $0.file.body == "draft\n" })
    #expect(draft.status == .draft)
    #expect(draft.file.metadata.isFavorite, "favorite on any copy survives the merge")
    #expect(draft.file.metadata.targets.count == 2)

    let solo = try #require(posts.first { $0.file.body.contains("Mr Hammond") })
    #expect(solo.file.metadata.targets == [
      Endpoint(account: "@veganstraightedge@ruby.social", network: .mastodon)
    ])

    // Legacy tree is gone, including the emptied network directories.
    #expect(!FileManager.default.fileExists(atPath: baseDirectory.appendingPathComponent("Mastodon").path))
    #expect(!FileManager.default.fileExists(atPath: baseDirectory.appendingPathComponent("Bluesky").path))
  }

  @Test func migrationIsIdempotentOnNewArchives() throws {
    try store.save(
      PostFile(
        body: "Already new-format\n",
        metadata: PostMetadata(createdAt: Date.iso8601("2026-09-18T10:00:00Z"))
      ))

    let migrator = ArchiveMigrator(baseDirectory: baseDirectory, store: store)
    #expect(try migrator.migrateIfNeeded() == 0)
    #expect(try store.allPosts().count == 1)
  }

  private func copyLegacyFixture(_ name: String, to relativePath: String) throws {
    let source = try #require(
      Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/Legacy"))
    let destination = baseDirectory.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: source, to: destination)
  }
}
