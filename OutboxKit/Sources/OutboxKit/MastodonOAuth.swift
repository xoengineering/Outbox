import Foundation

/// Mastodon OAuth 2 flow: dynamic app registration, authorization URL,
/// code-for-token exchange, and credential verification.
public struct MastodonOAuth: Sendable {
  public static let redirectURI = "outbox://oauth/mastodon"
  /// `read:accounts` identifies you, `read:statuses` backfills your posts,
  /// `read:search` resolves the post a reply targets, `write:statuses` publishes.
  public static let scopes = "read:accounts read:search read:statuses write:statuses"

  private let transport: any HTTPTransport

  public init(transport: any HTTPTransport = URLSessionTransport()) {
    self.transport = transport
  }

  public struct AppRegistration: Codable, Equatable, Sendable {
    public var clientID: String
    public var clientSecret: String

    enum CodingKeys: String, CodingKey {
      case clientID = "client_id"
      case clientSecret = "client_secret"
    }
  }

  /// Registers Outbox with an instance via `POST /api/v1/apps`.
  public func registerApp(on serverURL: URL) async throws -> AppRegistration {
    let body = [
      "client_name": "Outbox",
      "redirect_uris": Self.redirectURI,
      "scopes": Self.scopes,
      "website": "https://xo.engineering",
    ]
    return try await postJSON(body, to: serverURL.appending(path: "api/v1/apps"))
  }

  public func authorizationURL(on serverURL: URL, clientID: String, pkce: PKCE) -> URL {
    var components = URLComponents(
      url: serverURL.appending(path: "oauth/authorize"),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = [
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "code_challenge", value: pkce.challenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: Self.scopes),
    ]
    return components.url!
  }

  public struct TokenResponse: Codable, Equatable, Sendable {
    public var accessToken: String

    enum CodingKeys: String, CodingKey {
      case accessToken = "access_token"
    }
  }

  /// Exchanges an authorization code for an access token via `POST /oauth/token`.
  public func exchangeCode(
    _ code: String,
    on serverURL: URL,
    pkce: PKCE,
    registration: AppRegistration
  ) async throws -> String {
    let body = [
      "client_id": registration.clientID,
      "client_secret": registration.clientSecret,
      "code": code,
      "code_verifier": pkce.verifier,
      "grant_type": "authorization_code",
      "redirect_uri": Self.redirectURI,
      "scope": Self.scopes,
    ]
    let token: TokenResponse = try await postJSON(body, to: serverURL.appending(path: "oauth/token"))
    return token.accessToken
  }

  public struct VerifiedAccount: Codable, Equatable, Sendable {
    public var acct: String
    public var username: String
  }

  /// Looks up who the token belongs to via `GET /api/v1/accounts/verify_credentials`.
  public func verifyCredentials(on serverURL: URL, token: String) async throws -> VerifiedAccount {
    var request = URLRequest(url: serverURL.appending(path: "api/v1/accounts/verify_credentials"))
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw AdapterError.httpError(
        statusCode: response.statusCode,
        message: String(bytes: data, encoding: .utf8) ?? ""
      )
    }
    return try JSONDecoder().decode(VerifiedAccount.self, from: data)
  }

  private func postJSON<Response: Decodable>(_ body: [String: String], to url: URL) async throws -> Response {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw AdapterError.httpError(
        statusCode: response.statusCode,
        message: String(bytes: data, encoding: .utf8) ?? ""
      )
    }
    return try JSONDecoder().decode(Response.self, from: data)
  }
}
