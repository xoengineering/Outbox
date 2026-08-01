import Foundation

/// The YAML frontmatter of a Post: one canonical body, with the places it
/// should go (`targets`) and the copies that exist (`syndication`).
public struct PostMetadata: Equatable, Sendable {
  public var createdAt: Date
  /// Remote URL of someone else's post this one replies to.
  public var inReplyTo: URL?
  /// Archive-relative path of our own Post this one continues (a thread).
  public var inReplyToPost: String?
  /// Starred within Outbox as a writing tool; never sent to any network.
  public var isFavorite: Bool
  /// Copies that exist on networks.
  public var syndication: [Syndication]
  /// Destinations still owed a copy.
  public var targets: [Endpoint]

  public init(
    createdAt: Date,
    inReplyTo: URL? = nil,
    inReplyToPost: String? = nil,
    isFavorite: Bool = false,
    syndication: [Syndication] = [],
    targets: [Endpoint] = []
  ) {
    self.createdAt = createdAt
    self.inReplyTo = inReplyTo
    self.inReplyToPost = inReplyToPost
    self.isFavorite = isFavorite
    self.syndication = syndication
    self.targets = targets
  }

  public var isPublished: Bool { !syndication.isEmpty }

  /// Every endpoint this post touches: existing copies first, then pending targets.
  public var endpoints: [Endpoint] {
    var seen = Set<Endpoint>()
    return (syndication.map(\.endpoint) + targets).filter { seen.insert($0).inserted }
  }
}
