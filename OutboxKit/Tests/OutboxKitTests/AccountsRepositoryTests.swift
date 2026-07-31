import Foundation
import Testing

@testable import OutboxKit

@Suite struct AccountsRepositoryTests {
  @Test func roundTripsAccounts() throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("AccountsRepositoryTests-\(UUID().uuidString)")
      .appendingPathComponent("accounts.json")
    let repository = AccountsRepository(fileURL: fileURL)

    #expect(repository.load() == [])

    let accounts = [
      Account(
        handle: "@veganstraightedge.com",
        network: .bluesky,
        serverURL: URL(string: "https://bsky.social")!
      ),
      Account(
        handle: "@veganstraightedge@ruby.social",
        maximumCharacters: 5000,
        network: .mastodon,
        serverURL: URL(string: "https://ruby.social")!
      ),
    ]
    try repository.save(accounts)

    #expect(repository.load() == accounts)
  }
}
