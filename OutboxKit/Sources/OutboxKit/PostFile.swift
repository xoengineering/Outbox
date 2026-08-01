import Foundation
import Yams

/// A Post as stored on disk: YAML frontmatter followed by the canonical
/// Markdown body.
///
/// Frontmatter is parsed with Yams. Serialization is hand-emitted so key
/// order and quoting stay byte-for-byte stable across round trips.
public struct PostFile: Equatable, Sendable {
  public var body: String
  public var metadata: PostMetadata

  public init(body: String, metadata: PostMetadata) {
    self.body = body
    self.metadata = metadata
  }

  public enum ParseError: Error, Equatable {
    case invalidValue(field: String)
    case legacyFormat
    case malformedFrontmatter
    case missingField(String)
    case missingFrontmatter
  }

  private static let delimiter = "---"

  public static func parse(_ text: String) throws -> PostFile {
    let lines = text.components(separatedBy: "\n")
    guard lines.first == delimiter else { throw ParseError.missingFrontmatter }
    guard let closingIndex = lines.dropFirst().firstIndex(of: delimiter) else {
      throw ParseError.missingFrontmatter
    }

    let yamlText = lines[1..<closingIndex].joined(separator: "\n")
    guard let rawFields = try? Yams.load(yaml: yamlText) as? [String: Any] else {
      throw ParseError.malformedFrontmatter
    }
    guard rawFields["network"] == nil else { throw ParseError.legacyFormat }

    var bodyLines = Array(lines[(closingIndex + 1)...])
    if bodyLines.first?.isEmpty == true { bodyLines.removeFirst() }
    let body = bodyLines.joined(separator: "\n")

    return PostFile(body: body, metadata: try metadata(from: rawFields))
  }

  public func serialized() throws -> String {
    var lines = [Self.delimiter]
    lines.append("created_at: \(iso8601(metadata.createdAt))")
    if metadata.isFavorite {
      lines.append("favorite: true")
    }
    if let inReplyTo = metadata.inReplyTo {
      lines.append("in_reply_to: \(inReplyTo.absoluteString)")
    }
    if let inReplyToPost = metadata.inReplyToPost {
      lines.append("in_reply_to_post: \(quoted(inReplyToPost))")
    }
    if !metadata.targets.isEmpty {
      lines.append("targets:")
      for target in metadata.targets {
        lines.append("  - network: \(target.network.rawValue)")
        lines.append("    account: \(quoted(target.account))")
      }
    }
    if !metadata.syndication.isEmpty {
      lines.append("syndication:")
      for copy in metadata.syndication {
        lines.append("  - network: \(copy.network.rawValue)")
        lines.append("    account: \(quoted(copy.account))")
        lines.append("    published_at: \(iso8601(copy.publishedAt))")
        lines.append("    id: \(quoted(copy.remoteID))")
        if let remoteURL = copy.remoteURL {
          lines.append("    url: \(remoteURL.absoluteString)")
        }
        if let text = copy.text {
          lines.append("    text: |")
          for textLine in text.components(separatedBy: "\n") {
            lines.append(textLine.isEmpty ? "" : "      \(textLine)")
          }
        }
      }
    }
    lines.append(Self.delimiter)
    lines.append("")
    lines.append(body)
    return lines.joined(separator: "\n")
  }

  // MARK: - Parsing helpers

  private static func metadata(from fields: [String: Any]) throws -> PostMetadata {
    guard let createdAt = date(from: fields["created_at"]) else {
      throw ParseError.missingField("created_at")
    }

    var targets: [Endpoint] = []
    if let rawTargets = fields["targets"] as? [[String: Any]] {
      targets = try rawTargets.map { try endpoint(from: $0, field: "targets") }
    }

    var syndication: [Syndication] = []
    if let rawCopies = fields["syndication"] as? [[String: Any]] {
      syndication = try rawCopies.map { try self.syndication(from: $0) }
    }

    return PostMetadata(
      createdAt: createdAt,
      inReplyTo: try url(from: fields["in_reply_to"], field: "in_reply_to"),
      inReplyToPost: fields["in_reply_to_post"] as? String,
      isFavorite: fields["favorite"] as? Bool ?? false,
      syndication: syndication,
      targets: targets
    )
  }

  private static func endpoint(from fields: [String: Any], field: String) throws -> Endpoint {
    guard let networkValue = fields["network"] as? String,
      let network = Network(rawValue: networkValue)
    else { throw ParseError.invalidValue(field: "\(field).network") }
    guard let account = fields["account"] as? String else {
      throw ParseError.missingField("\(field).account")
    }
    return Endpoint(account: account, network: network)
  }

  private static func syndication(from fields: [String: Any]) throws -> Syndication {
    let endpoint = try endpoint(from: fields, field: "syndication")
    guard let publishedAt = date(from: fields["published_at"]) else {
      throw ParseError.missingField("syndication.published_at")
    }
    guard let remoteID = (fields["id"]).map({ "\($0)" }) else {
      throw ParseError.missingField("syndication.id")
    }

    var text = fields["text"] as? String
    if let unwrapped = text, unwrapped.hasSuffix("\n") {
      text = String(unwrapped.dropLast())
    }

    return Syndication(
      account: endpoint.account,
      network: endpoint.network,
      publishedAt: publishedAt,
      remoteID: remoteID,
      remoteURL: try url(from: fields["url"], field: "syndication.url"),
      text: text
    )
  }

  private static func url(from value: Any?, field: String) throws -> URL? {
    guard let string = value as? String else { return nil }
    guard let url = URL(string: string) else { throw ParseError.invalidValue(field: field) }
    return url
  }

  /// Yams resolves unquoted timestamps to `Date`; quoted ones arrive as `String`.
  private static func date(from value: Any?) -> Date? {
    switch value {
    case let date as Date: date
    case let string as String: ISO8601DateFormatter().date(from: string)
    default: nil
    }
  }

  // MARK: - Emission helpers

  private func iso8601(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
  }

  private func quoted(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
  }
}
