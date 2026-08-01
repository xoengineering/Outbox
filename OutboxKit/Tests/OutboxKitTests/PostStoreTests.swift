import Foundation
import Testing

@testable import OutboxKit

@Suite struct PostStoreTests {
  let baseDirectory: URL
  let store: PostStore

  init() throws {
    baseDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("OutboxKitTests-\(UUID().uuidString)", isDirectory: true)
    store = PostStore(baseDirectory: baseDirectory, timeZone: TimeZone(identifier: "UTC")!)
  }

  @Test func savesUnderDatePath() throws {
    let url = try store.save(draft())

    let expectedPath = "2026/09/18/01-happy-bday-to-me.md"
    #expect(url == baseDirectory.appendingPathComponent(expectedPath))
    #expect(store.relativePath(of: url) == expectedPath)
    #expect(try PostFile.parse(String(contentsOf: url, encoding: .utf8)) == draft())
  }

  @Test func numbersMultiplePostsOnTheSameDay() throws {
    let firstURL = try store.save(draft(body: "Happy bday to me. 🎂\n"))
    let secondURL = try store.save(draft(body: "Blowing out candles now.\n"))

    #expect(firstURL.lastPathComponent == "01-happy-bday-to-me.md")
    #expect(secondURL.lastPathComponent == "02-blowing-out-candles-now.md")
  }

  @Test func overwritesInPlaceWhenGivenExistingURL() throws {
    var file = draft()
    let url = try store.save(file)

    file.metadata.syndication.append(
      Syndication(
        account: "@veganstraightedge.com",
        network: .bluesky,
        publishedAt: Date.iso8601("2026-09-18T17:32:05Z"),
        remoteID: "at://did:plc:abc/app.bsky.feed.post/3k7q"
      ))
    file.metadata.targets.removeAll()
    try store.save(file, to: url)

    let reloaded = try PostFile.parse(String(contentsOf: url, encoding: .utf8))
    #expect(reloaded.metadata.isPublished)
    #expect(reloaded.metadata.targets.isEmpty)
    let siblings = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
    #expect(siblings == ["01-happy-bday-to-me.md"])
  }

  private func draft(body: String = "Happy bday to me. 🎂\n") -> PostFile {
    PostFile(
      body: body,
      metadata: PostMetadata(
        createdAt: Date.iso8601("2026-09-18T17:32:00Z"),
        targets: [Endpoint(account: "@veganstraightedge.com", network: .bluesky)]
      )
    )
  }
}
