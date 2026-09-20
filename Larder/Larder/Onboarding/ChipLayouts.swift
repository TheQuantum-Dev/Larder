//
//  ChipLayouts.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// Lays views out left to right and wraps onto a new line when a row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = Theme.Spacing.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Spreads views around a fixed-height area in a repeatable "tossed" pattern.
struct ScatterLayout: Layout {
    var height: CGFloat = 260

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 300, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            // Golden-ratio steps give an even-looking spread with no randomness,
            // so the layout is the same every time.
            let fx = (Double(index) * 0.618 + 0.13).truncatingRemainder(dividingBy: 1)
            let fy = (Double(index) * 0.382 + 0.27).truncatingRemainder(dividingBy: 1)
            let x = bounds.minX + (bounds.width - size.width) * fx
            let y = bounds.minY + (bounds.height - size.height) * fy
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
        }
    }
}
