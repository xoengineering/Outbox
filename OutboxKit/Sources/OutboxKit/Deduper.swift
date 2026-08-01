import Foundation

/// A set of archived Posts whose content matches: candidates for merging.
public struct DupeGroup: Identifiable, Sendable {
  public var id: String
  public var posts: [StoredPost]
}

/// Finds same-content Posts and merges them on request — always with a human
/// saying yes first (Photos.app style), never automatically.
public struct Deduper: Sendable {
  private let store: PostStore

  public init(store: PostStore) {
    self.store = store
  }

  /// Groups of Posts whose whitespace-normalized bodies are identical.
  public func candidateGroups() throws -> [DupeGroup] {
    let groups = Dictionary(grouping: try store.allPosts()) { normalize($0.file.body) }
    return
      groups
      .filter { $0.value.count > 1 }
      .map { key, posts in
        DupeGroup(id: key, posts: posts.sorted { $0.file.metadata.createdAt < $1.file.metadata.createdAt })
      }
      .sorted { $0.posts[0].file.metadata.createdAt < $1.posts[0].file.metadata.createdAt }
  }

  /// Merges a group into one Post: union of copies and targets, earliest
  /// creation date, favorite if any was. The survivor is the post with the
  /// most copies (ties: oldest); the others' files are deleted.
  @discardableResult
  public func merge(_ group: DupeGroup) throws -> StoredPost? {
    guard let winner = group.posts.max(by: { lhs, rhs in
      if lhs.file.metadata.syndication.count != rhs.file.metadata.syndication.count {
        return lhs.file.metadata.syndication.count < rhs.file.metadata.syndication.count
      }
      return lhs.file.metadata.createdAt > rhs.file.metadata.createdAt
    })
    else { return nil }

    var file = winner.file
    for post in group.posts where post.id != winner.id {
      let metadata = post.file.metadata
      for copy in metadata.syndication
      where !file.metadata.syndication.contains(where: {
        $0.endpoint == copy.endpoint && $0.remoteID == copy.remoteID
      }) {
        file.metadata.syndication.append(copy)
      }
      for target in metadata.targets where !file.metadata.targets.contains(target) {
        file.metadata.targets.append(target)
      }
      file.metadata.isFavorite = file.metadata.isFavorite || metadata.isFavorite
      file.metadata.createdAt = min(file.metadata.createdAt, metadata.createdAt)
      if file.metadata.inReplyTo == nil { file.metadata.inReplyTo = metadata.inReplyTo }
    }
    let syndicated = Set(file.metadata.syndication.map(\.endpoint))
    file.metadata.targets.removeAll { syndicated.contains($0) }
    file.metadata.syndication.sort { $0.publishedAt < $1.publishedAt }

    try store.save(file, to: winner.fileURL)
    for post in group.posts where post.id != winner.id {
      try store.delete(post)
    }
    return StoredPost(file: file, fileURL: winner.fileURL)
  }

  private func normalize(_ text: String) -> String {
    String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
  }
}
