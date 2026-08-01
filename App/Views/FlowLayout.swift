import SwiftUI

/// Lays out subviews left to right, wrapping whole items onto new lines,
/// like text wraps words.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    return arrangement(of: sizes, in: proposal.width ?? .infinity).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let offsets = arrangement(of: sizes, in: bounds.width).offsets
    for (subview, offset) in zip(subviews, offsets) {
      subview.place(
        at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
        proposal: .unspecified
      )
    }
  }

  private func arrangement(of sizes: [CGSize], in maxWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
    var offsets: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var widestRow: CGFloat = 0

    for size in sizes {
      if x > 0, x + size.width > maxWidth {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      offsets.append(CGPoint(x: x, y: y))
      x += size.width + spacing
      widestRow = max(widestRow, x - spacing)
      rowHeight = max(rowHeight, size.height)
    }
    return (offsets, CGSize(width: widestRow, height: y + rowHeight))
  }
}
