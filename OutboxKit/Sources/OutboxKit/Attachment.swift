import Foundation

/// A media file stored alongside a Post in its day folder.
public struct Attachment: Equatable, Sendable {
  /// Alt text, for people using screen readers.
  public var alt: String?
  /// File name relative to the post file's folder.
  public var fileName: String

  public init(alt: String? = nil, fileName: String) {
    self.alt = alt
    self.fileName = fileName
  }

  public var mimeType: String {
    switch (fileName as NSString).pathExtension.lowercased() {
    case "gif": "image/gif"
    case "heic": "image/heic"
    case "jpeg", "jpg": "image/jpeg"
    case "mov": "video/quicktime"
    case "mp4": "video/mp4"
    case "png": "image/png"
    case "webp": "image/webp"
    default: "application/octet-stream"
    }
  }
}

/// Media chosen in the composer but not yet written to disk.
public struct PendingAttachment: Equatable, Sendable {
  public var alt: String?
  public var data: Data
  public var fileExtension: String

  public init(alt: String? = nil, data: Data, fileExtension: String) {
    self.alt = alt
    self.data = data
    self.fileExtension = fileExtension
  }
}

/// An attachment with its bytes loaded, ready to upload.
public struct OutgoingAttachment: Equatable, Sendable {
  public var alt: String?
  public var data: Data
  public var mimeType: String

  public init(alt: String? = nil, data: Data, mimeType: String) {
    self.alt = alt
    self.data = data
    self.mimeType = mimeType
  }
}
