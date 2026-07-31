import Foundation

/// Publishes posts to Bluesky (atproto): creates a session with an app password,
/// then writes an `app.bsky.feed.post` record with link facets.
public struct BlueskyAdapter: SocialServiceAdapter {
  private let now: @Sendable () -> Date
  private let transport: any HTTPTransport

  public init(
    now: @escaping @Sendable () -> Date = { Date() },
    transport: any HTTPTransport = URLSessionTransport()
  ) {
    self.now = now
    self.transport = transport
  }

  public var network: Network { .bluesky }

  public func publish(body: String, account: Account, credential: Credential) async throws -> PublishOutcome {
    guard case .appPassword(let identifier, let password) = credential else {
      throw AdapterError.missingCredential
    }

    let session = try await createSession(
      identifier: identifier,
      password: password,
      serverURL: account.serverURL
    )
    let record = try await createRecord(body: body, session: session, serverURL: account.serverURL)

    let receipt = PublishReceipt(
      publishedAt: now(),
      remoteID: record.uri,
      remoteURL: webURL(handle: session.handle, recordURI: record.uri)
    )
    return .published(receipt)
  }

  /// Confirms an app password works by creating a session; returns the canonical handle.
  public func verifyCredential(_ credential: Credential, serverURL: URL) async throws -> String {
    guard case .appPassword(let identifier, let password) = credential else {
      throw AdapterError.missingCredential
    }
    let session = try await createSession(identifier: identifier, password: password, serverURL: serverURL)
    return session.handle
  }

  /// Maps `at://did:plc:xyz/app.bsky.feed.post/<rkey>` to the public bsky.app permalink.
  func webURL(handle: String, recordURI: String) -> URL? {
    guard let recordKey = recordURI.split(separator: "/").last else { return nil }
    return URL(string: "https://bsky.app/profile/\(handle)/post/\(recordKey)")
  }

  private func createSession(
    identifier: String,
    password: String,
    serverURL: URL
  ) async throws -> SessionResponse {
    let body = SessionRequest(identifier: identifier, password: password)
    return try await postJSON(
      body,
      to: serverURL.appending(path: "xrpc/com.atproto.server.createSession"),
      token: nil
    )
  }

  private func createRecord(
    body: String,
    session: SessionResponse,
    serverURL: URL
  ) async throws -> RecordResponse {
    let record = PostRecord(
      createdAt: ISO8601.string(from: now()),
      facets: LinkFacets.detect(in: body),
      text: body
    )
    let request = RecordRequest(record: record, repo: session.did)
    return try await postJSON(
      request,
      to: serverURL.appending(path: "xrpc/com.atproto.repo.createRecord"),
      token: session.accessJwt
    )
  }

  private func postJSON<Body: Encodable, Response: Decodable>(
    _ body: Body,
    to url: URL,
    token: String?
  ) async throws -> Response {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw AdapterError.httpError(
        statusCode: response.statusCode,
        message: String(decoding: data, as: UTF8.self)
      )
    }
    return try JSONDecoder().decode(Response.self, from: data)
  }

  private struct SessionRequest: Encodable {
    var identifier: String
    var password: String
  }

  private struct SessionResponse: Decodable {
    var accessJwt: String
    var did: String
    var handle: String
  }

  private struct RecordRequest: Encodable {
    var collection = "app.bsky.feed.post"
    var record: PostRecord
    var repo: String
  }

  private struct PostRecord: Encodable {
    var createdAt: String
    var facets: [LinkFacets.Facet]
    var text: String
    var type = "app.bsky.feed.post"

    enum CodingKeys: String, CodingKey {
      case createdAt
      case facets
      case text
      case type = "$type"
    }
  }

  private struct RecordResponse: Decodable {
    var cid: String
    var uri: String
  }
}
