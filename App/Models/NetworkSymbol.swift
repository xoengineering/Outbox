import OutboxKit

extension Network {
  var symbolName: String {
    switch self {
    case .bluesky: "cloud"
    case .mastodon: "burst"
    case .threads: "at"
    }
  }
}
