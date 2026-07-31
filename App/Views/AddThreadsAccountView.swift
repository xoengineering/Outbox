import OutboxKit
import SwiftUI

/// Adds a Threads endpoint.
///
/// Publishing to Threads is a stub for now:
/// posts are archived locally under Threads/, nothing is sent to the network.
struct AddThreadsAccountView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var errorMessage: String?
  @State private var username = ""

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Username", text: $username, prompt: Text("veganstraightedge"))
            #if os(iOS)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
            #endif
        } footer: {
          Text(
            "Threads publishing isn't wired up yet. Posts to this endpoint are saved "
              + "to your local archive only — nothing is sent to Threads.")
        }

        if let errorMessage {
          Text(errorMessage)
            .foregroundStyle(.red)
        }

        Button("Add") {
          add()
        }
        .disabled(username.isEmpty)
      }
      .textSelection(.enabled)
      .navigationTitle("Add Threads")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    #if os(macOS)
      .frame(minWidth: 420, minHeight: 240)
    #endif
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
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
