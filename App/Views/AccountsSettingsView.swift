import OutboxKit
import SwiftUI

/// Account management inside Settings: connected accounts, plus an inline
/// add-account form — pick a network, the form below changes to match.
struct AccountsSettingsView: View {
  @Environment(AppModel.self) private var model
  @State private var newNetwork: Network = .bluesky
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
            Label {
              Text(account.handle)
            } icon: {
              NetworkIconView(network: account.network)
            }
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

      Section("Add Account") {
        NetworkPickerView(selection: $newNetwork)

        switch newNetwork {
        case .bluesky:
          BlueskyAccountFormView()
        case .mastodon:
          MastodonAccountFormView()
        case .threads:
          ThreadsAccountFormView()
        }
      }
    }
    .formStyle(.grouped)
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
