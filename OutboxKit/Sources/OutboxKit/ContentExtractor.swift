import Foundation

/// Pulls #hashtags, @mentions, and URLs out of post text for display.
public enum ContentExtractor {
  public struct Extracted: Equatable, Sendable {
    public var hashtags: [String]
    public var mentions: [String]
    public var urls: [URL]

    public init(hashtags: [String] = [], mentions: [String] = [], urls: [URL] = []) {
      self.hashtags = hashtags
      self.mentions = mentions
      self.urls = urls
    }
  }

  public static func extract(from text: String) -> Extracted {
    Extracted(
      hashtags: unique(text.matches(of: /#[\p{L}\p{N}_]+/).map { String($0.output) }),
      mentions: unique(
        text.matches(of: /@[A-Za-z0-9_.\-]*[A-Za-z0-9](?:@[A-Za-z0-9.\-]*[A-Za-z0-9])?/)
          .map { String($0.output) }),
      urls: unique(detectedURLs(in: text))
    )
  }

  private static func detectedURLs(in text: String) -> [URL] {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return [] }

    let fullRange = NSRange(text.startIndex..., in: text)
    return detector.matches(in: text, range: fullRange).compactMap(\.url)
  }

  private static func unique<Element: Hashable>(_ elements: [Element]) -> [Element] {
    var seen = Set<Element>()
    return elements.filter { seen.insert($0).inserted }
  }
}
