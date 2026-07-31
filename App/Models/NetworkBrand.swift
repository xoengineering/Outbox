import OutboxKit
import SwiftUI

extension Network {
  /// The official brand color.
  ///
  /// Threads' is black, expressed as a concrete adaptive color so it flips with
  /// the color scheme. (Hierarchical styles like `.primary` render as vibrant
  /// materials in some contexts, washing out fills.)
  var brandColor: AnyShapeStyle {
    switch self {
    case .bluesky: AnyShapeStyle(Color(red: 0x11 / 255, green: 0x85 / 255, blue: 0xFE / 255))
    case .mastodon: AnyShapeStyle(Color(red: 0x63 / 255, green: 0x64 / 255, blue: 0xFF / 255))
    case .threads: AnyShapeStyle(Color.primary)
    }
  }

  /// A legible content color on top of `brandColor`.
  var brandContrastColor: AnyShapeStyle {
    switch self {
    case .bluesky, .mastodon:
      AnyShapeStyle(.white)
    case .threads:
      #if os(macOS)
        AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
      #else
        AnyShapeStyle(Color(uiColor: .systemBackground))
      #endif
    }
  }
}
