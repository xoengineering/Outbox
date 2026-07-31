import Foundation

/// The YAML frontmatter of a post file: which account it belongs to,
/// when it was written, and — once syndicated — where it lives remotely.
public struct PostMetadata: Equatable, Sendable {
  public var account: String
  public var createdAt: Date
  public var network: Network
  public var publishedAt: Date?
  public var remoteID: String?
  public var remoteURL: URL?

  public init(
    account: String,
    createdAt: Date,
    network: Network,
    publishedAt: Date? = nil,
    remoteID: String? = nil,
    remoteURL: URL? = nil
  ) {
    self.account = account
    self.createdAt = createdAt
    self.network = network
    self.publishedAt = publishedAt
    self.remoteID = remoteID
    self.remoteURL = remoteURL
  }

  public var isPublished: Bool { publishedAt != nil }
}
