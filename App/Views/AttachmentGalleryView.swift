import OutboxKit
import SwiftUI

/// A post's media, rendered in the show view with its alt text.
struct AttachmentGalleryView: View {
  var attachments: [Attachment]
  var urlForAttachment: (Attachment) -> URL

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(attachments, id: \.fileName) { attachment in
        VStack(alignment: .leading, spacing: 4) {
          AsyncImage(url: urlForAttachment(attachment)) { image in
            image
              .resizable()
              .scaledToFit()
          } placeholder: {
            RoundedRectangle(cornerRadius: 10)
              .fill(Palette.editorFill)
              .frame(height: 120)
              .overlay {
                Image(systemName: "photo")
                  .foregroundStyle(.secondary)
              }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .accessibilityLabel(attachment.alt ?? "Image with no alt text")

          if let alt = attachment.alt, !alt.isEmpty {
            Text(alt)
              .font(.caption)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          } else {
            Text("No alt text")
              .font(.caption)
              .foregroundStyle(Palette.warning)
          }
        }
      }
    }
  }
}
