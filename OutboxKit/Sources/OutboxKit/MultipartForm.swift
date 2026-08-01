import Foundation

/// Builds `multipart/form-data` bodies for media uploads.
struct MultipartForm {
  let boundary: String
  private var body = Data()

  init(boundary: String = "OutboxBoundary-\(UUID().uuidString)") {
    self.boundary = boundary
  }

  var contentType: String {
    "multipart/form-data; boundary=\(boundary)"
  }

  mutating func addField(name: String, value: String) {
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
    body.append("\(value)\r\n")
  }

  mutating func addFile(name: String, fileName: String, mimeType: String, data: Data) {
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
    body.append("Content-Type: \(mimeType)\r\n\r\n")
    body.append(data)
    body.append("\r\n")
  }

  func encoded() -> Data {
    var finished = body
    finished.append("--\(boundary)--\r\n")
    return finished
  }
}

extension Data {
  fileprivate mutating func append(_ string: String) {
    append(Data(string.utf8))
  }
}
