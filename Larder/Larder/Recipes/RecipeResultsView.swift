//
//  RecipeResultsView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftUI

/// Recipes ranked for a pantry: what can be cooked right now first, then what
/// is only a few items away. The cards spring in one after another.
struct RecipeResultsView: View {
    let matches: [RecipeMatch]
    /// True when nothing was close, so these are just the easiest to get to.
    var stretched = false
    let diets: Set<Diet>
    let onCook: (Recipe) -> Void
    let onAddMore: () -> Void

    @State private var selected: RecipeMatch?
    @State private var appeared = false

    private var ready: [RecipeMatch] { matches.filter(\.isReady) }
    private var almost: [RecipeMatch] { matches.filter { !$0.isReady } }

    var body: some View {
        Group {
            if matches.isEmpty {
                emptyState
            } else {
                results
            }
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .sheet(item: $selected) { match in
            RecipeDetailView(match: match, diets: diets) { recipe in
                selected = nil
                onCook(recipe)
            }
        }
        .onAppear {
            appeared = true
            openDebugRecipe()
        }
    }

    private var results: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header

                if !ready.isEmpty {
                    section("Ready to cook now", ready, firstIndex: 0)
                }
                if !almost.isEmpty {
                    section(almostTitle, almost, firstIndex: ready.count)
                }

                Button("Add more ingredients", action: onAddMore)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(Theme.Spacing.s)
        }
    }

    /// Shown only if no recipe could be found at all, so the screen still has
    /// Nutmeg and a clear next step instead of empty space.
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)
            NutmegView()
                .frame(height: 160)
            VStack(spacing: Theme.Spacing.xs) {
                Text("Let's find you something")
                    .font(.title.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("I need a few more ingredients to work with. Add what you have and I'll look again.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            Spacer(minLength: 0)
            Button("Add ingredients", action: onAddMore)
                .buttonStyle(PillButtonStyle())
        }
        .padding(Theme.Spacing.s)
    }

    // MARK: - Pieces

    private var almostTitle: String {
        if stretched { return "Easiest to get to" }
        return ready.isEmpty ? "Just a few items away" : "Almost there"
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(width: 80)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(headline)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(subheadline)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headline: String {
        if stretched { return "Let's go shopping!" }
        switch ready.count {
        case 0: return "So close!"
        case 1: return "You can make 1 thing right now!"
        default: return "You can make \(ready.count) things right now!"
        }
    }

    private var subheadline: String {
        if stretched { return "You're a few items short of these, but they're the easiest ones to get to." }
        if ready.isEmpty { return "Nothing's fully ready, but these are only a few items away." }
        return "Here's what I'd cook first. Tap one to see the recipe."
    }

    private func section(_ title: String, _ items: [RecipeMatch], firstIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, match in
                RecipeCard(match: match) { selected = match }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .animation(.spring(response: 0.55, dampingFraction: 0.75)
                        .delay(Double(min(firstIndex + offset, 8)) * 0.07), value: appeared)
            }
        }
    }

    /// `-openRecipe egg-fried-rice` opens that recipe straight away (debug builds only).
    private func openDebugRecipe() {
        #if DEBUG
        if let id = UserDefaults.standard.string(forKey: "openRecipe"),
           let match = matches.first(where: { $0.recipe.id == id }) {
            selected = match
        }
        #endif
    }
}
