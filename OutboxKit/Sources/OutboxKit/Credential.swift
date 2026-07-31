/// A secret needed to publish to an account. Stored in the Keychain, never on disk.
public enum Credential: Codable, Equatable, Sendable {
  case accessToken(String)
  case appPassword(identifier: String, password: String)
  case none
}
