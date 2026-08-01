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

    var mediaIDs: [String] = []
    for attachment in post.attachments {
      mediaIDs.append(try await uploadMedia(attachment, account: account, token: token))
    }

    var request = URLRequest(url: account.serverURL.appending(path: "api/v1/statuses"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
      StatusRequest(
        inReplyToID: inReplyToID,
        mediaIDs: mediaIDs.isEmpty ? nil : mediaIDs,
        status: post.body
      ))

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

  /// Uploads one attachment via `POST /api/v2/media`, returning its media ID.
  private func uploadMedia(
    _ attachment: OutgoingAttachment,
    account: Account,
    token: String
  ) async throws -> String {
    var form = MultipartForm()
    form.addFile(
      name: "file",
      fileName: "attachment.\(fileExtension(for: attachment.mimeType))",
      mimeType: attachment.mimeType,
      data: attachment.data
    )
    if let alt = attachment.alt, !alt.isEmpty {
      form.addField(name: "description", value: alt)
    }

    var request = URLRequest(url: account.serverURL.appending(path: "api/v2/media"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = form.encoded()

    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw AdapterError.httpError(
        statusCode: response.statusCode,
        message: String(bytes: data, encoding: .utf8) ?? ""
      )
    }
    return try JSONDecoder().decode(MediaResponse.self, from: data).id
  }

  private func fileExtension(for mimeType: String) -> String {
    mimeType.split(separator: "/").last.map(String.init) ?? "bin"
  }

  /// Mastodon supports edits: `PUT /api/v1/statuses/:id`.
  public func edit(body: String, remoteID: String, account: Account, credential: Credential) async throws {
    guard case .accessToken(let token) = credential else { throw AdapterError.missingCredential }

    var request = URLRequest(url: account.serverURL.appending(path: "api/v1/statuses/\(remoteID)"))
    request.httpMethod = "PUT"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
      StatusRequest(inReplyToID: nil, mediaIDs: nil, status: body))

    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw AdapterError.httpError(
        statusCode: response.statusCode,
        message: String(bytes: data, encoding: .utf8) ?? ""
      )
    }
  }

  private struct StatusRequest: Encodable {
    var inReplyToID: String?
    var mediaIDs: [String]?
    var status: String

    enum CodingKeys: String, CodingKey {
      case inReplyToID = "in_reply_to_id"
      case mediaIDs = "media_ids"
      case status
    }
  }

  private struct MediaResponse: Decodable {
    var id: String
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
