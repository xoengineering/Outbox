import OutboxKit
import SwiftUI

/// Account management inside Settings: connected accounts, add, and remove.
struct AccountsSettingsView: View {
  @Environment(AppModel.self) private var model
  @State private var addingNetwork: Network?
  @State private var removingAccount: Account?

  var body: some View {
    Form {
      Section {
        if model.accounts.isEmpty {
          Text("No accounts yet.")
            .foregroundStyle(.secondary)
        }
        ForEach(model.accounts) { account in
          HStack {
            Label(account.handle, systemImage: account.network.symbolName)
            Spacer()
            Text(account.network.displayName)
              .font(.caption)
              .foregroundStyle(.secondary)
            Button("Remove", systemImage: "minus.circle.fill") {
              removingAccount = account
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Remove this account")
          }
        }
      } footer: {
        Text("Removing an account deletes its credential from your Keychain. Archived post files stay on disk.")
      }

      Section {
        Menu("Add Account…") {
          Button("Bluesky") { addingNetwork = .bluesky }
          Button("Mastodon") { addingNetwork = .mastodon }
          Button("Threads (saves locally only)") { addingNetwork = .threads }
        }
      }
    }
    .formStyle(.grouped)
    .sheet(item: $addingNetwork) { network in
      switch network {
      case .bluesky: AddBlueskyAccountView()
      case .mastodon: AddMastodonAccountView()
      case .threads: AddThreadsAccountView()
      }
    }
    .confirmationDialog(
      "Remove \(removingAccount?.handle ?? "this account")?",
      isPresented: Binding(
        get: { removingAccount != nil },
        set: { if !$0 { removingAccount = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("Remove", role: .destructive) {
        if let account = removingAccount {
          model.remove(account)
        }
        removingAccount = nil
      }
    } message: {
      Text("Its credential is deleted from your Keychain. Archived files stay on disk.")
    }
  }
}
