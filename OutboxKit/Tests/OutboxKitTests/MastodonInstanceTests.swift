import Foundation
import Testing

@testable import OutboxKit

@Suite struct MastodonInstanceTests {
  @Test func readsMaximumCharacters() async {
    let transport = FixtureTransport(fixtureName: "mastodon-instance.json")
    let instance = MastodonInstance(transport: transport)

    let maximum = await instance.maximumCharacters(on: URL(string: "https://ruby.social")!)

    #expect(maximum == 5000)
    #expect(transport.requests[0].url == URL(string: "https://ruby.social/api/v2/instance"))
  }

  @Test func returnsNilOnServerError() async {
    let transport = FixtureTransport(fixtureName: "mastodon-error-unauthorized.json", statusCode: 500)
    let instance = MastodonInstance(transport: transport)

    let maximum = await instance.maximumCharacters(on: URL(string: "https://ruby.social")!)

    #expect(maximum == nil)
  }
}
