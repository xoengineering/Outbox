import SwiftUI

/// The composer's media strip: thumbnails with alt-text fields and a remove button.
struct AttachmentEditorView: View {
  @Binding var attachments: [ComposerAttachment]
  var onRemove: (ComposerAttachment) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach($attachments) { $attachment in
        HStack(alignment: .top, spacing: 10) {
          thumbnail(for: attachment)
          VStack(alignment: .leading, spacing: 4) {
            TextField("Alt text — describe this image", text: $attachment.alt, axis: .vertical)
              .textFieldStyle(.roundedBorder)
              .lineLimit(1...3)
            if attachment.alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              Text("No alt text yet — screen readers will skip this.")
                .font(.caption)
                .foregroundStyle(Palette.warning)
            }
          }
          Button("Remove", systemImage: "trash") {
            onRemove(attachment)
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .foregroundStyle(Palette.danger)
          .help("Remove this attachment")
        }
      }
    }
  }

  @ViewBuilder
  private func thumbnail(for attachment: ComposerAttachment) -> some View {
    Group {
      if let previewURL = attachment.previewURL {
        AsyncImage(url: previewURL) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          Image(systemName: "photo")
            .foregroundStyle(.secondary)
        }
      } else {
        Image(systemName: "photo")
          .foregroundStyle(.secondary)
      }
    }
    .frame(width: 64, height: 64)
    .background(Palette.editorFill, in: RoundedRectangle(cornerRadius: 8))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
