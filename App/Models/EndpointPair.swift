import Foundation
import OutboxKit

/// One avatar + network pairing a post touches, for row footers.
struct EndpointPair: Identifiable {
  let id: String
  var avatarURL: URL?
  var network: Network
}
