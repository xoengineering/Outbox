import Foundation
import Testing

@testable import OutboxKit

@Suite struct ContentExtractorTests {
  @Test func extractsHashtags() {
    let extracted = ContentExtractor.extract(from: "Loving #ruby and #OpenSource today. #ruby again")
    #expect(extracted.hashtags == ["#ruby", "#OpenSource"])
  }

  @Test func extractsMentionsWithAndWithoutDomains() {
    let extracted = ContentExtractor.extract(from: "cc @veganstraightedge@ruby.social and @someone.")
    #expect(extracted.mentions == ["@veganstraightedge@ruby.social", "@someone"])
  }

  @Test func extractsURLs() {
    let extracted = ContentExtractor.extract(from: "Read https://xo.engineering and http://example.com/a")
    #expect(
      extracted.urls == [
        URL(string: "https://xo.engineering")!,
        URL(string: "http://example.com/a")!,
      ])
  }

  @Test func emptyTextExtractsNothing() {
    let extracted = ContentExtractor.extract(from: "plain words only")
    #expect(extracted == ContentExtractor.Extracted())
  }
}
