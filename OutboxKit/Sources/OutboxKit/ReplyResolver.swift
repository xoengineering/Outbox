import Foundation

/// Turns a pasted post URL into the reply reference a network's API needs.
public protocol ReplyResolving: Sendable {
  func resolve(_ url: URL, account: Account, credential: Credential) async throws -> ResolvedReply?
  func snapshot(_ url: URL, account: Account, credential: Credential) async -> ReplySnapshot?
}

extension ReplyResolving {
  public func snapshot(_ url: URL, account: Account, credential: Credential) async -> ReplySnapshot? {
    nil
  }
}

public struct ReplyResolver: ReplyResolving {
  private let now: @Sendable () -> Date
  private let transport: any HTTPTransport

  public init(
    now: @escaping @Sendable () -> Date = { Date() },
    transport: any HTTPTransport = URLSessionTransport()
  ) {
    self.now = now
    self.transport = transport
  }

  public func resolve(_ url: URL, account: Account, credential: Credential) async throws -> ResolvedReply? {
    switch account.network {
    case .bluesky:
      let (record, _) = try await blueskyRecord(url, serverURL: account.serverURL)
      let parent = RecordRef(cid: record.cid, uri: record.uri)
      return .bluesky(parent: parent, root: record.value.reply?.root ?? parent)
    case .mastodon:
      let status = try await mastodonStatus(url, serverURL: account.serverURL, credential: credential)
      return .mastodon(statusID: status.id)
    case .threads:
      return nil
    }
  }

  /// Fetches a keepable copy of the upstream post: author and plain text.
  public func snapshot(_ url: URL, account: Account, credential: Credential) async -> ReplySnapshot? {
    switch account.network {
    case .bluesky:
      guard let (record, profile) = try? await blueskyRecord(url, serverURL: account.serverURL),
        let text = record.value.text
      else { return nil }
      return ReplySnapshot(author: "@\(profile)", fetchedAt: now(), text: text)
    case .mastodon:
      guard
        let status = try? await mastodonStatus(url, serverURL: account.serverURL, credential: credential)
      else { return nil }
      return ReplySnapshot(
        author: "@\(status.account?.acct ?? "unknown")",
        fetchedAt: now(),
        text: HTMLText.plainText(fromHTML: status.content ?? "")
      )
    case .threads:
      return nil
    }
  }

  // MARK: - Mastodon

  /// Resolves any fediverse status URL via the instance's search API,
  /// which also fetches statuses the instance hasn't seen yet.
  private func mastodonStatus(
    _ url: URL,
    serverURL: URL,
    credential: Credential
  ) async throws -> SearchResponse.Status {
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
    return status
  }

  // MARK: - Bluesky

  /// Fetches the record behind a `https://bsky.app/profile/<handle>/post/<rkey>`
  /// URL, returning it with the profile segment of the URL.
  private func blueskyRecord(
    _ url: URL,
    serverURL: URL
  ) async throws -> (GetRecordResponse, String) {
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
    return (record, profile)
  }

  // MARK: - Shared

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
      var account: StatusAccount?
      var content: String?
      var id: String
    }
  }

  private struct StatusAccount: Decodable {
    var acct: String
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
    var text: String?
  }

  private struct RecordValueReply: Decodable {
    var root: RecordRef?
  }
}
