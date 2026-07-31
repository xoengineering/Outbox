import Foundation

/// One network's publishing implementation.
public protocol SocialServiceAdapter: Sendable {
  var network: Network { get }

  func publish(body: String, account: Account, credential: Credential) async throws -> PublishOutcome
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
  case httpError(statusCode: Int, message: String)
  case invalidResponse
  case missingCredential

  public var errorDescription: String? {
    switch self {
    case .httpError(let statusCode, let message):
      "The server replied with HTTP \(statusCode): \(message)"
    case .invalidResponse:
      "The server returned a response that couldn't be understood."
    case .missingCredential:
      "No stored credential for this account. Remove the account and add it again."
    }
  }
}
