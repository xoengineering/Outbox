import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
  import AppKit
#endif

/// General settings: archive location and display preferences.
struct GeneralSettingsView: View {
  @AppStorage(DateFormatChoice.defaultsKey) private var dateFormat = DateFormatChoice.monthDayYear
  @AppStorage(PostContentSize.defaultsKey) private var contentSize = PostContentSize.medium
  @AppStorage("MonochromeRowIcons") private var monochromeRowIcons = false
  @AppStorage("ShowsRowAvatars") private var showsRowAvatars = true
  @AppStorage("ShowsRowNetworkIcons") private var showsRowNetworkIcons = true
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
        HStack {
          #if os(macOS)
            Button("Open in Finder") {
              NSWorkspace.shared.open(model.archiveFolder.url)
            }
            Button("Choose Folder…") {
              isChoosingFolder = true
            }
            Button("Reset to Default") {
              model.archiveFolder.resetToDefault()
            }
          #endif
        }
      } footer: {
        #if os(macOS)
          Text("Every post is saved here as a Markdown file before anything is sent to a network.")
        #else
          Text(
            "Every post is saved here as a Markdown file before anything is sent to a network. "
              + "Browse them in the Files app under Outbox.")
        #endif
      }

      Section("Display") {
        Toggle("Show avatars in post list", isOn: $showsRowAvatars)
        Toggle("Show network icons in post list", isOn: $showsRowNetworkIcons)
        Toggle("Monochrome post list icons", isOn: $monochromeRowIcons)
        Picker("Date format", selection: $dateFormat) {
          ForEach(DateFormatChoice.allCases) { choice in
            Text(choice.label).tag(choice)
          }
        }
        Picker("Post content size", selection: $contentSize) {
          ForEach(PostContentSize.allCases) { size in
            Text(size.label).tag(size)
          }
        }
        .pickerStyle(.segmented)
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
