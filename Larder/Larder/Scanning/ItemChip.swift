//
//  ItemChip.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// A tappable ingredient. Checked chips are filled amber with a checkmark;
/// unchecked "maybe" chips are muted with a dashed edge so they read as
/// suggestions, not answers.
struct ItemChip: View {
    let item: ResolvedItem
    let isChecked: Bool
    var isMaybe = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(item.emoji)
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                // Always in the layout, just invisible when unchecked, so
                // checking one item never resizes it and reflows its
                // neighbors in the flow.
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .symbolEffect(.bounce, value: isChecked)
                    .opacity(isChecked ? 1 : 0)
            }
            .foregroundStyle(Theme.Palette.textPrimary.opacity(isChecked || !isMaybe ? 1 : 0.75))
            .padding(.horizontal, Theme.Spacing.xs)
            .frame(minHeight: 40)
            .background(isChecked ? Theme.Palette.amber.opacity(0.35) : Theme.Palette.surface, in: Capsule())
            .overlay {
                Capsule().strokeBorder(borderColor, style: StrokeStyle(lineWidth: 2, dash: isMaybe && !isChecked ? [5, 4] : []))
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isChecked)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }

    private var borderColor: Color {
        if isChecked { return Theme.Palette.amber }
        return isMaybe ? Theme.Palette.textPrimary.opacity(0.3) : .clear
    }
}
