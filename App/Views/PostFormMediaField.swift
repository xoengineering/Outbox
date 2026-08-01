import SwiftUI

/// The composer's media control: attached files with alt text, plus a picker.
struct PostFormMediaField: View {
  @Binding var attachments: [ComposerAttachment]
  @Binding var removedFileNames: [String]
  @State private var isChoosingMedia = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if !attachments.isEmpty {
        AttachmentEditorView(attachments: $attachments) { attachment in
          if let fileName = attachment.storedFileName { removedFileNames.append(fileName) }
          attachments.removeAll { $0.id == attachment.id }
        }
      }
      Button("Add Media…", systemImage: "paperclip") {
        isChoosingMedia = true
      }
      .buttonStyle(.borderless)
    }
    .fileImporter(
      isPresented: $isChoosingMedia,
      allowedContentTypes: [.image, .movie],
      allowsMultipleSelection: true
    ) { result in
      guard case .success(let urls) = result else { return }
      attachments.append(contentsOf: urls.compactMap(composerAttachment(from:)))
    }
  }

  private func composerAttachment(from url: URL) -> ComposerAttachment? {
    let isScoped = url.startAccessingSecurityScopedResource()
    defer {
      if isScoped { url.stopAccessingSecurityScopedResource() }
    }
    guard let data = try? Data(contentsOf: url) else { return nil }
    return ComposerAttachment(
      previewURL: url,
      source: .pending(data: data, fileExtension: url.pathExtension.lowercased())
    )
  }
}
