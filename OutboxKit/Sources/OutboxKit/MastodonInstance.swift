import Foundation

/// Reads instance-level configuration from `GET /api/v2/instance`.
public struct MastodonInstance: Sendable {
  private let transport: any HTTPTransport

  public init(transport: any HTTPTransport = URLSessionTransport()) {
    self.transport = transport
  }

  /// The instance's status character limit, or nil if it can't be determined.
  public func maximumCharacters(on serverURL: URL) async -> Int? {
    let request = URLRequest(url: serverURL.appending(path: "api/v2/instance"))
    guard let (data, response) = try? await transport.send(request),
      (200..<300).contains(response.statusCode),
      let instance = try? JSONDecoder().decode(InstanceResponse.self, from: data)
    else { return nil }
    return instance.configuration?.statuses?.maxCharacters
  }

  private struct InstanceResponse: Decodable {
    var configuration: Configuration?
  }

  private struct Configuration: Decodable {
    var statuses: Statuses?
  }

  private struct Statuses: Decodable {
    var maxCharacters: Int?

    enum CodingKeys: String, CodingKey {
      case maxCharacters = "max_characters"
    }
  }
}
