import Foundation
import Testing

@testable import OutboxKit

@Suite struct MastodonOAuthTests {
  let serverURL = URL(string: "https://ruby.social")!

  @Test func registersApp() async throws {
    let transport = FixtureTransport(fixtureName: "mastodon-app-registration.json")
    let oauth = MastodonOAuth(transport: transport)

    let registration = try await oauth.registerApp(on: serverURL)

    #expect(registration.clientID == "TWhM-tNSuncnqN7DBJmoyeLnk6K3iJJ71KKXxgL1hPM")
    #expect(registration.clientSecret == "ZEaFUFmF0umgBX1qKJDjaU99Q31lDkOU8NutzTOoBw")
    #expect(transport.requests[0].url == URL(string: "https://ruby.social/api/v1/apps"))
  }

  @Test func buildsAuthorizationURL() {
    let url = MastodonOAuth().authorizationURL(on: serverURL, clientID: "client-123")
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

    #expect(url.absoluteString.hasPrefix("https://ruby.social/oauth/authorize?"))
    let query = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) })
    #expect(query["client_id"] == "client-123")
    #expect(query["redirect_uri"] == "outbox://oauth/mastodon")
    #expect(query["response_type"] == "code")
    #expect(query["scope"] == "read:accounts write:statuses")
  }

  @Test func exchangesCodeForToken() async throws {
    let transport = FixtureTransport(fixtureName: "mastodon-token.json")
    let oauth = MastodonOAuth(transport: transport)
    let registration = MastodonOAuth.AppRegistration(clientID: "id", clientSecret: "secret")

    let token = try await oauth.exchangeCode("auth-code", on: serverURL, registration: registration)

    #expect(token == "ZA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0")
    let body = try transport.requestBodyJSON(at: 0)
    #expect(body["code"] as? String == "auth-code")
    #expect(body["grant_type"] as? String == "authorization_code")
  }

  @Test func verifiesCredentials() async throws {
    let transport = FixtureTransport(fixtureName: "mastodon-verify-credentials.json")
    let oauth = MastodonOAuth(transport: transport)

    let verified = try await oauth.verifyCredentials(on: serverURL, token: "token-123")

    #expect(verified.acct == "veganstraightedge")
    #expect(transport.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
  }
}
