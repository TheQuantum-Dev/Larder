//
//  ShoppingListView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import SwiftData
import SwiftUI

/// What to get on the next shop, grouped by aisle. Type "2 cans of beans"
/// to add something with how much; tick things off as they go in the basket;
/// then one tap puts the whole basket in the pantry, adding to what's there.
struct ShoppingListView: View {
    let onAdd: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \ShoppingItem.addedAt) private var items: [ShoppingItem]
    @State private var movedCount = 0
    @State private var draft = ""
    @State private var editing: ShoppingItem?
    @State private var toast: String?
    @FocusState private var typing: Bool

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
        .overlay(alignment: .bottom) {
            if let toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.onAccent)
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Palette.sage, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                    .padding(Theme.Spacing.s)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: toast)
        .sheet(item: $editing) { item in
            AmountEditorView(emoji: item.emoji, name: item.name, amount: item.amount,
                             emptyNote: "No amount yet. Add one if it helps you remember how much to buy.",
                             onChange: { ShoppingRepository.setAmount($0, for: item, in: context) })
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(.success, trigger: movedCount)
        .tapFeedback(items.map(\.isBought))
    }

    // MARK: - The list

    private var list: some View {
        List {
            Section {
                progressCard
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Theme.Spacing.xs, trailing: 0))
                quickAdd
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            ForEach(aisles, id: \.title) { aisle in
                Section {
                    ForEach(aisle.items) { row($0) }
                } header: {
                    Text("\(aisle.emoji)  \(aisle.title)")
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .textCase(nil)
                }
            }
            if !inBasket.isEmpty {
                Section {
                    ForEach(inBasket) { row($0) }
                } header: {
                    Text("🧺  In your basket")
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .textCase(nil)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: items.map(\.isBought))
    }

    /// How the shop's going: how many left to get, and a bar that fills as
    /// things go in the basket.
    private var progressCard: some View {
        let done = Double(inBasket.count) / Double(max(items.count, 1))
        return HStack(spacing: Theme.Spacing.s) {
            LivelyNutmeg(expression: toGet.isEmpty ? .grin : .smile, seed: 4)
                .frame(width: 60, height: 47)
            VStack(alignment: .leading, spacing: 6) {
                Text(toGet.isEmpty ? "All in the basket!" : "\(toGet.count) to get")
                    .font(.headline)
                    .contentTransition(.numericText())
                Text(inBasket.isEmpty ? "Tick things off as they go in your basket."
                                      : "\(inBasket.count) in your basket")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.background)
                        Capsule().fill(Theme.Palette.amber)
                            .frame(width: max(8, proxy.size.width * done))
                    }
                }
                .frame(height: 8)
            }
            .foregroundStyle(Theme.Palette.textPrimary)
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: done)
        .accessibilityElement(children: .combine)
    }

    /// Type something and it's on the list, with how much if you said.
    private var quickAdd: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.Palette.amber)
            TextField("Add something, like 2 cans of beans", text: $draft)
                .focused($typing)
                .submitLabel(.done)
                .onSubmit(addTyped)
                .foregroundStyle(Theme.Palette.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.s)
        .frame(minHeight: 50)
        .background(Theme.Palette.surface, in: Capsule())
    }

    private func row(_ item: ShoppingItem) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Button {
                ShoppingRepository.toggleBought(item, in: context)
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isBought ? Theme.Palette.amber : Theme.Palette.textPrimary.opacity(0.35))
                        .symbolEffect(.bounce, value: item.isBought)
                    ItemBubble(emoji: item.emoji, size: 40)
                    Text(item.name)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(item.isBought ? 0.5 : 1))
                        .strikethrough(item.isBought)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.amountText.map { "\(item.name), \($0)" } ?? item.name)
            .accessibilityValue(item.isBought ? "In your basket" : "To get")
            .accessibilityHint("Toggles whether it's in your basket")
            Button { editing = item } label: {
                AmountBadge(amount: item.amount)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.amountText.map { "Amount, \($0)" } ?? "Add an amount")
        }
        .frame(minHeight: 50)
        .listRowBackground(Theme.Palette.surface)
        .swipeActions {
            Button("Remove", role: .destructive) { ShoppingRepository.remove(item, in: context) }
        }
    }

    private var moveBar: some View {
        Button {
            let moved = ShoppingRepository.moveBoughtToPantry(in: context)
            movedCount += moved.count
            SoundPlayer.pop()
            show(Self.summary(of: moved))
        } label: {
            Label("Put \(inBasket.count) in my pantry", systemImage: "refrigerator")
        }
        .buttonStyle(PillButtonStyle())
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.top, Theme.Spacing.xs)
        .background(Theme.Palette.background)
    }

    // MARK: - Helpers

    /// Things still to get, grouped by aisle.
    private var aisles: [(title: String, emoji: String, items: [ShoppingItem])] {
        let category = { (item: ShoppingItem) in IngredientCatalog.ingredient(withID: item.ingredientID)?.category }
        var result: [(title: String, emoji: String, items: [ShoppingItem])] = IngredientCategory.allCases.compactMap { aisle in
            let items = toGet.filter { category($0) == aisle }
            return items.isEmpty ? nil : (aisle.title, PantryFilter.emoji(for: aisle), items)
        }
        let other = toGet.filter { category($0) == nil }
        if !other.isEmpty { result.append(("Other", PantryFilter.emoji(for: nil), other)) }
        return result
    }

    private func addTyped() {
        guard let entry = ShoppingEntry.parse(draft) else { return }
        ShoppingRepository.add([entry], in: context)
        SoundPlayer.pop()
        draft = ""
        typing = true
    }

    /// "Added to your pantry: eggs (now 9) and spinach (1 bag)."
    static func summary(of moved: [ShoppingRepository.Moved]) -> String {
        let parts = moved.map { item -> String in
            let name = item.name.lowercased()
            guard let total = item.total else { return name }
            return item.wasInPantry ? "\(name) (now \(total.text))" : "\(name) (\(total.text))"
        }
        return "Added to your pantry: \(OfflineBrain.list(parts))."
    }

    private func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            if toast == message { toast = nil }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)
            LivelyNutmeg(seed: 4)
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
            quickAdd
            Spacer(minLength: 0)
            Button("Browse the usual suspects", action: onAdd)
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
                        .onSubmit(addTyped)
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

    /// Typing "6 eggs" adds eggs with that amount.
    private func addTyped() {
        guard let entry = ShoppingEntry.parse(query) else { return }
        ShoppingRepository.add([entry], in: context)
        query = ""
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
