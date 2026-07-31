import OutboxKit
import SwiftUI

/// Configured accounts, plus entry points to connect new ones.
struct AccountsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var addingNetwork: Network?

  var body: some View {
    NavigationStack {
      List {
        ForEach(model.accounts) { account in
          HStack {
            Text(account.network.displayName)
              .font(.caption)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(.quaternary, in: Capsule())
            Text(account.handle)
          }
        }
        .onDelete { offsets in
          for offset in offsets {
            model.remove(model.accounts[offset])
          }
        }

        Section {
          Menu("Add Account…") {
            Button("Bluesky") { addingNetwork = .bluesky }
            Button("Mastodon") { addingNetwork = .mastodon }
            Button("Threads (saves locally only)") { addingNetwork = .threads }
          }
        }
      }
      .navigationTitle("Accounts")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .sheet(item: $addingNetwork) { network in
        switch network {
        case .bluesky: AddBlueskyAccountView()
        case .mastodon: AddMastodonAccountView()
        case .threads: AddThreadsAccountView()
        }
      }
    }
    #if os(macOS)
      .frame(minWidth: 420, minHeight: 360)
    #endif
  }
}
