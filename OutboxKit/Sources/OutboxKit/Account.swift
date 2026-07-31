import Foundation

/// A configured publishing endpoint: one identity on one network.
public struct Account: Codable, Equatable, Hashable, Identifiable, Sendable {
  public var avatarURL: URL?
  public var displayName: String?
  public var handle: String
  public var id: UUID
  /// Instance-specific character limit override (Mastodon instances can raise the default).
  public var maximumCharacters: Int?
  public var network: Network
  public var serverURL: URL

  public init(
    avatarURL: URL? = nil,
    displayName: String? = nil,
    handle: String,
    id: UUID = UUID(),
    maximumCharacters: Int? = nil,
    network: Network,
    serverURL: URL
  ) {
    self.avatarURL = avatarURL
    self.displayName = displayName
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
