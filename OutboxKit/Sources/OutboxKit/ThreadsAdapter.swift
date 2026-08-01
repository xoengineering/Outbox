import Foundation

/// Publishes to Threads via Meta's Graph API, which is a two-step dance:
/// create a media container, then publish that container.
public struct ThreadsAdapter: SocialServiceAdapter {
  private let transport: any HTTPTransport

  public init(transport: any HTTPTransport = URLSessionTransport()) {
    self.transport = transport
  }

  public var network: Network { .threads }

  public func publish(_ post: OutgoingPost, account: Account, credential: Credential) async throws -> PublishOutcome {
    guard case .threads(let userID, let token) = credential else {
      throw AdapterError.missingCredential
    }
    // Threads takes media as a publicly reachable URL, never as an upload, so
    // local attachments can't go out until Outbox can host them somewhere.
    guard post.attachments.isEmpty else {
      return .skipped(
        reason: "Threads needs media at a public URL, so this post's attachments weren't sent.")
    }

    var replyToID: String?
    if let replyTo = post.replyTo {
      guard case .threads(let parentID) = replyTo else { throw AdapterError.replyMismatch }
      replyToID = parentID
    }

    var containerFields = [
      "media_type": "TEXT",
      "text": post.body,
    ]
    if let replyToID { containerFields["reply_to_id"] = replyToID }
    let container: ContainerResponse = try await sendPost(
      path: "\(userID)/threads",
      fields: containerFields,
      token: token
    )

    let published: ContainerResponse = try await sendPost(
      path: "\(userID)/threads_publish",
      fields: ["creation_id": container.id],
      token: token
    )

    return .published(
      PublishReceipt(
        publishedAt: Date(),
        remoteID: published.id,
        remoteURL: try? await permalink(for: published.id, token: token)
      ))
  }

  /// Threads posts can be edited from the API only within a limited window and
  /// only for some post types, so Outbox records divergence instead.
  public func edit(body: String, remoteID: String, account: Account, credential: Credential) async throws {
    throw AdapterError.editingUnsupported
  }

  private func permalink(for mediaID: String, token: String) async throws -> URL? {
    var components = URLComponents(string: "\(ThreadsOAuth.graphHost)/v1.0/\(mediaID)")!
    components.queryItems = [
      URLQueryItem(name: "access_token", value: token),
      URLQueryItem(name: "fields", value: "permalink"),
    ]
    let response: PermalinkResponse = try await send(URLRequest(url: components.url!))
    return response.permalink.flatMap(URL.init(string:))
  }

  private func sendPost<Response: Decodable>(
    path: String,
    fields: [String: String],
    token: String
  ) async throws -> Response {
    var components = URLComponents(string: "\(ThreadsOAuth.graphHost)/v1.0/\(path)")!
    components.queryItems =
      fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
      + [URLQueryItem(name: "access_token", value: token)]

    var request = URLRequest(url: components.url!)
    request.httpMethod = "POST"
    return try await send(request)
  }

  private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw AdapterError.httpError(
        statusCode: response.statusCode,
        message: String(bytes: data, encoding: .utf8) ?? ""
      )
    }
    return try JSONDecoder().decode(Response.self, from: data)
  }

  private struct ContainerResponse: Decodable {
    var id: String
  }

  private struct PermalinkResponse: Decodable {
    var permalink: String?
  }
}
