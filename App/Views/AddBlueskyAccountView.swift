import OutboxKit
import SwiftUI

/// Connects a Bluesky account with an app password (Settings → Privacy and Security
/// → App Passwords on Bluesky) — never the main account password.
struct AddBlueskyAccountView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var appPassword = ""
  @State private var errorMessage: String?
  @State private var handle = ""
  @State private var isWorking = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Handle", text: $handle, prompt: Text("you.bsky.social"))
            #if os(iOS)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
            #endif
          SecureField("App password", text: $appPassword, prompt: Text("xxxx-xxxx-xxxx-xxxx"))
        } footer: {
          Text(
            "Create an app password on Bluesky under Settings → Privacy and Security → App Passwords. "
              + "Don't use your main password.")
        }

        if let errorMessage {
          Text(errorMessage)
            .foregroundStyle(.red)
        }

        Button {
          Task { await connect() }
        } label: {
          if isWorking {
            ProgressView()
          } else {
            Text("Connect")
          }
        }
        .disabled(handle.isEmpty || appPassword.isEmpty || isWorking)
      }
      .navigationTitle("Add Bluesky")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    #if os(macOS)
      .frame(minWidth: 420, minHeight: 280)
    #endif
  }

  private func connect() async {
    isWorking = true
    defer { isWorking = false }
    errorMessage = nil

    let serverURL = URL(string: "https://bsky.social")!
    let identifier = handle.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "@", with: "")
    let credential = Credential.appPassword(identifier: identifier, password: appPassword)

    do {
      let canonicalHandle = try await BlueskyAdapter().verifyCredential(credential, serverURL: serverURL)
      let account = Account(handle: "@\(canonicalHandle)", network: .bluesky, serverURL: serverURL)
      try model.add(account, credential: credential)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
