//
//  RecipesView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import SwiftData
import SwiftUI

/// Quick ways to narrow the list. One at a time, so it's always obvious why
/// something is or isn't showing.
nonisolated enum RecipeFilter: String, CaseIterable, Identifiable, Sendable {
    case all, ready, quick, cheap, noStove, highProtein, lighter, hearty

    var id: String { rawValue }

    /// The chips to offer. The calorie and protein ones go away entirely when
    /// someone has chosen not to see numbers.
    static func available(showsNutrition: Bool) -> [RecipeFilter] {
        showsNutrition ? allCases : allCases.filter { !$0.needsNutrition }
    }

    var needsNutrition: Bool { [.highProtein, .lighter, .hearty].contains(self) }

    var title: String {
        switch self {
        case .all: "All"
        case .ready: "Ready now"
        case .quick: "Quick"
        case .cheap: "Cheap"
        case .noStove: "No stove"
        case .highProtein: "High protein"
        case .lighter: "Lighter"
        case .hearty: "Hearty"
        }
    }

    /// Ready in 15 minutes or less.
    static let quickMinutes = 15
    /// About a dollar a serving or less.
    static let cheapPerServing = 1.0
    /// Grams of protein per serving for "high protein".
    static let highProteinGrams = 25.0
    /// Calories per serving for "lighter", and for "hearty".
    static let lighterKcal = 450.0
    static let heartyKcal = 650.0

    func includes(_ match: RecipeMatch) -> Bool {
        switch self {
        case .all: true
        case .ready: match.isReady
        case .quick: match.recipe.minutes <= Self.quickMinutes
        case .cheap: match.recipe.costPerServing <= Self.cheapPerServing
        case .noStove: match.recipe.needsNoStove
        case .highProtein: match.recipe.nutrition.protein >= Self.highProteinGrams
        case .lighter: match.recipe.nutrition.kcal <= Self.lighterKcal
        case .hearty: match.recipe.nutrition.kcal >= Self.heartyKcal
        }
    }

    /// The filter plus a search on the title, keeping the matcher's order.
    static func apply(_ filter: RecipeFilter, query: String, to matches: [RecipeMatch]) -> [RecipeMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return matches.filter { match in
            filter.includes(match)
                && (trimmed.isEmpty || match.recipe.title.localizedCaseInsensitiveContains(trimmed))
        }
    }
}

/// Every recipe that fits the person's diet, best matches first. The
/// onboarding results screen shows a shortlist; this is the whole book.
struct RecipesView: View {
    @Environment(AppModel.self) private var app
    @Query private var pantry: [PantryItem]

    @State private var filter = RecipeFilter.all
    @State private var query = ""
    @State private var selected: RecipeMatch?

    private var allMatches: [RecipeMatch] {
        RecipeMatcher.matches(pantry: Set(pantry.map(\.ingredientID)), diets: app.profile.dietSet,
                              priorities: app.profile.prioritySet, cooking: app.profile.cookingSet,
                              goal: app.profile.goalContext, maxMissing: .max)
    }

    var body: some View {
        let shown = RecipeFilter.apply(filter, query: query, to: allMatches)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    filterChips
                    if shown.isEmpty {
                        emptyState
                    } else {
                        section("Ready now", shown.filter(\.isReady))
                        section("Just a couple of things away", shown.filter { !$0.isReady && $0.missing.count <= 2 })
                        section("Worth a shop", shown.filter { $0.missing.count > 2 })
                    }
                }
                .padding(Theme.Spacing.s)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Recipes")
            .searchable(text: $query, prompt: "Search recipes")
        }
        .recipeCookingFlow(selected: $selected, diets: app.profile.dietSet, showsNutrition: app.profile.showsNutrition)
        .tapFeedback(filter)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(RecipeFilter.available(showsNutrition: app.profile.showsNutrition)) { option in
                    Button { filter = option } label: {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .padding(.horizontal, Theme.Spacing.s)
                            .frame(minHeight: 40)
                            .background(filter == option ? Theme.Palette.amber.opacity(0.35) : Theme.Palette.surface,
                                        in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(filter == option ? Theme.Palette.amber : .clear, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == option ? .isSelected : [])
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: filter)
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [RecipeMatch]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                ForEach(items) { match in
                    let badges = RecipeBadges.reasons(for: match, priorities: app.profile.prioritySet,
                                                      cooking: app.profile.cookingSet, goal: app.profile.goalContext)
                    RecipeCard(match: match, badges: badges, showsNutrition: app.profile.showsNutrition) { selected = match }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(height: 120)
            Text(query.isEmpty ? "Nothing fits that just yet" : "No recipes called \"\(query)\"")
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            Button("Show everything") {
                filter = .all
                query = ""
            }
            .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.l)
    }
}
