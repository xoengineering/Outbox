import Foundation
import Testing

@testable import OutboxKit

@Suite struct BlueskyAdapterTests {
  let account = Account(
    handle: "@veganstraightedge.com",
    network: .bluesky,
    serverURL: URL(string: "https://bsky.social")!
  )

  let credential = Credential.appPassword(
    identifier: "veganstraightedge.com",
    password: "abcd-efgh-ijkl-mnop"
  )

  @Test func createsSessionThenRecord() async throws {
    let transport = FixtureTransport(stubs: [
      .init(fixtureName: "bluesky-create-session.json", statusCode: 200),
      .init(fixtureName: "bluesky-create-record.json", statusCode: 200),
    ])
    let adapter = BlueskyAdapter(now: { Date.iso8601("2026-09-18T17:32:05Z") }, transport: transport)

    let outcome = try await adapter.publish(
      OutgoingPost(body: "Happy bday to me. 🎂"),
      account: account,
      credential: credential
    )

    guard case .published(let receipt) = outcome else {
      Issue.record("Expected .published, got \(outcome)")
      return
    }
    #expect(receipt.remoteID == "at://did:plc:abc123xyz456/app.bsky.feed.post/3k7qmnop2ls25")
    #expect(
      receipt.remoteURL
        == URL(string: "https://bsky.app/profile/veganstraightedge.com/post/3k7qmnop2ls25"))

    #expect(
      transport.requests[0].url
        == URL(string: "https://bsky.social/xrpc/com.atproto.server.createSession"))
    #expect(
      transport.requests[1].url == URL(string: "https://bsky.social/xrpc/com.atproto.repo.createRecord"))

    let recordBody = try transport.requestBodyJSON(at: 1)
    #expect(recordBody["repo"] as? String == "did:plc:abc123xyz456")
    #expect(recordBody["collection"] as? String == "app.bsky.feed.post")
    let record = recordBody["record"] as? [String: Any]
    #expect(record?["$type"] as? String == "app.bsky.feed.post")
    #expect(record?["text"] as? String == "Happy bday to me. 🎂")
    #expect(record?["createdAt"] as? String == "2026-09-18T17:32:05Z")
  }

  @Test func includesLinkFacetsWithUTF8ByteOffsets() async throws {
    let transport = FixtureTransport(stubs: [
      .init(fixtureName: "bluesky-create-session.json", statusCode: 200),
      .init(fixtureName: "bluesky-create-record.json", statusCode: 200),
    ])
    let adapter = BlueskyAdapter(now: { Date.iso8601("2026-09-18T17:32:05Z") }, transport: transport)

    _ = try await adapter.publish(
      OutgoingPost(body: "🎂 https://example.com yay"),
      account: account,
      credential: credential
    )

    let record = try transport.requestBodyJSON(at: 1)["record"] as? [String: Any]
    let facets = record?["facets"] as? [[String: Any]]
    let index = facets?.first?["index"] as? [String: Any]
    #expect(index?["byteStart"] as? Int == 5)
    #expect(index?["byteEnd"] as? Int == 24)
    let features = facets?.first?["features"] as? [[String: Any]]
    #expect(features?.first?["uri"] as? String == "https://example.com")
  }

  @Test func sendsReplyRefsWhenReplying() async throws {
    let transport = FixtureTransport(stubs: [
      .init(fixtureName: "bluesky-create-session.json", statusCode: 200),
      .init(fixtureName: "bluesky-create-record.json", statusCode: 200),
    ])
    let adapter = BlueskyAdapter(now: { Date.iso8601("2026-09-18T17:32:05Z") }, transport: transport)
    let parent = RecordRef(cid: "parentcid", uri: "at://did:plc:x/app.bsky.feed.post/3parent")
    let root = RecordRef(cid: "rootcid", uri: "at://did:plc:x/app.bsky.feed.post/3root")

    _ = try await adapter.publish(
      OutgoingPost(body: "Replying!", replyTo: .bluesky(parent: parent, root: root)),
      account: account,
      credential: credential
    )

    let record = try transport.requestBodyJSON(at: 1)["record"] as? [String: Any]
    let reply = record?["reply"] as? [String: Any]
    #expect((reply?["parent"] as? [String: Any])?["uri"] as? String == parent.uri)
    #expect((reply?["root"] as? [String: Any])?["cid"] as? String == root.cid)
  }

  @Test func verifiesAppPasswordAndReturnsHandle() async throws {
    let transport = FixtureTransport(fixtureName: "bluesky-create-session.json")
    let adapter = BlueskyAdapter(transport: transport)

    let handle = try await adapter.verifyCredential(credential, serverURL: account.serverURL)

    #expect(handle == "veganstraightedge.com")
  }

  @Test func requiresAppPassword() async throws {
    let adapter = BlueskyAdapter(transport: FixtureTransport(stubs: []))

    await #expect(throws: AdapterError.missingCredential) {
      try await adapter.publish(OutgoingPost(body: "hi"), account: account, credential: .accessToken("nope"))
    }
  }
}
