//
//  QuizScreen.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// One multi-select question. It works for any enum that conforms to
/// `QuizOption`, which is how the diet, cooking and priorities screens share
/// a single view.
struct QuizScreen<Option: QuizOption>: View {
    let title: String
    let subtitle: String
    @Binding var selection: MultiSelection<Option>
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.s) {
                    NutmegView()
                        .frame(width: 80)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(title)
                            .font(.title2.bold())
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(Array(Option.allCases)) { option in
                    OptionRow(emoji: option.emoji,
                              title: option.title,
                              isSelected: selection.contains(option)) {
                        selection.toggle(option)
                    }
                }
            }
            .padding(Theme.Spacing.s)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Continue", action: onContinue)
                .buttonStyle(PillButtonStyle())
                .disabled(selection.isEmpty)
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.top, Theme.Spacing.xs)
                .background(Theme.Palette.background)
        }
        // A light tick on every tap, select or deselect.
        .sensoryFeedback(.selection, trigger: selection.items)
    }
}

private struct OptionRow: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                Text(emoji).font(.title2)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: Theme.Spacing.xs)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.Palette.amber : Theme.Palette.textPrimary.opacity(0.35))
                    .symbolEffect(.bounce, value: isSelected)
            }
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Theme.Palette.amber.opacity(0.25) : Theme.Palette.surface,
                        in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(isSelected ? Theme.Palette.amber : .clear, lineWidth: 3)
            }
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
