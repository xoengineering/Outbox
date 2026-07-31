import Foundation

/// Turns a pasted post URL into the reply reference a network's API needs.
public protocol ReplyResolving: Sendable {
  func resolve(_ url: URL, account: Account, credential: Credential) async throws -> ResolvedReply?
}

public struct ReplyResolver: ReplyResolving {
  private let transport: any HTTPTransport

  public init(transport: any HTTPTransport = URLSessionTransport()) {
    self.transport = transport
  }

  public func resolve(_ url: URL, account: Account, credential: Credential) async throws -> ResolvedReply? {
    switch account.network {
    case .bluesky: try await resolveBluesky(url, serverURL: account.serverURL)
    case .mastodon: try await resolveMastodon(url, serverURL: account.serverURL, credential: credential)
    case .threads: nil
    }
  }

  /// Resolves any fediverse status URL via the instance's search API,
  /// which also fetches statuses the instance hasn't seen yet.
  private func resolveMastodon(
    _ url: URL,
    serverURL: URL,
    credential: Credential
  ) async throws -> ResolvedReply {
    guard case .accessToken(let token) = credential else { throw AdapterError.missingCredential }

    var components = URLComponents(
      url: serverURL.appending(path: "api/v2/search"),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = [
      URLQueryItem(name: "limit", value: "1"),
      URLQueryItem(name: "q", value: url.absoluteString),
      URLQueryItem(name: "resolve", value: "true"),
      URLQueryItem(name: "type", value: "statuses"),
    ]
    var request = URLRequest(url: components.url!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let results: SearchResponse = try await getJSON(request)
    guard let status = results.statuses.first else {
      throw AdapterError.replyNotFound(url.absoluteString)
    }
    return .mastodon(statusID: status.id)
  }

  /// Resolves a `https://bsky.app/profile/<handle>/post/<rkey>` URL to strong record
  /// refs, walking up to the thread root when the parent is itself a reply.
  private func resolveBluesky(_ url: URL, serverURL: URL) async throws -> ResolvedReply {
    let pathParts = url.path.split(separator: "/").map(String.init)
    guard pathParts.count == 4, pathParts[0] == "profile", pathParts[2] == "post" else {
      throw AdapterError.replyNotFound("Expected a bsky.app post URL, got \(url.absoluteString)")
    }
    let profile = pathParts[1]
    let recordKey = pathParts[3]

    let did: String
    if profile.hasPrefix("did:") {
      did = profile
    } else {
      var components = URLComponents(
        url: serverURL.appending(path: "xrpc/com.atproto.identity.resolveHandle"),
        resolvingAgainstBaseURL: false
      )!
      components.queryItems = [URLQueryItem(name: "handle", value: profile)]
      let resolved: ResolveHandleResponse = try await getJSON(URLRequest(url: components.url!))
      did = resolved.did
    }

    var components = URLComponents(
      url: serverURL.appending(path: "xrpc/com.atproto.repo.getRecord"),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = [
      URLQueryItem(name: "collection", value: "app.bsky.feed.post"),
      URLQueryItem(name: "repo", value: did),
      URLQueryItem(name: "rkey", value: recordKey),
    ]
    let record: GetRecordResponse = try await getJSON(URLRequest(url: components.url!))

    let parent = RecordRef(cid: record.cid, uri: record.uri)
    let root = record.value.reply?.root ?? parent
    return .bluesky(parent: parent, root: root)
  }

  private func getJSON<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw AdapterError.httpError(
        statusCode: response.statusCode,
        message: String(bytes: data, encoding: .utf8) ?? ""
      )
    }
    return try JSONDecoder().decode(Response.self, from: data)
  }

  private struct SearchResponse: Decodable {
    var statuses: [Status]

    struct Status: Decodable {
      var id: String
    }
  }

  private struct ResolveHandleResponse: Decodable {
    var did: String
  }

  private struct GetRecordResponse: Decodable {
    var cid: String
    var uri: String
    var value: RecordValue
  }

  private struct RecordValue: Decodable {
    var reply: RecordValueReply?
  }

  private struct RecordValueReply: Decodable {
    var root: RecordRef?
  }
}
