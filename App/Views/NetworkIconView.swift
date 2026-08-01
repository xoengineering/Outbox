import OutboxKit
import SwiftUI

/// A network's brand glyph, rendered in its brand color unless a tint override is given.
///
/// The SVG assets are tight-cropped to the glyph, so `size` is the exact glyph
/// height; width follows each glyph's natural aspect.
struct NetworkIconView: View {
  var network: Network
  var size: CGFloat = 14
  var tint: AnyShapeStyle?

  var body: some View {
    Image("network-\(network.rawValue)")
      .resizable()
      .scaledToFit()
      .frame(height: size)
      .foregroundStyle(tint ?? network.brandColor)
      .accessibilityLabel(network.displayName)
  }
}
