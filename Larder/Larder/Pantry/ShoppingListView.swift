//
//  ShoppingListView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import SwiftData
import SwiftUI

/// What to get on the next shop. Tick things off as they go in the basket,
/// then one tap moves the whole basket into the pantry.
struct ShoppingListView: View {
    let onAdd: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \ShoppingItem.addedAt) private var items: [ShoppingItem]
    @State private var movedCount = 0

    private var toGet: [ShoppingItem] { items.filter { !$0.isBought } }
    private var inBasket: [ShoppingItem] { items.filter(\.isBought) }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !inBasket.isEmpty { moveBar }
        }
        .sensoryFeedback(.success, trigger: movedCount)
        .tapFeedback(items.map(\.isBought))
    }

    // MARK: - The list

    private var list: some View {
        List {
            if !toGet.isEmpty {
                Section("To get") {
                    ForEach(toGet) { row($0) }
                }
            }
            if !inBasket.isEmpty {
                Section("In your basket") {
                    ForEach(inBasket) { row($0) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: items.map(\.isBought))
    }

    private func row(_ item: ShoppingItem) -> some View {
        Button {
            ShoppingRepository.toggleBought(item, in: context)
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isBought ? Theme.Palette.amber : Theme.Palette.textPrimary.opacity(0.35))
                    .symbolEffect(.bounce, value: item.isBought)
                Text(item.emoji)
                    .font(.title2)
                Text(item.name)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(item.isBought ? 0.5 : 1))
                    .strikethrough(item.isBought)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 40)
        }
        .listRowBackground(Theme.Palette.surface)
        .swipeActions {
            Button("Remove", role: .destructive) { ShoppingRepository.remove(item, in: context) }
        }
        .accessibilityLabel(item.name)
        .accessibilityValue(item.isBought ? "In your basket" : "To get")
        .accessibilityHint("Toggles whether it's in your basket")
    }

    private var moveBar: some View {
        Button("Add \(inBasket.count) to my pantry") {
            movedCount += ShoppingRepository.moveBoughtToPantry(in: context)
        }
        .buttonStyle(PillButtonStyle())
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.top, Theme.Spacing.xs)
        .background(Theme.Palette.background)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)
            NutmegView()
                .frame(height: 160)
            VStack(spacing: Theme.Spacing.xs) {
                Text("Your list is empty")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("When something runs out I'll put it here. Or add what you need yourself.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            Spacer(minLength: 0)
            Button("Add something", action: onAdd)
                .buttonStyle(PillButtonStyle())
        }
        .padding(Theme.Spacing.s)
    }
}

/// Picking things to put on the list: the usual suspects to tap, or search
/// for anything, including something that isn't in the catalog.
struct AddToListSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var listed: [ShoppingItem]
    @State private var query = ""

    private var listedIDs: Set<String> { Set(listed.map(\.ingredientID)) }
    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var results: [ResolvedItem] {
        let found = IngredientCatalog.search(query).map(ResolvedItem.init)
        return found.isEmpty && !trimmed.isEmpty ? [ResolvedItem(customName: trimmed)] : found
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    TextField("What do you need?", text: $query)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .onSubmit { if let first = results.first { toggle(first) } }
                        .padding(Theme.Spacing.s)
                        .background(Theme.Palette.surface, in: Capsule())

                    if trimmed.isEmpty {
                        Text("The usual suspects")
                            .font(.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        FlowLayout {
                            ForEach(IngredientCatalog.quickAdd.map(ResolvedItem.init)) { item in
                                ItemChip(item: item, isChecked: listedIDs.contains(item.id)) { toggle(item) }
                            }
                        }
                    } else {
                        FlowLayout {
                            ForEach(results) { item in
                                ItemChip(item: item, isChecked: listedIDs.contains(item.id)) { toggle(item) }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.s)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Add to your list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .tint(Theme.Palette.amber)
        .tapFeedback(listedIDs)
    }

    /// Tapping adds it; tapping again takes it back off.
    private func toggle(_ item: ResolvedItem) {
        if let existing = listed.first(where: { $0.ingredientID == item.id }) {
            ShoppingRepository.remove(existing, in: context)
        } else {
            ShoppingRepository.add([item], in: context)
        }
    }
}
