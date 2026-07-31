import Foundation

/// The YAML frontmatter of a post file: which account it belongs to,
/// when it was written, and — once syndicated — where it lives remotely.
public struct PostMetadata: Equatable, Sendable {
  public var account: String
  /// Shared ID linking sibling files created by one crosspost.
  public var compositionID: UUID?
  public var createdAt: Date
  /// Remote URL of the post this one replies to.
  public var inReplyTo: URL?
  public var network: Network
  public var publishedAt: Date?
  public var remoteID: String?
  public var remoteURL: URL?

  public init(
    account: String,
    compositionID: UUID? = nil,
    createdAt: Date,
    inReplyTo: URL? = nil,
    network: Network,
    publishedAt: Date? = nil,
    remoteID: String? = nil,
    remoteURL: URL? = nil
  ) {
    self.account = account
    self.compositionID = compositionID
    self.createdAt = createdAt
    self.inReplyTo = inReplyTo
    self.network = network
    self.publishedAt = publishedAt
    self.remoteID = remoteID
    self.remoteURL = remoteURL
  }

  public var isPublished: Bool { publishedAt != nil }
}
