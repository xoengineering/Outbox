import Foundation

/// Per-network character counting and limits, for composer UI and pre-publish validation.
///
/// - Bluesky: 300 grapheme clusters; URLs count at full length.
/// - Mastodon: 500 by default (instances can raise it); every URL counts as 23;
///   only the local part of a `@user@domain` mention counts.
/// - Threads: 500 characters.
public enum CharacterCount {
  public static func limit(for network: Network) -> Int {
    switch network {
    case .bluesky: 300
    case .mastodon: 500
    case .threads: 500
    }
  }

  public static func count(_ text: String, for network: Network) -> Int {
    switch network {
    case .bluesky, .threads: text.count
    case .mastodon: mastodonCount(text)
    }
  }

  public static func remaining(_ text: String, for network: Network) -> Int {
    limit(for: network) - count(text, for: network)
  }

  private static let urlPlaceholder = String(repeating: "x", count: 23)

  private static func mastodonCount(_ text: String) -> Int {
    var normalized = replacingURLs(in: text, with: urlPlaceholder)
    normalized = trimmingMentionDomains(in: normalized)
    return normalized.unicodeScalars.count
  }

  private static func replacingURLs(in text: String, with placeholder: String) -> String {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return text }

    var result = text
    let fullRange = NSRange(result.startIndex..., in: result)
    let matches = detector.matches(in: result, range: fullRange).reversed()
    for match in matches {
      guard let range = Range(match.range, in: result) else { continue }
      result.replaceSubrange(range, with: placeholder)
    }
    return result
  }

  private static func trimmingMentionDomains(in text: String) -> String {
    let pattern = /(@[A-Za-z0-9_]+)@[A-Za-z0-9.\-]+/
    return text.replacing(pattern) { match in String(match.output.1) }
  }
}
