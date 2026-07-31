import OutboxKit
import SwiftUI

/// Every color concept in the app, named once.
///
/// Network brand colors live in `NetworkBrand`; everything else is here.
enum Palette {
  // MARK: Semantic colors

  static let danger = Color.red
  static let draft = Color.orange
  static let hashtag = Color.blue
  static let mention = Color.purple
  static let published = Color.green
  static let success = Color.green
  static let warning = Color.orange

  // MARK: Opacities

  /// Icon/text screen for off and over-limit chip states.
  static let dimmedContentOpacity = 0.5
  /// Brand background screen when a toggled-on endpoint is over its limit.
  static let overLimitScreenOpacity = 0.1
  /// Background opacity for tinted capsules (badges, filter pills, token chips).
  static let tintedCapsuleOpacity = 0.15

  // MARK: Fills

  /// Row highlight when its column owns keyboard focus.
  static let focusedSelectionFill = AnyShapeStyle(.tint)
  /// Row highlight when selection is in an unfocused column.
  static let unfocusedSelectionFill = AnyShapeStyle(.quaternary)
  /// Background of inactive pills and chips.
  static let inactiveFill = AnyShapeStyle(.quaternary)

  // MARK: Content on selection fills

  static let selectedContent = AnyShapeStyle(.white)
  static let selectedSecondaryContent = AnyShapeStyle(.white.opacity(0.85))

  // MARK: Capsule recipes

  /// Tinted-capsule background: colored wash when on, quiet gray when off.
  static func capsuleFill(_ tint: AnyShapeStyle, isOn: Bool) -> AnyShapeStyle {
    isOn ? AnyShapeStyle(tint.opacity(tintedCapsuleOpacity)) : inactiveFill
  }

  /// Tinted-capsule content: full-strength tint when on, secondary when off.
  static func capsuleContent(_ tint: AnyShapeStyle, isOn: Bool) -> AnyShapeStyle {
    isOn ? tint : AnyShapeStyle(.secondary)
  }
}

extension StoredPost.Status {
  var color: Color {
    switch self {
    case .draft: Palette.draft
    case .published: Palette.published
    }
  }
}
