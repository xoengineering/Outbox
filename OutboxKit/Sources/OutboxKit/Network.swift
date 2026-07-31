public enum Network: String, CaseIterable, Codable, Identifiable, Sendable {
  case bluesky
  case mastodon
  case threads

  public var id: Self { self }

  public var displayName: String {
    switch self {
    case .bluesky: "Bluesky"
    case .mastodon: "Mastodon"
    case .threads: "Threads"
    }
  }

  public var folderName: String { displayName }
}
