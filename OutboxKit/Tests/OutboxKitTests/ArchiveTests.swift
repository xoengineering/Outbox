import Foundation
import Testing

@testable import OutboxKit

@Suite struct ArchiveTests {
  let baseDirectory: URL
  let store: PostStore

  init() {
    baseDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ArchiveTests-\(UUID().uuidString)", isDirectory: true)
    store = PostStore(baseDirectory: baseDirectory, timeZone: TimeZone(identifier: "UTC")!)
  }

  @Test func readsAllPostsNewestFirst() throws {
    try store.save(draft(body: "First post\n", createdAt: "2026-09-17T10:00:00Z"))
    try store.save(draft(body: "Second post\n", createdAt: "2026-09-18T10:00:00Z"))

    let posts = try store.allPosts()

    #expect(posts.map(\.file.body) == ["Second post\n", "First post\n"])
    #expect(posts[0].status == .draft)
  }

  @Test func emptyArchiveReadsAsEmpty() throws {
    #expect(try store.allPosts() == [])
  }

  @Test func skipsUnparseableFiles() throws {
    try store.save(draft(body: "Good post\n", createdAt: "2026-09-18T10:00:00Z"))
    let strayURL = baseDirectory.appendingPathComponent("stray.md")
    try "no frontmatter here".write(to: strayURL, atomically: true, encoding: .utf8)

    let posts = try store.allPosts()

    #expect(posts.count == 1)
    #expect(FileManager.default.fileExists(atPath: strayURL.path))
  }

  @Test func deleteRemovesTheFile() throws {
    try store.save(draft(body: "Doomed\n", createdAt: "2026-09-18T10:00:00Z"))
    let post = try #require(try store.allPosts().first)

    try store.delete(post)

    #expect(try store.allPosts() == [])
  }

  @Test func roundTripsFavoriteFlag() throws {
    var file = draft(body: "A keeper\n", createdAt: "2026-09-18T10:00:00Z")
    file.metadata.isFavorite = true
    let url = try store.save(file)

    let reloaded = try PostFile.parse(String(contentsOf: url, encoding: .utf8))
    #expect(reloaded.metadata.isFavorite)

    var unfavorited = reloaded
    unfavorited.metadata.isFavorite = false
    #expect(try !unfavorited.serialized().contains("favorite:"))
  }

  private func draft(body: String, createdAt: String) -> PostFile {
    PostFile(
      body: body,
      metadata: PostMetadata(
        createdAt: Date.iso8601(createdAt),
        targets: [Endpoint(account: "@veganstraightedge.com", network: .bluesky)]
      )
    )
  }
}
