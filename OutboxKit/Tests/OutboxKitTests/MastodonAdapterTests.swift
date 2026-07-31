import Foundation
import Testing

@testable import OutboxKit

@Suite struct MastodonAdapterTests {
  let account = Account(
    handle: "@veganstraightedge@ruby.social",
    network: .mastodon,
    serverURL: URL(string: "https://ruby.social")!
  )

  @Test func publishesStatusAndReturnsReceipt() async throws {
    let transport = FixtureTransport(fixtureName: "mastodon-status-created.json")
    let adapter = MastodonAdapter(transport: transport)

    let outcome = try await adapter.publish(
      body: "Happy bday to me. 🎂",
      account: account,
      credential: .accessToken("token-123")
    )

    guard case .published(let receipt) = outcome else {
      Issue.record("Expected .published, got \(outcome)")
      return
    }
    #expect(receipt.remoteID == "115234567890123456")
    #expect(receipt.remoteURL == URL(string: "https://ruby.social/@veganstraightedge/115234567890123456"))

    let request = transport.requests[0]
    #expect(request.url == URL(string: "https://ruby.social/api/v1/statuses"))
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
    let body = try transport.requestBodyJSON(at: 0)
    #expect(body["status"] as? String == "Happy bday to me. 🎂")
  }

  @Test func throwsOnHTTPError() async throws {
    let transport = FixtureTransport(fixtureName: "mastodon-error-unauthorized.json", statusCode: 401)
    let adapter = MastodonAdapter(transport: transport)

    await #expect(throws: AdapterError.self) {
      try await adapter.publish(body: "hi", account: account, credential: .accessToken("bad"))
    }
  }

  @Test func requiresAccessToken() async throws {
    let adapter = MastodonAdapter(transport: FixtureTransport(stubs: []))

    await #expect(throws: AdapterError.missingCredential) {
      try await adapter.publish(body: "hi", account: account, credential: .none)
    }
  }
}
