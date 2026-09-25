//
//  RecipeCard.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftData
import SwiftUI

/// A one-tap way to put what a recipe is missing on the shopping list.
struct RecipeListAction {
    let title: String
    let isDone: Bool
    let perform: () -> Void

    /// For a recipe that's only one or two things away.
    static func nudge(for match: RecipeMatch, listed: Set<String>, context: ModelContext) -> RecipeListAction? {
        guard !match.isReady, (1...2).contains(match.missing.count) else { return nil }
        let items = match.missing.compactMap { IngredientCatalog.ingredient(withID: $0.id).map(ResolvedItem.init) }
        guard !items.isEmpty else { return nil }
        let title = items.count == 1 ? "Add \(items[0].name.lowercased()) to my list" : "Add both to my list"
        return RecipeListAction(title: title,
                                isDone: items.allSatisfy { listed.contains($0.id) }) {
            ShoppingRepository.add(items, in: context)
        }
    }
}

/// One recipe in a list: what it is, how long and how much, and whether the
/// pantry already covers it.
struct RecipeCard: View {
    let match: RecipeMatch
    /// Short "picked for you" reasons, worked out from onboarding answers.
    /// Empty when nothing stands out, or when the caller has no profile to draw from.
    var badges: [String] = []
    /// Adds calories and protein under the time and cost.
    var showsNutrition = false
    var listAction: RecipeListAction?
    let action: () -> Void

    private var recipe: Recipe { match.recipe }

    var body: some View {
        VStack(spacing: 0) {
            mainButton
            if let listAction { listButton(listAction) }
        }
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func listButton(_ listAction: RecipeListAction) -> some View {
        Button(action: listAction.perform) {
            Label(listAction.isDone ? "On your shopping list" : listAction.title,
                  systemImage: listAction.isDone ? "checkmark.circle.fill" : "cart.badge.plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, Theme.Spacing.xs)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Theme.Palette.softAmber.opacity(listAction.isDone ? 0.4 : 1), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(listAction.isDone)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.s)
    }

    private var mainButton: some View {
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
            .contentShape(Rectangle())
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
