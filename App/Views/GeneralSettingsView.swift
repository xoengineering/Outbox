import SwiftUI
import UniformTypeIdentifiers

/// General settings: where the plaintext archive lives on disk.
struct GeneralSettingsView: View {
  @Environment(AppModel.self) private var model
  @State private var isChoosingFolder = false

  var body: some View {
    Form {
      Section {
        LabeledContent("Archive Folder") {
          Text(model.archiveFolder.url.path)
            .font(.callout.monospaced())
            .textSelection(.enabled)
            .multilineTextAlignment(.trailing)
        }
        #if os(macOS)
          HStack {
            Button("Choose Folder…") {
              isChoosingFolder = true
            }
            Button("Reset to Default") {
              model.archiveFolder.resetToDefault()
            }
          }
        #endif
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
    .formStyle(.grouped)
    .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
      if case .success(let url) = result {
        model.archiveFolder.choose(url)
        Task { await model.reloadPosts() }
      }
    }
  }
}
