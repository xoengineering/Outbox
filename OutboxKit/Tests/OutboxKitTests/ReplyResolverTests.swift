import Foundation
import Testing

@testable import OutboxKit

@Suite struct ReplyResolverTests {
  let blueskyAccount = Account(
    handle: "@veganstraightedge.com",
    network: .bluesky,
    serverURL: URL(string: "https://bsky.social")!
  )

  let mastodonAccount = Account(
    handle: "@veganstraightedge@ruby.social",
    network: .mastodon,
    serverURL: URL(string: "https://ruby.social")!
  )

  @Test func resolvesMastodonURLThroughSearch() async throws {
    let transport = FixtureTransport(fixtureName: "mastodon-search-status.json")
    let resolver = ReplyResolver(transport: transport)
    let url = URL(string: "https://other.instance/@someone/115000000000000001")!

    let resolved = try await resolver.resolve(url, account: mastodonAccount, credential: .accessToken("token"))

    #expect(resolved == .mastodon(statusID: "115000000000000001"))
    let request = transport.requests[0]
    #expect(request.url!.path == "/api/v2/search")
    #expect(request.url!.query()!.contains("resolve=true"))
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
  }

  @Test func resolvesBlueskyURLToRecordRefs() async throws {
    let transport = FixtureTransport(stubs: [
      .init(fixtureName: "bluesky-resolve-handle.json", statusCode: 200),
      .init(fixtureName: "bluesky-get-record.json", statusCode: 200),
    ])
    let resolver = ReplyResolver(transport: transport)
    let url = URL(string: "https://bsky.app/profile/someoneelse.com/post/3parent111")!

    let resolved = try await resolver.resolve(url, account: blueskyAccount, credential: .none)

    let expectedRef = RecordRef(
      cid: "bafyreiparentcid1111111111111111111111111111111111111111",
      uri: "at://did:plc:someoneelse111222333/app.bsky.feed.post/3parent111"
    )
    #expect(resolved == .bluesky(parent: expectedRef, root: expectedRef))
    #expect(transport.requests[0].url!.path == "/xrpc/com.atproto.identity.resolveHandle")
    #expect(transport.requests[1].url!.path == "/xrpc/com.atproto.repo.getRecord")
  }

  @Test func propagatesThreadRootWhenParentIsAReply() async throws {
    let transport = FixtureTransport(stubs: [
      .init(fixtureName: "bluesky-resolve-handle.json", statusCode: 200),
      .init(fixtureName: "bluesky-get-record-in-thread.json", statusCode: 200),
    ])
    let resolver = ReplyResolver(transport: transport)
    let url = URL(string: "https://bsky.app/profile/someoneelse.com/post/3parent222")!

    let resolved = try await resolver.resolve(url, account: blueskyAccount, credential: .none)

    guard case .bluesky(let parent, let root) = resolved else {
      Issue.record("Expected .bluesky, got \(String(describing: resolved))")
      return
    }
    #expect(parent.uri.hasSuffix("3parent222"))
    #expect(root.uri.hasSuffix("3root000"))
  }

  @Test func rejectsNonPostURLsForBluesky() async {
    let resolver = ReplyResolver(transport: FixtureTransport(stubs: []))
    let url = URL(string: "https://bsky.app/profile/someoneelse.com")!

    await #expect(throws: AdapterError.self) {
      try await resolver.resolve(url, account: blueskyAccount, credential: .none)
    }
  }

  @Test func threadsResolvesToNil() async throws {
    let resolver = ReplyResolver(transport: FixtureTransport(stubs: []))
    let account = Account(
      handle: "@veganstraightedge",
      network: .threads,
      serverURL: URL(string: "https://www.threads.net")!
    )

    let resolved = try await resolver.resolve(
      URL(string: "https://www.threads.net/@someone/post/abc")!,
      account: account,
      credential: .none
    )

    #expect(resolved == nil)
  }
}
