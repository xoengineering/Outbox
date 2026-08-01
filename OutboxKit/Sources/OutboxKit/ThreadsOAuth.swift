import Foundation

/// Threads OAuth, which runs against Meta's Graph API.
///
/// Unlike Mastodon, Threads has no dynamic app registration: you register an
/// app at developers.facebook.com and supply its client ID and secret.
public struct ThreadsOAuth: Sendable {
  public static let authorizationHost = "https://threads.net"
  public static let graphHost = "https://graph.threads.net"
  public static let redirectURI = "outbox://oauth/threads"
  public static let scopes = "threads_basic,threads_content_publish"

  private let transport: any HTTPTransport

  public init(transport: any HTTPTransport = URLSessionTransport()) {
    self.transport = transport
  }

  public func authorizationURL(clientID: String) -> URL {
    var components = URLComponents(string: "\(Self.authorizationHost)/oauth/authorize")!
    components.queryItems = [
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: Self.scopes),
    ]
    return components.url!
  }

  /// Exchanges the authorization code for a short-lived token, then upgrades it
  /// to the 60-day long-lived token Outbox stores.
  public func exchangeCode(
    _ code: String,
    clientID: String,
    clientSecret: String
  ) async throws -> Credential {
    var request = URLRequest(url: URL(string: "\(Self.graphHost)/oauth/access_token")!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(
      formEncoded([
        "client_id": clientID,
        "client_secret": clientSecret,
        "code": code,
        "grant_type": "authorization_code",
        "redirect_uri": Self.redirectURI,
      ]).utf8)

    let shortLived: ShortLivedToken = try await sendJSON(request)
    let longLived = try await exchangeForLongLivedToken(
      shortLived.accessToken,
      clientSecret: clientSecret
    )
    return .threads(userID: "\(shortLived.userID)", accessToken: longLived)
  }

  private func exchangeForLongLivedToken(_ token: String, clientSecret: String) async throws -> String {
    var components = URLComponents(string: "\(Self.graphHost)/access_token")!
    components.queryItems = [
      URLQueryItem(name: "access_token", value: token),
      URLQueryItem(name: "client_secret", value: clientSecret),
      URLQueryItem(name: "grant_type", value: "th_exchange_token"),
    ]
    let response: LongLivedToken = try await sendJSON(URLRequest(url: components.url!))
    return response.accessToken
  }

  /// Looks up the handle a token belongs to.
  public func profile(credential: Credential) async throws -> String {
    guard case .threads(let userID, let token) = credential else {
      throw AdapterError.missingCredential
    }
    var components = URLComponents(string: "\(Self.graphHost)/v1.0/\(userID)")!
    components.queryItems = [
      URLQueryItem(name: "access_token", value: token),
      URLQueryItem(name: "fields", value: "id,username"),
    ]
    let profile: ThreadsProfile = try await sendJSON(URLRequest(url: components.url!))
    return profile.username
  }

  private func formEncoded(_ fields: [String: String]) -> String {
    fields
      .sorted { $0.key < $1.key }
      .map { key, value in
        let encoded =
          value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
        return "\(key)=\(encoded)"
      }
      .joined(separator: "&")
  }

  private func sendJSON<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw AdapterError.httpError(
        statusCode: response.statusCode,
        message: String(bytes: data, encoding: .utf8) ?? ""
      )
    }
    return try JSONDecoder().decode(Response.self, from: data)
  }

  private struct ShortLivedToken: Decodable {
    var accessToken: String
    var userID: Int

    enum CodingKeys: String, CodingKey {
      case accessToken = "access_token"
      case userID = "user_id"
    }
  }

  private struct LongLivedToken: Decodable {
    var accessToken: String

    enum CodingKeys: String, CodingKey {
      case accessToken = "access_token"
    }
  }

  private struct ThreadsProfile: Decodable {
    var username: String
  }
}
