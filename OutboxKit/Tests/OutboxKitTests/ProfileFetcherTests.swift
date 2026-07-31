import Foundation
import Testing

@testable import OutboxKit

@Suite struct ProfileFetcherTests {
  @Test func fetchesMastodonProfile() async throws {
    let transport = FixtureTransport(fixtureName: "mastodon-verify-credentials.json")
    let account = Account(
      handle: "@veganstraightedge@ruby.social",
      network: .mastodon,
      serverURL: URL(string: "https://ruby.social")!
    )

    let profile = try await ProfileFetcher(transport: transport)
      .profile(for: account, credential: .accessToken("token"))

    #expect(profile.displayName == "Shane Becker")
    #expect(profile.avatarURL?.absoluteString.hasPrefix("https://media.ruby.social") == true)
  }

  @Test func fetchesBlueskyProfileViaSession() async throws {
    let transport = FixtureTransport(stubs: [
      .init(fixtureName: "bluesky-create-session.json", statusCode: 200),
      .init(fixtureName: "bluesky-get-profile.json", statusCode: 200),
    ])
    let account = Account(
      handle: "@veganstraightedge.com",
      network: .bluesky,
      serverURL: URL(string: "https://bsky.social")!
    )

    let profile = try await ProfileFetcher(transport: transport)
      .profile(for: account, credential: .appPassword(identifier: "veganstraightedge.com", password: "pw"))

    #expect(profile.displayName == "Shane Becker")
    #expect(profile.avatarURL?.absoluteString.hasPrefix("https://cdn.bsky.app") == true)
    #expect(transport.requests[1].url!.query()!.contains("actor=did:plc:abc123xyz456"))
  }

  @Test func threadsHasNoProfileSource() async throws {
    let account = Account(
      handle: "@veganstraightedge",
      network: .threads,
      serverURL: URL(string: "https://www.threads.net")!
    )

    let profile = try await ProfileFetcher(transport: FixtureTransport(stubs: []))
      .profile(for: account, credential: .none)

    #expect(profile == ProfileInfo())
  }
}
