import Foundation
import Testing

@testable import OutboxKit

@Suite struct PostFileTests {
  @Test func parsesPublishedFixture() throws {
    let file = try PostFile.parse(try fixture("post-published.md"))

    #expect(file.metadata.createdAt == Date.iso8601("2026-09-18T17:32:00Z"))
    #expect(file.metadata.targets.isEmpty)
    #expect(file.metadata.syndication.count == 2)

    let mastodon = file.metadata.syndication[0]
    #expect(mastodon.network == .mastodon)
    #expect(mastodon.account == "@veganstraightedge@ruby.social")
    #expect(mastodon.publishedAt == Date.iso8601("2026-09-18T17:32:05Z"))
    #expect(mastodon.remoteID == "115234567890123456")
    #expect(mastodon.remoteURL == URL(string: "https://ruby.social/@veganstraightedge/115234567890123456"))
    #expect(mastodon.text == nil)

    let bluesky = file.metadata.syndication[1]
    #expect(bluesky.network == .bluesky)
    #expect(bluesky.text == "Happy bday to me. 🎂\nThirty-nine laps around the sun.")

    #expect(file.body == "Happy bday to me. 🎂\n\nThirty-nine laps around the sun.\n")
  }

  @Test func parsesDraftFixtureWithTargets() throws {
    let file = try PostFile.parse(try fixture("post-draft.md"))

    #expect(file.metadata.isFavorite)
    #expect(file.metadata.syndication.isEmpty)
    #expect(
      file.metadata.targets == [
        Endpoint(account: "@veganstraightedge.com", network: .bluesky),
        Endpoint(account: "@veganstraightedge", network: .threads),
      ])
    #expect(file.body == "Happy bday to me. 🎂\n")
  }

  @Test func parsesReplyReferences() throws {
    let thread = try PostFile.parse(try fixture("post-thread-reply.md"))
    #expect(thread.metadata.inReplyToPost == "2026/09/18/01-happy-bday-to-me.md")
    #expect(thread.metadata.inReplyTo == nil)

    let external = try PostFile.parse(try fixture("post-external-reply.md"))
    #expect(external.metadata.inReplyTo == URL(string: "https://ruby.social/@someone/115000000000000001"))
    #expect(external.metadata.inReplyToPost == nil)
  }

  @Test func roundTripsAllFixturesExactly() throws {
    for name in ["post-published.md", "post-draft.md", "post-thread-reply.md", "post-external-reply.md"] {
      let text = try fixture(name)
      let file = try PostFile.parse(text)
      #expect(try file.serialized() == text, "byte-stable round trip failed for \(name)")
    }
  }

  @Test func rejectsLegacyPerCopyFormat() throws {
    let legacy = try fixture("Legacy/legacy-mastodon-published.md")
    #expect(throws: PostFile.ParseError.legacyFormat) {
      try PostFile.parse(legacy)
    }
  }

  @Test func parseRejectsTextWithoutFrontmatter() {
    #expect(throws: PostFile.ParseError.self) {
      try PostFile.parse("Just a body, no frontmatter.\n")
    }
  }

  private func fixture(_ name: String) throws -> String {
    let parts = name.split(separator: "/").map(String.init)
    let subdirectory = (["Fixtures"] + parts.dropLast()).joined(separator: "/")
    let url = try #require(
      Bundle.module.url(forResource: parts.last!, withExtension: nil, subdirectory: subdirectory))
    return try String(contentsOf: url, encoding: .utf8)
  }
}

extension Date {
  static func iso8601(_ string: String) -> Date {
    ISO8601DateFormatter().date(from: string)!
  }
}
