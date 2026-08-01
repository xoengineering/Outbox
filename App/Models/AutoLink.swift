import Foundation

/// Turns plain post text into attributed text with tappable links.
enum AutoLink {
  static func attributed(_ text: String) -> AttributedString {
    var attributed = AttributedString(text)
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return attributed }

    let fullRange = NSRange(text.startIndex..., in: text)
    for match in detector.matches(in: text, range: fullRange) {
      guard let url = match.url,
        let textRange = Range(match.range, in: text),
        let attributedRange = Range(textRange, in: attributed)
      else { continue }
      attributed[attributedRange].link = url
    }
    return attributed
  }
}
