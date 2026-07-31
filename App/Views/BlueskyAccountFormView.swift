import OutboxKit
import SwiftUI

/// Inline Bluesky connect form: handle + app password (never the main password).
struct BlueskyAccountFormView: View {
  @Environment(AppModel.self) private var model
  @State private var appPassword = ""
  @State private var errorMessage: String?
  @State private var handle = ""
  @State private var isWorking = false

  var body: some View {
    TextField("Handle", text: $handle, prompt: Text("you.bsky.social"))
      #if os(iOS)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
      #endif
    SecureField("App password", text: $appPassword, prompt: Text("xxxx-xxxx-xxxx-xxxx"))

    if let errorMessage {
      Text(errorMessage)
        .foregroundStyle(Palette.danger)
    }

    HStack {
      Text(
        "Create an app password on Bluesky under Settings → Privacy and Security → App Passwords. "
          + "Don't use your main password."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      Spacer()
      if isWorking {
        ProgressView()
          .controlSize(.small)
      }
      Button("Connect") {
        Task { await connect() }
      }
      .disabled(handle.isEmpty || appPassword.isEmpty || isWorking)
    }
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
      appPassword = ""
      handle = ""
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
