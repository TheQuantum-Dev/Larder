//
//  RecipeCard.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftUI

/// One recipe in a list: what it is, how long and how much, and whether the
/// pantry already covers it.
struct RecipeCard: View {
    let match: RecipeMatch
    /// Short "picked for you" reasons, worked out from onboarding answers.
    /// Empty when nothing stands out, or when the caller has no profile to draw from.
    var badges: [String] = []
    /// Adds calories and protein under the time and cost.
    var showsNutrition = false
    let action: () -> Void

    private var recipe: Recipe { match.recipe }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                Text(recipe.emoji)
                    .font(.largeTitle)
                    .frame(width: 60, height: 60)
                    .background(Theme.Palette.amber.opacity(0.25), in: Circle())

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(recipe.title)
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(details)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    if showsNutrition {
                        Text(recipe.nutrition.summaryText)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    }
                    if !badges.isEmpty {
                        badgeRow
                    }
                    status
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.4))
            }
            .padding(Theme.Spacing.s)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var details: String {
        var parts = ["\(recipe.minutes) min", recipe.costText]
        if recipe.needsNoStove { parts.append("no stove") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var status: some View {
        if match.isReady {
            // Sage is reserved for success, and "you have everything" is one.
            Label("Ready now", systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(Theme.Palette.onAccent)
                .padding(.horizontal, Theme.Spacing.xs)
                .frame(minHeight: 30)
                .background(Theme.Palette.sage, in: Capsule())
        } else {
            Text("Missing: " + missingNames)
                .font(.footnote)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .multilineTextAlignment(.leading)
        }
    }

    private var badgeRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(badges, id: \.self) { badge in
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .padding(.horizontal, Theme.Spacing.xs)
                    .frame(minHeight: 20)
                    .background(Theme.Palette.background, in: Capsule())
            }
        }
    }

    private var missingNames: String {
        match.missing
            .map { IngredientCatalog.ingredient(withID: $0.id)?.name ?? $0.id }
            .joined(separator: ", ")
    }
}
