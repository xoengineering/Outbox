import Foundation
import Testing

@testable import OutboxKit

@Suite struct PostFileTests {
  @Test func parsesPublishedFixture() throws {
    let text = try fixture("mastodon-published.md")
    let file = try PostFile.parse(text)

    #expect(file.metadata.network == .mastodon)
    #expect(file.metadata.account == "@veganstraightedge@ruby.social")
    #expect(file.metadata.createdAt == Date.iso8601("2026-09-18T17:32:00Z"))
    #expect(file.metadata.publishedAt == Date.iso8601("2026-09-18T17:32:05Z"))
    #expect(file.metadata.remoteID == "115234567890123456")
    #expect(
      file.metadata.remoteURL
        == URL(string: "https://ruby.social/@veganstraightedge/115234567890123456"))
    #expect(file.body == "Happy bday to me. 🎂\n\nThirty-nine laps around the sun.\n")
  }

  @Test func parsesDraftFixtureWithoutPublicationFields() throws {
    let text = try fixture("bluesky-draft.md")
    let file = try PostFile.parse(text)

    #expect(file.metadata.network == .bluesky)
    #expect(file.metadata.account == "@veganstraightedge.com")
    #expect(file.metadata.publishedAt == nil)
    #expect(file.metadata.remoteID == nil)
    #expect(file.metadata.remoteURL == nil)
    #expect(file.body == "Happy bday to me. 🎂\n")
  }

  @Test func roundTripsThroughSerialization() throws {
    let original = try PostFile.parse(try fixture("mastodon-published.md"))
    let reparsed = try PostFile.parse(try original.serialized())

    #expect(reparsed == original)
  }

  @Test func serializedDraftMatchesFixtureExactly() throws {
    let metadata = PostMetadata(
      account: "@veganstraightedge.com",
      createdAt: Date.iso8601("2026-09-18T17:32:00Z"),
      network: .bluesky
    )
    let file = PostFile(body: "Happy bday to me. 🎂\n", metadata: metadata)

    #expect(try file.serialized() == (try fixture("bluesky-draft.md")))
  }

  @Test func parseRejectsTextWithoutFrontmatter() {
    #expect(throws: PostFile.ParseError.self) {
      try PostFile.parse("Just a body, no frontmatter.\n")
    }
  }

  private func fixture(_ name: String) throws -> String {
    let url = try #require(
      Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    return try String(contentsOf: url, encoding: .utf8)
  }
}

extension Date {
  static func iso8601(_ string: String) -> Date {
    ISO8601DateFormatter().date(from: string)!
  }
}
