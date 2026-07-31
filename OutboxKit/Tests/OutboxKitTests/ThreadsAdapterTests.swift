import Foundation
import Testing

@testable import OutboxKit

@Suite struct ThreadsAdapterTests {
  @Test func skipsWithoutTouchingTheNetwork() async throws {
    let account = Account(
      handle: "@veganstraightedge",
      network: .threads,
      serverURL: URL(string: "https://www.threads.net")!
    )

    let outcome = try await ThreadsAdapter().publish(OutgoingPost(body: "hi"), account: account, credential: .none)

    guard case .skipped = outcome else {
      Issue.record("Expected .skipped, got \(outcome)")
      return
    }
  }
}
