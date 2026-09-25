//
//  RecipeDetailView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftData
import SwiftUI

/// A whole recipe: cost, what you need and what you have, the steps, and a
/// tip from Nutmeg.
struct RecipeDetailView: View {
    let match: RecipeMatch
    let diets: Set<Diet>
    var showsNutrition = true
    var offersShoppingList = false
    let onCook: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var addedToList = false

    private var recipe: Recipe { match.recipe }
    private var missingIDs: Set<String> { Set(match.missing.map(\.id)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header
                if showsNutrition { nutrition }
                if !recipe.equipment.isEmpty { equipment }
                ingredients
                if offersShoppingList, !match.isReady { addMissingButton }
                steps
                tip
                footnotes
            }
            .padding(Theme.Spacing.s)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
        .safeAreaInset(edge: .bottom) { cookBar }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(recipe.emoji).font(.system(size: 60))
            Text(recipe.title)
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.Palette.textPrimary)
            FlowLayout {
                fact("clock", "\(recipe.minutes) min")
                fact("person.2", recipe.servings == 1 ? "1 serving" : "\(recipe.servings) servings")
                fact("dollarsign.circle", recipe.costText + " each")
                if recipe.needsNoStove { fact("bolt.slash", "No stove needed") }
            }
        }
    }

    private func fact(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.horizontal, Theme.Spacing.xs)
            .frame(minHeight: 40)
            .background(Theme.Palette.surface, in: Capsule())
    }

    private var nutrition: some View {
        let macros = recipe.nutrition
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            heading("Per serving")
            HStack(spacing: Theme.Spacing.xs) {
                macroTile("\(macros.roundedKcal)", "kcal")
                macroTile("\(macros.roundedProtein) g", "protein")
                macroTile("\(macros.roundedCarbs) g", "carbs")
                macroTile("\(macros.roundedFat) g", "fat")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func macroTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var equipment: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            heading("You'll need")
            Text(recipe.equipment.map(\.title).joined(separator: " · "))
                .font(.body)
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            heading("Ingredients")
            VStack(alignment: .leading, spacing: 0) {
                let lines = recipe.visibleIngredients(for: diets)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    ingredientRow(line)
                }
            }
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }

    private var addMissingButton: some View {
        Button {
            ShoppingRepository.addMissing(from: match, in: context)
            addedToList = true
        } label: {
            Label(addedToList ? "On your shopping list" : "Add what's missing to my list",
                  systemImage: addedToList ? "checkmark.circle.fill" : "cart.badge.plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.Palette.softAmber.opacity(addedToList ? 0.4 : 1), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(addedToList)
        .sensoryFeedback(.success, trigger: addedToList)
    }

    private func ingredientRow(_ line: RecipeIngredient) -> some View {
        let needed = missingIDs.contains(line.id)
        return HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: needed ? "cart" : (line.isOptional ? "circle.dotted" : "checkmark.circle.fill"))
                .foregroundStyle(needed ? Theme.Palette.coral : Theme.Palette.textPrimary.opacity(line.isOptional ? 0.4 : 0.9))
                .frame(width: 30)
            Text(line.amount)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(line.isOptional ? 0.6 : 1))
            if line.isOptional {
                Text("optional")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
            }
            Spacer(minLength: 0)
            if needed {
                Text("need")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.Palette.coral)
            }
        }
        .frame(minHeight: 40)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            heading("Steps")
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    Text("\(index + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.Palette.onAccent)
                        .frame(width: 30, height: 30)
                        .background(Theme.Palette.amber, in: Circle())
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(step.text)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let timer = step.timer {
                            Label(TimerText.text(seconds: timer), systemImage: "timer")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.xs)
            }
        }
    }

    private var tip: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(width: 60)
            Text(recipe.tip)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var footnotes: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if diets.contains(.halal), recipe.traits.contains(.meat) {
                Text("This recipe has no pork or alcohol. Use halal-certified meat.")
            }
            Text("Costs are rough estimates and vary by store.")
            if showsNutrition {
                Text("Calories and macros are estimates from USDA FoodData Central. Optional ingredients aren't counted.")
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
    }

    // MARK: - Controls

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(Theme.Palette.textPrimary)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 40, height: 40)
                .background(Theme.Palette.surface, in: Circle())
        }
        .padding(Theme.Spacing.s)
        .accessibilityLabel("Close")
    }

    private var cookBar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if !match.isReady {
                Text("You'll need: " + match.missing
                    .map { IngredientCatalog.ingredient(withID: $0.id)?.name ?? $0.id }
                    .joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            Button("Let's cook this") { onCook(recipe) }
                .buttonStyle(PillButtonStyle())
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.top, Theme.Spacing.xs)
        .background(Theme.Palette.background)
    }
}
