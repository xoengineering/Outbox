import Foundation

/// A configured publishing endpoint: one identity on one network.
public struct Account: Codable, Equatable, Hashable, Identifiable, Sendable {
  public var handle: String
  public var id: UUID
  /// Instance-specific character limit override (Mastodon instances can raise the default).
  public var maximumCharacters: Int?
  public var network: Network
  public var serverURL: URL

  public init(
    handle: String,
    id: UUID = UUID(),
    maximumCharacters: Int? = nil,
    network: Network,
    serverURL: URL
  ) {
    self.handle = handle
    self.id = id
    self.maximumCharacters = maximumCharacters
    self.network = network
    self.serverURL = serverURL
  }

  public var characterLimit: Int {
    maximumCharacters ?? CharacterCount.limit(for: network)
  }
}
