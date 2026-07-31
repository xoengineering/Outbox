import Foundation

/// Persists the list of configured accounts as JSON.
///
/// Credentials never live here — they belong to `KeychainStore`.
public struct AccountsRepository: Sendable {
  public var fileURL: URL

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  public static func inApplicationSupport() -> AccountsRepository {
    let directory = URL.applicationSupportDirectory.appending(path: "Outbox", directoryHint: .isDirectory)
    return AccountsRepository(fileURL: directory.appending(path: "accounts.json"))
  }

  public func load() -> [Account] {
    guard let data = try? Data(contentsOf: fileURL) else { return [] }
    return (try? JSONDecoder().decode([Account].self, from: data)) ?? []
  }

  public func save(_ accounts: [Account]) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(accounts).write(to: fileURL, options: .atomic)
  }
}
