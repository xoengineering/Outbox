import Foundation

/// A saved copy of someone else's post that ours replies to — upstream posts
/// can vanish, so we keep what we replied to (LOCKSS again).
public struct ReplySnapshot: Equatable, Sendable {
  public var author: String
  public var fetchedAt: Date
  public var text: String

  public init(author: String, fetchedAt: Date, text: String) {
    self.author = author
    self.fetchedAt = fetchedAt
    self.text = text
  }
}
