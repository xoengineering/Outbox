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

public enum AdapterError: Error, Equatable {
  case httpError(statusCode: Int, message: String)
  case invalidResponse
  case missingCredential
}
