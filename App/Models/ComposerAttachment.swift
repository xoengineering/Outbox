import Foundation
import OutboxKit

/// An attachment as the composer holds it: either newly picked (bytes in
/// memory) or already stored on disk with the post.
struct ComposerAttachment: Identifiable {
  enum Source {
    case pending(data: Data, fileExtension: String)
    case stored(fileName: String)
  }

  var alt: String
  let id = UUID()
  var previewURL: URL?
  var source: Source

  init(alt: String = "", previewURL: URL? = nil, source: Source) {
    self.alt = alt
    self.previewURL = previewURL
    self.source = source
  }

  var storedFileName: String? {
    if case .stored(let fileName) = source { return fileName }
    return nil
  }

  var pendingAttachment: PendingAttachment? {
    guard case .pending(let data, let fileExtension) = source else { return nil }
    return PendingAttachment(
      alt: alt.isEmpty ? nil : alt,
      data: data,
      fileExtension: fileExtension
    )
  }
}
