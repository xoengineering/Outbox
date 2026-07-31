import OutboxKit
import SwiftUI

extension Network {
  /// The official brand color.
  ///
  /// Threads' is black, expressed as `.primary` so it flips with the color scheme.
  var brandColor: AnyShapeStyle {
    switch self {
    case .bluesky: AnyShapeStyle(Color(red: 0x11 / 255, green: 0x85 / 255, blue: 0xFE / 255))
    case .mastodon: AnyShapeStyle(Color(red: 0x63 / 255, green: 0x64 / 255, blue: 0xFF / 255))
    case .threads: AnyShapeStyle(.primary)
    }
  }

  /// A legible content color on top of `brandColor`.
  var brandContrastColor: AnyShapeStyle {
    switch self {
    case .bluesky, .mastodon: AnyShapeStyle(.white)
    case .threads: AnyShapeStyle(.background)
    }
  }
}
