import Foundation
import Synchronization

@testable import OutboxKit

/// Test transport that replays fixture files and records every request it receives.
final class FixtureTransport: HTTPTransport, Sendable {
  struct Stub {
    var fixtureName: String
    var statusCode: Int
  }

  private struct State {
    var requests: [URLRequest] = []
    var stubs: [Stub]
  }

  private let state: Mutex<State>

  init(stubs: [Stub]) {
    state = Mutex(State(stubs: stubs))
  }

  convenience init(fixtureName: String, statusCode: Int = 200) {
    self.init(stubs: [Stub(fixtureName: fixtureName, statusCode: statusCode)])
  }

  var requests: [URLRequest] {
    state.withLock { $0.requests }
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let stub = state.withLock { state in
      state.requests.append(request)
      return state.stubs.removeFirst()
    }

    let url = Bundle.module.url(forResource: stub.fixtureName, withExtension: nil, subdirectory: "Fixtures")!
    let data = try Data(contentsOf: url)
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: stub.statusCode,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!
    return (data, response)
  }

  func requestBodyJSON(at index: Int) throws -> [String: Any] {
    let body = requests[index].httpBody ?? Data()
    return try JSONSerialization.jsonObject(with: body) as? [String: Any] ?? [:]
  }
}
