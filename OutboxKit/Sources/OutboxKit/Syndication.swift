import Foundation

/// One live copy of a Post on a network (LOCKSS: lots of copies keep stuff safe).
public struct Syndication: Equatable, Sendable {
  public var account: String
  public var network: Network
  public var publishedAt: Date
  public var remoteID: String
  public var remoteURL: URL?
  /// The exact text sent to this network, only when it differed from the canonical body.
  public var text: String?

  public init(
    account: String,
    network: Network,
    publishedAt: Date,
    remoteID: String,
    remoteURL: URL? = nil,
    text: String? = nil
  ) {
    self.account = account
    self.network = network
    self.publishedAt = publishedAt
    self.remoteID = remoteID
    self.remoteURL = remoteURL
    self.text = text
  }

  public var endpoint: Endpoint {
    Endpoint(account: account, network: network)
  }
}
