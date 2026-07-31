import Foundation
import Security

/// Stores per-account credentials in the data-protection Keychain.
///
/// Keys are account UUIDs; values are JSON-encoded `Credential`s.
/// Builds without a real signing identity (ad-hoc/unsigned) can't use the
/// data-protection keychain, so operations fall back to the login keychain
/// when the entitlement is missing.
public struct KeychainStore: Sendable {
  public var service: String

  public init(service: String = "engineering.xo.Outbox") {
    self.service = service
  }

  public enum KeychainError: Error, Equatable, LocalizedError {
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
      switch self {
      case .unexpectedStatus(let status):
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
        return "Keychain error \(status): \(message)"
      }
    }
  }

  public func save(_ credential: Credential, for accountID: UUID) throws {
    let data = try JSONEncoder().encode(credential)
    try delete(for: accountID)

    let attributes: [CFString: Any] = [
      kSecAttrAccount: accountID.uuidString,
      kSecAttrService: service,
      kSecClass: kSecClassGenericPassword,
      kSecValueData: data,
    ]
    let status = withEntitlementFallback { useDataProtection in
      var attributes = attributes
      attributes[kSecUseDataProtectionKeychain] = useDataProtection
      return SecItemAdd(attributes as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
  }

  public func credential(for accountID: UUID) -> Credential? {
    let query: [CFString: Any] = [
      kSecAttrAccount: accountID.uuidString,
      kSecAttrService: service,
      kSecClass: kSecClassGenericPassword,
      kSecMatchLimit: kSecMatchLimitOne,
      kSecReturnData: true,
    ]
    for useDataProtection in [true, false] {
      var query = query
      query[kSecUseDataProtectionKeychain] = useDataProtection
      var result: CFTypeRef?
      guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
        let data = result as? Data
      else { continue }
      return try? JSONDecoder().decode(Credential.self, from: data)
    }
    return nil
  }

  public func delete(for accountID: UUID) throws {
    let query: [CFString: Any] = [
      kSecAttrAccount: accountID.uuidString,
      kSecAttrService: service,
      kSecClass: kSecClassGenericPassword,
    ]
    for useDataProtection in [true, false] {
      var query = query
      query[kSecUseDataProtectionKeychain] = useDataProtection
      let status = SecItemDelete(query as CFDictionary)
      let isAcceptable =
        status == errSecSuccess || status == errSecItemNotFound || status == errSecMissingEntitlement
      guard isAcceptable else { throw KeychainError.unexpectedStatus(status) }
    }
  }

  private func withEntitlementFallback(_ operation: (_ useDataProtection: Bool) -> OSStatus) -> OSStatus {
    let status = operation(true)
    guard status == errSecMissingEntitlement else { return status }
    return operation(false)
  }
}
