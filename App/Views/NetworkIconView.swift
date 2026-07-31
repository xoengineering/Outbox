import OutboxKit
import SwiftUI

/// A network's brand glyph (template-rendered, so it takes the current tint).
struct NetworkIconView: View {
  var network: Network
  var size: CGFloat = 14

  var body: some View {
    Image("network-\(network.rawValue)")
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .accessibilityLabel(network.displayName)
  }
}
