import OutboxKit
import SwiftUI

/// A network's brand glyph, rendered in its brand color.
struct NetworkIconView: View {
  var network: Network
  var size: CGFloat = 14

  var body: some View {
    Image("network-\(network.rawValue)")
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .foregroundStyle(brandColor)
      .accessibilityLabel(network.displayName)
  }

  private var brandColor: AnyShapeStyle {
    switch network {
    case .bluesky: AnyShapeStyle(Color(red: 0x11 / 255, green: 0x85 / 255, blue: 0xFE / 255))
    case .mastodon: AnyShapeStyle(Color(red: 0x63 / 255, green: 0x64 / 255, blue: 0xFF / 255))
    // Threads' brand color is black; use .primary so it inverts in dark mode.
    case .threads: AnyShapeStyle(.primary)
    }
  }
}
