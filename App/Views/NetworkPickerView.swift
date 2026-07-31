import OutboxKit
import SwiftUI

/// A branded segmented control for choosing a network: each segment takes an
/// equal share of the width, with the brand glyph and color when selected.
struct NetworkPickerView: View {
  @Binding var selection: Network

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Network.allCases) { network in
        segment(for: network)
      }
    }
    .animation(.smooth(duration: 0.2), value: selection)
  }

  private func segment(for network: Network) -> some View {
    let isSelected = selection == network
    return Button {
      selection = network
    } label: {
      HStack(spacing: 5) {
        NetworkIconView(
          network: network,
          size: 12,
          tint: isSelected ? network.brandContrastColor : nil
        )
        Text(network.displayName)
          .font(.callout.weight(.medium))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
      .background(
        isSelected ? network.brandColor : AnyShapeStyle(.quaternary),
        in: RoundedRectangle(cornerRadius: 7)
      )
      .foregroundStyle(isSelected ? network.brandContrastColor : AnyShapeStyle(.primary))
      .contentShape(RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
  }
}
