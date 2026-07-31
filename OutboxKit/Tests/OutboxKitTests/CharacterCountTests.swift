import Testing

@testable import OutboxKit

@Suite struct CharacterCountTests {
  @Test func plainTextCountsMatchAcrossNetworks() {
    let text = "Happy bday to me."
    #expect(CharacterCount.count(text, for: .bluesky) == 17)
    #expect(CharacterCount.count(text, for: .mastodon) == 17)
    #expect(CharacterCount.count(text, for: .threads) == 17)
  }

  @Test func defaultLimits() {
    #expect(CharacterCount.limit(for: .bluesky) == 300)
    #expect(CharacterCount.limit(for: .mastodon) == 500)
    #expect(CharacterCount.limit(for: .threads) == 500)
  }

  @Test func remainingSubtractsFromLimit() {
    #expect(CharacterCount.remaining("12345", for: .bluesky) == 295)
  }

  @Test func blueskyCountsGraphemeClusters() {
    #expect(CharacterCount.count("👨‍👩‍👧 party", for: .bluesky) == 7)
  }

  @Test func mastodonCountsEveryURLAsTwentyThree() {
    let text = "Read https://example.com/a/very/long/path/that/goes/on/forever now"
    #expect(CharacterCount.count(text, for: .mastodon) == 5 + 23 + 4)
  }

  @Test func mastodonCountsOnlyLocalPartOfMentions() {
    let text = "hi @veganstraightedge@ruby.social"
    #expect(CharacterCount.count(text, for: .mastodon) == 3 + "@veganstraightedge".count)
  }

  @Test func blueskyCountsFullURLLength() {
    let url = "https://example.com/path"
    #expect(CharacterCount.count(url, for: .bluesky) == url.count)
  }
}
