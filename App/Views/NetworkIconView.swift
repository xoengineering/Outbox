import OutboxKit
import SwiftUI

/// A network's brand glyph, rendered in its brand color unless a tint override is given.
struct NetworkIconView: View {
  var network: Network
  var size: CGFloat = 14
  var tint: AnyShapeStyle?

  var body: some View {
    Image("network-\(network.rawValue)")
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .foregroundStyle(tint ?? network.brandColor)
      .accessibilityLabel(network.displayName)
  }
}
