/// A secret needed to publish to an account.
///
/// Stored in the Keychain, never on disk.
public enum Credential: Codable, Equatable, Sendable {
  case accessToken(String)
  case appPassword(identifier: String, password: String)
  /// Threads pairs a long-lived token with the numeric user ID every call needs.
  case threads(userID: String, accessToken: String)
  case none
}
