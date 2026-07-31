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

  @Test func savesUnderNetworkAccountAndDatePath() throws {
    let file = draft(account: "@veganstraightedge@ruby.social", network: .mastodon)
    let url = try store.save(file)

    let expectedPath = "Mastodon/@veganstraightedge@ruby.social/2026/09/18/happy-bday-to-me-1.md"
    #expect(url == baseDirectory.appendingPathComponent(expectedPath))
    #expect(try PostFile.parse(String(contentsOf: url, encoding: .utf8)) == file)
  }

  @Test func numbersMultiplePostsOnTheSameDay() throws {
    let first = draft(body: "Happy bday to me. 🎂\n")
    let second = draft(body: "Blowing out candles now.\n")

    let firstURL = try store.save(first)
    let secondURL = try store.save(second)

    #expect(firstURL.lastPathComponent == "happy-bday-to-me-1.md")
    #expect(secondURL.lastPathComponent == "blowing-out-candles-now-2.md")
  }

  @Test func overwritesInPlaceWhenGivenExistingURL() throws {
    var file = draft()
    let url = try store.save(file)

    file.metadata.publishedAt = Date.iso8601("2026-09-18T17:32:05Z")
    try store.save(file, to: url)

    let reloaded = try PostFile.parse(String(contentsOf: url, encoding: .utf8))
    #expect(reloaded.metadata.publishedAt == Date.iso8601("2026-09-18T17:32:05Z"))
    let siblings = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
    #expect(siblings == ["happy-bday-to-me-1.md"])
  }

  private func draft(
    account: String = "@veganstraightedge.com",
    body: String = "Happy bday to me. 🎂\n",
    network: Network = .bluesky
  ) -> PostFile {
    let metadata = PostMetadata(
      account: account,
      createdAt: Date.iso8601("2026-09-18T17:32:00Z"),
      network: network
    )
    return PostFile(body: body, metadata: metadata)
  }
}
