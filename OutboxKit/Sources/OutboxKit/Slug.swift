/// Derives URL-and-filename-safe slugs from post content.
public enum Slug {
  /// Builds a slug from the first line of `text`, keeping at most `maximumWords` words.
  public static func from(_ text: String, maximumWords: Int = 6) -> String {
    let firstLine = text.split(separator: "\n", omittingEmptySubsequences: true).first ?? ""
    let words =
      firstLine
      .lowercased()
      .split { !($0.isLetter && $0.isASCII) && !$0.isNumber }
      .filter { $0.allSatisfy(\.isASCII) }
      .prefix(maximumWords)

    guard !words.isEmpty else { return "post" }
    return words.joined(separator: "-")
  }
}
