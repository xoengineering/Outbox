import OutboxKit
import SwiftUI

/// Inline Threads form.
///
/// Publishing to Threads is a stub for now: posts are archived locally
/// under Threads/, nothing is sent to the network.
struct ThreadsAccountFormView: View {
  @Environment(AppModel.self) private var model
  @State private var errorMessage: String?
  @State private var username = ""

  var body: some View {
    TextField("Username", text: $username, prompt: Text("veganstraightedge"))
      #if os(iOS)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
      #endif

    if let errorMessage {
      Text(errorMessage)
        .foregroundStyle(.red)
    }

    HStack {
      Text(
        "Threads publishing isn't wired up yet. Posts to this endpoint are saved "
          + "to your local archive only — nothing is sent to Threads."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      Spacer()
      Button("Add") {
        add()
      }
      .disabled(username.isEmpty)
    }
  }

  private func add() {
    let cleaned = username.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "@", with: "")
    let account = Account(
      handle: "@\(cleaned)",
      network: .threads,
      serverURL: URL(string: "https://www.threads.net")!
    )
    do {
      try model.add(account, credential: .none)
      username = ""
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
