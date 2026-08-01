/// One publishing destination: an account handle on a network.
public struct Endpoint: Equatable, Hashable, Sendable {
  public var account: String
  public var network: Network

  public init(account: String, network: Network) {
    self.account = account
    self.network = network
  }
}
