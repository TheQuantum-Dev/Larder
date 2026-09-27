//
//  PantryView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import SwiftData
import SwiftUI

/// Everything in the kitchen, as tiles grouped the way a shop is: produce,
/// dairy, and so on. A card up top says how things stand; chips narrow it to
/// one aisle. Tap a tile to set how much is left, press and hold for more.
struct PantryView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \PantryItem.name) private var pantry: [PantryItem]
    @Query private var shopping: [ShoppingItem]
    @AppStorage(AppSettings.autoAddToShoppingKey) private var autoAddToShopping = true

    @State private var query = ""
    @State private var editing: PantryItem?
    @State private var showsShopping = Self.launchesOnShopping
    @State private var showAddToList = false
    @State private var filter = PantryFilter.all

    private var toGetCount: Int { shopping.filter { !$0.isBought }.count }
    private var lowCount: Int { pantry.filter { PantryAmount.isRunningLow($0.amount) }.count }

    var body: some View {
        NavigationStack {
            Group {
                if showsShopping {
                    ShoppingListView { showAddToList = true }
                } else if pantry.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle(showsShopping ? "Shopping list" : "Pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    PantryModeSwitcher(showsShopping: $showsShopping, toGetCount: toGetCount)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if showsShopping { showAddToList = true } else { app.showScan = true }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                    .accessibilityLabel(showsShopping ? "Add to shopping list" : "Update pantry")
                }
            }
        }
        .sheet(item: $editing) { item in
            PantryAmountEditor(item: item)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddToList) {
            AddToListSheet()
                .presentationDragIndicator(.visible)
        }
        .tapFeedback(pantry.count)
        .tapFeedback(showsShopping)
        .tapFeedback(filter)
    }

    /// `-pantryMode shopping` opens the shopping list (debug builds only).
    private static var launchesOnShopping: Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: "pantryMode") == "shopping"
        #else
        false
        #endif
    }

    // MARK: - The grid

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                summaryCard
                CategoryChips(options: PantryFilter.available(for: pantry.map(\.category)), selection: $filter)
                if sections.isEmpty {
                    Text(query.isEmpty ? "Nothing in this aisle yet." : "Nothing called \"\(query)\" yet. Tap + to add it.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Theme.Spacing.m)
                }
                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("\(section.emoji)  \(section.title) · \(section.items.count)")
                            .font(.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.xs),
                                            GridItem(.flexible(), spacing: Theme.Spacing.xs)],
                                  spacing: Theme.Spacing.xs) {
                            ForEach(section.items) { item in
                                tile(item)
                                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.s)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: pantry.map(\.ingredientID))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: filter)
        }
        .searchable(text: $query, prompt: "Search your pantry")
    }

    /// How the pantry's doing, and the two ways to add to it.
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                LivelyNutmeg(seed: 2)
                    .frame(width: 70, height: 55)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pantry.count == 1 ? "1 thing in your kitchen" : "\(pantry.count) things in your kitchen")
                        .font(.headline)
                    Text(lowCount == 0 ? "Tap anything to say how much is left."
                                       : "\(lowCount) running low. Tap one to update it.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: Theme.Spacing.xs) {
                Button("Update pantry") { app.showScan = true }
                    .buttonStyle(PillButtonStyle())
                Button("Add by hand") {
                    app.scanByHand = true
                    app.showScan = true
                }
                .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
            }
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func tile(_ item: PantryItem) -> some View {
        let isLow = PantryAmount.isRunningLow(item.amount)
        return Button { editing = item } label: {
            VStack(spacing: Theme.Spacing.xs) {
                ItemBubble(emoji: item.emoji)
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                AmountBadge(amount: item.amount, isLow: isLow)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .padding(.horizontal, Theme.Spacing.xs)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(alignment: .topTrailing) {
                if isLow {
                    Circle().fill(Theme.Palette.amber)
                        .frame(width: 10, height: 10)
                        .padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { editing = item } label: { Label("Change amount", systemImage: "number") }
            Button { allGone(item) } label: { Label("All gone", systemImage: "cart.badge.plus") }
            Button(role: .destructive) { remove(item) } label: { Label("Remove", systemImage: "trash") }
        }
        .accessibilityLabel(item.amountText.map { "\(item.name), \($0)\(isLow ? ", running low" : "")" } ?? item.name)
        .accessibilityHint("Set how much is left")
    }

    private var sections: [(title: String, emoji: String, items: [PantryItem])] {
        let visible = pantry.filter { item in
            filter.includes(item.category)
                && (query.isEmpty || item.name.localizedCaseInsensitiveContains(query))
        }
        var result: [(title: String, emoji: String, items: [PantryItem])] = IngredientCategory.allCases.compactMap { category in
            let items = visible.filter { $0.category == category }
            return items.isEmpty ? nil : (category.title, PantryFilter.emoji(for: category), items)
        }
        let other = visible.filter { $0.category == nil }
        if !other.isEmpty { result.append(("Other", PantryFilter.emoji(for: nil), other)) }
        return result
    }

    private func remove(_ item: PantryItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            PantryRepository.remove(ids: [item.ingredientID], in: context)
        }
    }

    /// Takes it off, and puts it on the shopping list if that's switched on.
    private func allGone(_ item: PantryItem) {
        let gone = item.resolved
        remove(item)
        ShoppingRepository.addRunOut([gone], enabled: autoAddToShopping, in: context)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)
            LivelyNutmeg(mood: .peeking)
                .frame(height: 160)
            VStack(spacing: Theme.Spacing.xs) {
                Text("Nothing here yet")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Snap your fridge, scan a barcode, or type things in. I'll keep track of what you've got.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            Spacer(minLength: 0)
            Button("Fill my pantry") { app.showScan = true }
                .buttonStyle(PillButtonStyle())
        }
        .padding(Theme.Spacing.s)
    }
}

/// Setting how much of one pantry item is left. Changes save as they're made.
struct PantryAmountEditor: View {
    let item: PantryItem

    @Environment(\.modelContext) private var context
    @AppStorage(AppSettings.autoAddToShoppingKey) private var autoAddToShopping = true

    var body: some View {
        AmountEditorView(emoji: item.emoji, name: item.name, amount: item.amount,
                         emptyNote: "No amount set. That's fine, most things don't need one.",
                         onChange: { amount in
                             PantryRepository.setAmount(amount?.quantity, unit: amount?.unit, for: item.ingredientID,
                                                        in: context)
                         },
                         destructiveTitle: "All gone, take it off",
                         onDestructive: {
                             let gone = item.resolved
                             PantryRepository.remove(ids: [item.ingredientID], in: context)
                             ShoppingRepository.addRunOut([gone], enabled: autoAddToShopping, in: context)
                         })
    }
}
