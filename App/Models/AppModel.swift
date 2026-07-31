import Foundation
import Observation
import OutboxKit

/// App-wide state: configured accounts, which endpoints are toggled on,
/// and the wiring between the archive folder, Keychain, and Publisher.
@MainActor @Observable final class AppModel {
  var accounts: [Account] = []
  var enabledAccountIDs: Set<UUID> = []
  let archiveFolder = ArchiveFolder()

  private let accountsRepository: AccountsRepository
  private let keychain = KeychainStore()

  init(accountsRepository: AccountsRepository = .inApplicationSupport()) {
    self.accountsRepository = accountsRepository
    accounts = accountsRepository.load()
    enabledAccountIDs = Set(accounts.map(\.id))
  }

  var enabledAccounts: [Account] {
    accounts.filter { enabledAccountIDs.contains($0.id) }
  }

  func add(_ account: Account, credential: Credential) throws {
    try keychain.save(credential, for: account.id)
    accounts.append(account)
    enabledAccountIDs.insert(account.id)
    try accountsRepository.save(accounts)
  }

  func remove(_ account: Account) {
    try? keychain.delete(for: account.id)
    accounts.removeAll { $0.id == account.id }
    enabledAccountIDs.remove(account.id)
    try? accountsRepository.save(accounts)
  }

  func toggle(_ account: Account) {
    if enabledAccountIDs.contains(account.id) {
      enabledAccountIDs.remove(account.id)
    } else {
      enabledAccountIDs.insert(account.id)
    }
  }

  func publish(body: String) async -> [Publisher.TargetResult] {
    let targets = enabledAccounts.map { account in
      Publisher.Target(account: account, credential: keychain.credential(for: account.id) ?? .none)
    }
    return await archiveFolder.withAccess { baseURL in
      let publisher = Publisher(
        adapters: [
          .bluesky: BlueskyAdapter(),
          .mastodon: MastodonAdapter(),
          .threads: ThreadsAdapter(),
        ],
        store: PostStore(baseDirectory: baseURL)
      )
      return await publisher.publish(body: body, to: targets)
    }
  }
}
