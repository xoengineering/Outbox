import Foundation

/// One network's publishing implementation.
public protocol SocialServiceAdapter: Sendable {
  var network: Network { get }

  func publish(_ post: OutgoingPost, account: Account, credential: Credential) async throws -> PublishOutcome
  func edit(body: String, remoteID: String, account: Account, credential: Credential) async throws
}

extension SocialServiceAdapter {
  /// Most networks can't edit posts; adapters that can override this.
  public func edit(body: String, remoteID: String, account: Account, credential: Credential) async throws {
    throw AdapterError.editingUnsupported
  }
}

/// What gets sent to a network: the text, plus a resolved reply reference when threading.
public struct OutgoingPost: Equatable, Sendable {
  public var body: String
  public var replyTo: ResolvedReply?

  public init(body: String, replyTo: ResolvedReply? = nil) {
    self.body = body
    self.replyTo = replyTo
  }
}

/// A reply target in the form each network's API needs.
public enum ResolvedReply: Equatable, Sendable {
  case bluesky(parent: RecordRef, root: RecordRef)
  case mastodon(statusID: String)
}

/// An atproto strong record reference.
public struct RecordRef: Codable, Equatable, Sendable {
  public var cid: String
  public var uri: String

  public init(cid: String, uri: String) {
    self.cid = cid
    self.uri = uri
  }
}

public struct PublishReceipt: Equatable, Sendable {
  public var publishedAt: Date
  public var remoteID: String
  public var remoteURL: URL?

  public init(publishedAt: Date, remoteID: String, remoteURL: URL? = nil) {
    self.publishedAt = publishedAt
    self.remoteID = remoteID
    self.remoteURL = remoteURL
  }
}

public enum PublishOutcome: Equatable, Sendable {
  case published(PublishReceipt)
  case skipped(reason: String)
}

public enum AdapterError: Error, Equatable, LocalizedError {
  case editingUnsupported
  case httpError(statusCode: Int, message: String)
  case invalidResponse
  case missingCredential
  case replyMismatch
  case replyNotFound(String)

  public var errorDescription: String? {
    switch self {
    case .editingUnsupported:
      "This network doesn't support editing published posts."
    case .httpError(let statusCode, let message):
      "The server replied with HTTP \(statusCode): \(message)"
    case .invalidResponse:
      "The server returned a response that couldn't be understood."
    case .missingCredential:
      "No stored credential for this account. Remove the account and add it again."
    case .replyMismatch:
      "The reply reference doesn't belong to this network."
    case .replyNotFound(let detail):
      "Couldn't resolve the post being replied to: \(detail)"
    }
  }
}
