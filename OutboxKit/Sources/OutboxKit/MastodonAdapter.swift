import Foundation

/// Publishes statuses to a Mastodon instance via `POST /api/v1/statuses`.
public struct MastodonAdapter: SocialServiceAdapter {
  private let transport: any HTTPTransport

  public init(transport: any HTTPTransport = URLSessionTransport()) {
    self.transport = transport
  }

  public var network: Network { .mastodon }

  public func publish(_ post: OutgoingPost, account: Account, credential: Credential) async throws -> PublishOutcome {
    guard case .accessToken(let token) = credential else { throw AdapterError.missingCredential }

    var inReplyToID: String?
    if let replyTo = post.replyTo {
      guard case .mastodon(let statusID) = replyTo else { throw AdapterError.replyMismatch }
      inReplyToID = statusID
    }

    var request = URLRequest(url: account.serverURL.appending(path: "api/v1/statuses"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(StatusRequest(inReplyToID: inReplyToID, status: post.body))

    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw AdapterError.httpError(
        statusCode: response.statusCode,
        message: String(bytes: data, encoding: .utf8) ?? ""
      )
    }

    let status = try JSONDecoder().decode(StatusResponse.self, from: data)
    let receipt = PublishReceipt(
      publishedAt: ISO8601.date(from: status.createdAt) ?? Date(),
      remoteID: status.id,
      remoteURL: status.url.flatMap(URL.init(string:))
    )
    return .published(receipt)
  }

  private struct StatusRequest: Encodable {
    var inReplyToID: String?
    var status: String

    enum CodingKeys: String, CodingKey {
      case inReplyToID = "in_reply_to_id"
      case status
    }
  }

  private struct StatusResponse: Decodable {
    var createdAt: String
    var id: String
    var url: String?

    enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case id
      case url
    }
  }
}
