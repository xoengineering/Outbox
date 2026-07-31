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
    let older = draft(body: "First post\n", createdAt: "2026-09-17T10:00:00Z")
    let newer = draft(body: "Second post\n", createdAt: "2026-09-18T10:00:00Z")
    try store.save(older)
    try store.save(newer)

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

  @Test func roundTripsReplyAndCompositionFields() throws {
    let text = try #require(
      Bundle.module.url(forResource: "mastodon-reply-draft.md", withExtension: nil, subdirectory: "Fixtures")
        .map { try String(contentsOf: $0, encoding: .utf8) })
    let file = try PostFile.parse(text)

    #expect(file.metadata.compositionID == UUID(uuidString: "0B426700-2C1A-4E9F-8D5B-111122223333"))
    #expect(file.metadata.inReplyTo == URL(string: "https://ruby.social/@someone/115000000000000001"))
    #expect(try file.serialized() == text)
  }

  private func draft(body: String, createdAt: String) -> PostFile {
    PostFile(
      body: body,
      metadata: PostMetadata(
        account: "@veganstraightedge.com",
        createdAt: Date.iso8601(createdAt),
        network: .bluesky
      )
    )
  }
}
