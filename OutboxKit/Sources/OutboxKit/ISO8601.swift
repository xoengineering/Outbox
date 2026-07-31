import Foundation

/// Parses ISO 8601 timestamps with or without fractional seconds
/// (Mastodon includes them, atproto and our file format do not).
enum ISO8601 {
  static func date(from string: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: string) ?? ISO8601DateFormatter().date(from: string)
  }

  static func string(from date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
  }
}
