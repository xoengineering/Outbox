import Foundation

/// A post file as it exists in the archive: parsed content plus its location.
public struct StoredPost: Equatable, Identifiable, Sendable {
  public var file: PostFile
  public var fileURL: URL

  public init(file: PostFile, fileURL: URL) {
    self.file = file
    self.fileURL = fileURL
  }

  public var id: URL { fileURL }

  public enum Status: Equatable, Hashable, Sendable {
    case draft
    case published
  }

  public var status: Status {
    file.metadata.isPublished ? .published : .draft
  }
}
