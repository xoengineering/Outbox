import Foundation

/// Detects links in post text and produces atproto richtext facets,
/// which use UTF-8 byte offsets.
public enum LinkFacets {
  public struct Facet: Encodable, Equatable, Sendable {
    public var index: ByteRange
    public var features: [Feature]
  }

  public struct ByteRange: Encodable, Equatable, Sendable {
    public var byteStart: Int
    public var byteEnd: Int
  }

  public struct Feature: Encodable, Equatable, Sendable {
    public var type = "app.bsky.richtext.facet#link"
    public var uri: String

    enum CodingKeys: String, CodingKey {
      case type = "$type"
      case uri
    }
  }

  public static func detect(in text: String) -> [Facet] {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return [] }

    let fullRange = NSRange(text.startIndex..., in: text)
    return detector.matches(in: text, range: fullRange).compactMap { match in
      guard let range = Range(match.range, in: text), let url = match.url else { return nil }

      let byteStart = text.utf8.distance(from: text.utf8.startIndex, to: range.lowerBound)
      let byteEnd = byteStart + text[range].utf8.count
      return Facet(
        index: ByteRange(byteStart: byteStart, byteEnd: byteEnd),
        features: [Feature(uri: url.absoluteString)]
      )
    }
  }
}
