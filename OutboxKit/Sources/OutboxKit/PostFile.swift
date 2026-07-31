import Foundation
import Yams

/// A post as stored on disk: YAML frontmatter followed by a Markdown body.
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

    var bodyLines = Array(lines[(closingIndex + 1)...])
    if bodyLines.first?.isEmpty == true { bodyLines.removeFirst() }
    let body = bodyLines.joined(separator: "\n")

    return PostFile(body: body, metadata: try metadata(from: rawFields))
  }

  public func serialized() throws -> String {
    var lines = [Self.delimiter]
    lines.append("network: \(metadata.network.rawValue)")
    lines.append("account: \(quoted(metadata.account))")
    lines.append("created_at: \(iso8601(metadata.createdAt))")
    if let publishedAt = metadata.publishedAt {
      lines.append("published_at: \(iso8601(publishedAt))")
    }
    if let remoteID = metadata.remoteID {
      lines.append("id: \(quoted(remoteID))")
    }
    if let remoteURL = metadata.remoteURL {
      lines.append("url: \(remoteURL.absoluteString)")
    }
    lines.append(Self.delimiter)
    lines.append("")
    lines.append(body)
    return lines.joined(separator: "\n")
  }

  private static func metadata(from fields: [String: Any]) throws -> PostMetadata {
    guard let networkValue = fields["network"] as? String else {
      throw ParseError.missingField("network")
    }
    guard let network = Network(rawValue: networkValue) else {
      throw ParseError.invalidValue(field: "network")
    }
    guard let account = fields["account"] as? String else {
      throw ParseError.missingField("account")
    }
    guard let createdAt = date(from: fields["created_at"]) else {
      throw ParseError.missingField("created_at")
    }

    var remoteURL: URL?
    if let urlString = fields["url"] as? String {
      guard let url = URL(string: urlString) else {
        throw ParseError.invalidValue(field: "url")
      }
      remoteURL = url
    }

    return PostMetadata(
      account: account,
      createdAt: createdAt,
      network: network,
      publishedAt: date(from: fields["published_at"]),
      remoteID: (fields["id"]).map { "\($0)" },
      remoteURL: remoteURL
    )
  }

  /// Yams resolves unquoted timestamps to `Date`; quoted ones arrive as `String`.
  private static func date(from value: Any?) -> Date? {
    switch value {
    case let date as Date: date
    case let string as String: ISO8601DateFormatter().date(from: string)
    default: nil
    }
  }

  private func iso8601(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
  }

  private func quoted(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
  }
}
