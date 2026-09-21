//
//  FounderNoteView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftUI

/// A short, personal note from the builder, placed right before the paywall so
/// the ask comes from a person and not from a wall of features.
struct FounderNoteView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(spacing: Theme.Spacing.s) {
                    NutmegView()
                        .frame(width: 80)
                    Text(FounderNote.title)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(FounderNote.paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.body)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("— \(FounderNote.name)")
                        .font(.system(.title3, design: .serif).italic())
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                .padding(Theme.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            }
            .padding(Theme.Spacing.s)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Continue", action: onContinue)
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.top, Theme.Spacing.xs)
                .background(Theme.Palette.background)
        }
    }
}
