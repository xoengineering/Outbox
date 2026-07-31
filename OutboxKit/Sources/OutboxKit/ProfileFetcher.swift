import Foundation

/// A profile as the network presents it: display name and avatar.
public struct ProfileInfo: Equatable, Sendable {
  public var avatarURL: URL?
  public var displayName: String?

  public init(avatarURL: URL? = nil, displayName: String? = nil) {
    self.avatarURL = avatarURL
    self.displayName = displayName
  }
}

/// Fetches an account's profile (display name, avatar) from its network.
public struct ProfileFetcher: Sendable {
  private let transport: any HTTPTransport

  public init(transport: any HTTPTransport = URLSessionTransport()) {
    self.transport = transport
  }

  public func profile(for account: Account, credential: Credential) async throws -> ProfileInfo {
    switch account.network {
    case .bluesky: try await blueskyProfile(serverURL: account.serverURL, credential: credential)
    case .mastodon: try await mastodonProfile(serverURL: account.serverURL, credential: credential)
    case .threads: ProfileInfo()
    }
  }

  private func mastodonProfile(serverURL: URL, credential: Credential) async throws -> ProfileInfo {
    guard case .accessToken(let token) = credential else { throw AdapterError.missingCredential }

    var request = URLRequest(url: serverURL.appending(path: "api/v1/accounts/verify_credentials"))
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let response: MastodonAccountResponse = try await sendJSON(request)

    return ProfileInfo(
      avatarURL: response.avatar.flatMap(URL.init(string:)),
      displayName: normalized(response.displayName)
    )
  }

  private func blueskyProfile(serverURL: URL, credential: Credential) async throws -> ProfileInfo {
    guard case .appPassword(let identifier, let password) = credential else {
      throw AdapterError.missingCredential
    }

    var sessionRequest = URLRequest(url: serverURL.appending(path: "xrpc/com.atproto.server.createSession"))
    sessionRequest.httpMethod = "POST"
    sessionRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    sessionRequest.httpBody = try JSONEncoder().encode(["identifier": identifier, "password": password])
    let session: SessionResponse = try await sendJSON(sessionRequest)

    var components = URLComponents(
      url: serverURL.appending(path: "xrpc/app.bsky.actor.getProfile"),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = [URLQueryItem(name: "actor", value: session.did)]
    var profileRequest = URLRequest(url: components.url!)
    profileRequest.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
    let profile: BlueskyProfileResponse = try await sendJSON(profileRequest)

    return ProfileInfo(
      avatarURL: profile.avatar.flatMap(URL.init(string:)),
      displayName: normalized(profile.displayName)
    )
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

  private func normalized(_ displayName: String?) -> String? {
    guard let displayName, !displayName.isEmpty else { return nil }
    return displayName
  }

  private struct MastodonAccountResponse: Decodable {
    var avatar: String?
    var displayName: String?

    enum CodingKeys: String, CodingKey {
      case avatar
      case displayName = "display_name"
    }
  }

  private struct SessionResponse: Decodable {
    var accessJwt: String
    var did: String
  }

  private struct BlueskyProfileResponse: Decodable {
    var avatar: String?
    var displayName: String?
  }
}
