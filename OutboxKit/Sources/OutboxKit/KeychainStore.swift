import Foundation
import Security

/// Stores per-account credentials in the data-protection Keychain.
///
/// Keys are account UUIDs; values are JSON-encoded `Credential`s.
public struct KeychainStore: Sendable {
  public var service: String

  public init(service: String = "com.xoengineering.Outbox") {
    self.service = service
  }

  public enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
  }

  public func save(_ credential: Credential, for accountID: UUID) throws {
    let data = try JSONEncoder().encode(credential)
    try delete(for: accountID)

    let attributes: [CFString: Any] = [
      kSecAttrAccount: accountID.uuidString,
      kSecAttrService: service,
      kSecClass: kSecClassGenericPassword,
      kSecUseDataProtectionKeychain: true,
      kSecValueData: data,
    ]
    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
  }

  public func credential(for accountID: UUID) -> Credential? {
    let query: [CFString: Any] = [
      kSecAttrAccount: accountID.uuidString,
      kSecAttrService: service,
      kSecClass: kSecClassGenericPassword,
      kSecMatchLimit: kSecMatchLimitOne,
      kSecReturnData: true,
      kSecUseDataProtectionKeychain: true,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return try? JSONDecoder().decode(Credential.self, from: data)
  }

  public func delete(for accountID: UUID) throws {
    let query: [CFString: Any] = [
      kSecAttrAccount: accountID.uuidString,
      kSecAttrService: service,
      kSecClass: kSecClassGenericPassword,
      kSecUseDataProtectionKeychain: true,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.unexpectedStatus(status)
    }
  }
}
