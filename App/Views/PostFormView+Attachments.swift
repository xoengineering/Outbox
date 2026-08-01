import OutboxKit
import SwiftUI

extension PostFormView {
  /// Loads a post's stored media into the composer for editing.
  func loadStoredAttachments(from post: StoredPost) -> [ComposerAttachment] {
    post.file.metadata.media.map { attachment in
      ComposerAttachment(
        alt: attachment.alt ?? "",
        previewURL: model.attachmentURL(attachment, for: post),
        source: .stored(fileName: attachment.fileName)
      )
    }
  }

  /// Applies media edits — alt text changes, removals, and additions — to a saved post.
  func saveAttachmentChanges(to post: StoredPost) async throws {
    let keptMedia = attachments.compactMap { composer -> Attachment? in
      guard let fileName = composer.storedFileName else { return nil }
      return Attachment(alt: composer.alt.isEmpty ? nil : composer.alt, fileName: fileName)
    }
    if keptMedia != post.file.metadata.media || !removedFileNames.isEmpty {
      try await model.updateAttachments(keptMedia, removing: removedFileNames, on: post)
      removedFileNames = []
    }

    let newMedia = attachments.compactMap(\.pendingAttachment)
    guard !newMedia.isEmpty else { return }
    let current = model.posts.first { $0.id == post.id } ?? post
    try await model.addAttachments(newMedia, to: current)
  }
}
