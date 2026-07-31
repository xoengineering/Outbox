import SwiftUI
import UniformTypeIdentifiers

/// App settings: where the plaintext archive lives on disk.
struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var isChoosingFolder = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(model.archiveFolder.url.path)
            .font(.callout.monospaced())
            .textSelection(.enabled)
          #if os(macOS)
            Button("Choose Folder…") {
              isChoosingFolder = true
            }
            Button("Reset to Default") {
              model.archiveFolder.resetToDefault()
            }
          #endif
        } header: {
          Text("Archive Folder")
        } footer: {
          #if os(macOS)
            Text("Every post is saved here as a Markdown file before anything is sent to a network.")
          #else
            Text(
              "Every post is saved here as a Markdown file before anything is sent to a network. "
                + "Browse them in the Files app under Outbox.")
          #endif
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
        if case .success(let url) = result {
          model.archiveFolder.choose(url)
        }
      }
    }
    #if os(macOS)
      .frame(minWidth: 480, minHeight: 240)
    #endif
  }
}
