import OutboxKit
import SwiftUI

/// A toggleable endpoint: brand glyph, handle, and live remaining-character count.
///
/// Toggled off: gray background, icon and text screened back.
/// Toggled on: solid brand background, contrast icon and text.
/// Toggled on but over the limit: the brand color screens back so the
/// danger-colored count and outline stay legible.
struct EndpointChipView: View {
  var account: Account
  var isEnabled: Bool
  var remaining: Int
  var toggle: () -> Void

  var body: some View {
    Button(action: toggle) {
      HStack(spacing: 6) {
        NetworkIconView(
          network: account.network,
          size: 13,
          tint: isSolidBrand ? account.network.brandContrastColor : nil
        )
        .opacity(contentOpacity)
        Text(account.handle)
          .lineLimit(1)
          .foregroundStyle(isSolidBrand ? account.network.brandContrastColor : AnyShapeStyle(.primary))
          .opacity(contentOpacity)
        Text("\(remaining)")
          .monospacedDigit()
          .foregroundStyle(countStyle)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(backgroundStyle, in: Capsule())
      .overlay {
        if isOverLimit && isEnabled {
          Capsule().strokeBorder(Palette.danger, lineWidth: 1.5)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(account.network.displayName) \(account.handle)")
    .accessibilityValue(isEnabled ? "on, \(remaining) characters remaining" : "off")
  }

  private var isOverLimit: Bool { remaining < 0 }

  /// Full-strength brand background only when enabled and within the limit.
  private var isSolidBrand: Bool { isEnabled && !isOverLimit }

  private var contentOpacity: Double {
    isSolidBrand ? 1 : Palette.dimmedContentOpacity
  }

  private var backgroundStyle: AnyShapeStyle {
    guard isEnabled else { return Palette.inactiveFill }
    guard !isOverLimit else {
      return AnyShapeStyle(account.network.brandColor.opacity(Palette.overLimitScreenOpacity))
    }
    return account.network.brandColor
  }

  private var countStyle: AnyShapeStyle {
    if isOverLimit { return AnyShapeStyle(Palette.danger) }
    if isSolidBrand { return account.network.brandContrastColor }
    if remaining <= 20 { return AnyShapeStyle(Palette.warning) }
    return AnyShapeStyle(.secondary)
  }
}
