/// Reduces the HTML fragments network APIs return (Mastodon status content)
/// to plain text: a small character scanner, not a regex.
public enum HTMLText {
  public static func plainText(fromHTML html: String) -> String {
    var result = ""
    var index = html.startIndex

    while index < html.endIndex {
      let character = html[index]
      if character == "<" {
        let tagStart = html.index(after: index)
        guard let tagEnd = html[tagStart...].firstIndex(of: ">") else { break }
        let tag = html[tagStart..<tagEnd].lowercased()
        if tag.hasPrefix("br") {
          result.append("\n")
        } else if tag == "/p" {
          result.append("\n\n")
        }
        index = html.index(after: tagEnd)
      } else if character == "&" {
        let entityStart = html.index(after: index)
        if let entityEnd = html[entityStart...].prefix(8).firstIndex(of: ";") {
          result.append(decodeEntity(html[entityStart..<entityEnd]))
          index = html.index(after: entityEnd)
        } else {
          result.append(character)
          index = html.index(after: index)
        }
      } else {
        result.append(character)
        index = html.index(after: index)
      }
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func decodeEntity(_ name: Substring) -> String {
    switch name {
    case "amp": return "&"
    case "apos", "#39": return "'"
    case "gt": return ">"
    case "lt": return "<"
    case "nbsp": return " "
    case "quot": return "\""
    default:
      if name.hasPrefix("#"), let value = UInt32(name.dropFirst()), let scalar = Unicode.Scalar(value) {
        return String(Character(scalar))
      }
      return "&\(name);"
    }
  }
}
