import Foundation
import Yams

/// One-time migration from the per-network-copy layout
/// (`Network/Account/YYYY/MM/DD/slug-N.md`, one file per copy) to the
/// single-Post layout (`YYYY/MM/DD/slug-N.md` with a syndication list).
public struct ArchiveMigrator: Sendable {
  private let baseDirectory: URL
  private let store: PostStore

  public init(baseDirectory: URL, store: PostStore) {
    self.baseDirectory = baseDirectory
    self.store = store
  }

  /// Migrates any legacy files found; returns the number of Posts written.
  @discardableResult
  public func migrateIfNeeded() throws -> Int {
    let legacyPosts = try loadLegacyPosts()
    guard !legacyPosts.isEmpty else { return 0 }

    let groups = Dictionary(grouping: legacyPosts, by: \.groupKey)
    var written = 0
    for group in groups.values {
      try store.save(merge(group))
      written += 1
    }

    for legacy in legacyPosts {
      try FileManager.default.removeItem(at: legacy.fileURL)
      prune(from: legacy.fileURL.deletingLastPathComponent())
    }
    return written
  }

  // MARK: - Legacy reading

  private struct LegacyPost {
    var body: String
    var compositionID: String?
    var createdAt: Date
    var endpoint: Endpoint
    var fileURL: URL
    var inReplyTo: URL?
    var isFavorite: Bool
    var modifiedAt: Date
    var publishedAt: Date?
    var remoteID: String?
    var remoteURL: URL?

    /// Copies from one crosspost share a composition ID; older files fall back
    /// to same-content-same-minute grouping.
    var groupKey: String {
      if let compositionID { return compositionID }
      let squashedBody = body.filter { !$0.isWhitespace }
      let minute = Int(createdAt.timeIntervalSince1970 / 60)
      return "\(squashedBody)|\(minute)"
    }
  }

  private func loadLegacyPosts() throws -> [LegacyPost] {
    guard FileManager.default.fileExists(atPath: baseDirectory.path) else { return [] }

    let enumerator = FileManager.default.enumerator(
      at: baseDirectory,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    )
    var legacyPosts: [LegacyPost] = []
    while let fileURL = enumerator?.nextObject() as? URL {
      guard fileURL.pathExtension == "md" else { continue }
      guard let text = try? String(contentsOf: fileURL, encoding: .utf8),
        let legacy = parseLegacy(text, at: fileURL)
      else { continue }
      legacyPosts.append(legacy)
    }
    return legacyPosts
  }

  private func parseLegacy(_ text: String, at fileURL: URL) -> LegacyPost? {
    let lines = text.components(separatedBy: "\n")
    guard lines.first == "---", let closingIndex = lines.dropFirst().firstIndex(of: "---") else {
      return nil
    }
    let yamlText = lines[1..<closingIndex].joined(separator: "\n")
    guard let fields = (try? Yams.load(yaml: yamlText)) as? [String: Any],
      let networkValue = fields["network"] as? String,
      let network = Network(rawValue: networkValue),
      let account = fields["account"] as? String,
      let createdAt = date(from: fields["created_at"])
    else { return nil }

    var bodyLines = Array(lines[(closingIndex + 1)...])
    if bodyLines.first?.isEmpty == true { bodyLines.removeFirst() }

    let modifiedAt =
      (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
      ?? createdAt

    return LegacyPost(
      body: bodyLines.joined(separator: "\n"),
      compositionID: fields["composition"] as? String,
      createdAt: createdAt,
      endpoint: Endpoint(account: account, network: network),
      fileURL: fileURL,
      inReplyTo: (fields["in_reply_to"] as? String).flatMap(URL.init(string:)),
      isFavorite: fields["favorite"] as? Bool ?? false,
      modifiedAt: modifiedAt,
      publishedAt: date(from: fields["published_at"]),
      remoteID: (fields["id"]).map { "\($0)" },
      remoteURL: (fields["url"] as? String).flatMap(URL.init(string:))
    )
  }

  private func date(from value: Any?) -> Date? {
    switch value {
    case let date as Date: date
    case let string as String: ISO8601DateFormatter().date(from: string)
    default: nil
    }
  }

  // MARK: - Merging

  private func merge(_ group: [LegacyPost]) -> PostFile {
    let ordered = group.sorted { $0.createdAt < $1.createdAt }
    let canonicalBody = group.max { $0.modifiedAt < $1.modifiedAt }!.body

    var syndication: [Syndication] = []
    var targets: [Endpoint] = []
    for legacy in ordered {
      if let publishedAt = legacy.publishedAt, let remoteID = legacy.remoteID {
        syndication.append(
          Syndication(
            account: legacy.endpoint.account,
            network: legacy.endpoint.network,
            publishedAt: publishedAt,
            remoteID: remoteID,
            remoteURL: legacy.remoteURL,
            text: legacy.body == canonicalBody ? nil : legacy.body
          ))
      } else {
        targets.append(legacy.endpoint)
      }
    }

    let metadata = PostMetadata(
      createdAt: ordered.first!.createdAt,
      inReplyTo: ordered.compactMap(\.inReplyTo).first,
      isFavorite: group.contains { $0.isFavorite },
      syndication: syndication.sorted { $0.publishedAt < $1.publishedAt },
      targets: targets
    )
    return PostFile(body: canonicalBody, metadata: metadata)
  }

  /// Removes now-empty legacy directories, walking up to (not including) the base.
  private func prune(from directory: URL) {
    var current = directory.standardizedFileURL
    let base = baseDirectory.standardizedFileURL
    while current.path != base.path, current.path.hasPrefix(base.path) {
      let contents = (try? FileManager.default.contentsOfDirectory(atPath: current.path)) ?? []
      let removable = contents.isEmpty || contents == [".DS_Store"]
      guard removable else { return }
      try? FileManager.default.removeItem(at: current)
      current = current.deletingLastPathComponent()
    }
  }
}
