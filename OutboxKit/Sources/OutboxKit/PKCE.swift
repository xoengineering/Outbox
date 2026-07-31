import CryptoKit
import Foundation

/// RFC 7636 Proof Key for Code Exchange: a random verifier and its S256 challenge.
public struct PKCE: Sendable {
  public let verifier: String
  public let challenge: String

  public init() {
    var bytes = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    self.init(verifier: Data(bytes).base64URLEncoded)
  }

  public init(verifier: String) {
    self.verifier = verifier
    let digest = SHA256.hash(data: Data(verifier.utf8))
    challenge = Data(digest).base64URLEncoded
  }
}

extension Data {
  fileprivate var base64URLEncoded: String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
