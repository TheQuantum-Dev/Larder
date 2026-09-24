//
//  PantryView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import SwiftData
import SwiftUI

/// Everything in the kitchen, grouped the way a shop is: produce, dairy,
/// and so on. Tap something to set how much is left, swipe to take it off.
struct PantryView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \PantryItem.name) private var pantry: [PantryItem]

    @State private var query = ""
    @State private var editing: PantryItem?

    var body: some View {
        NavigationStack {
            Group {
                if pantry.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { app.showScan = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                    .accessibilityLabel("Add to pantry")
                }
            }
        }
        .sheet(item: $editing) { item in
            PantryAmountEditor(item: item)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .tapFeedback(pantry.count)
    }

    // MARK: - The list

    private var list: some View {
        List {
            Section {
                Text(countLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.s, bottom: 0, trailing: Theme.Spacing.s))
            }

            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        row(item)
                            .swipeActions {
                                Button("Remove", role: .destructive) { remove(item) }
                            }
                    }
                }
            }

            if !query.isEmpty, sections.isEmpty {
                Text("Nothing called \"\(query)\" yet. Tap + to add it.")
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .listRowBackground(Theme.Palette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $query, prompt: "Search your pantry")
    }

    private func row(_ item: PantryItem) -> some View {
        Button { editing = item } label: {
            HStack(spacing: Theme.Spacing.s) {
                Text(item.emoji)
                    .font(.title2)
                Text(item.name)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: Theme.Spacing.xs)
                if let amount = item.amountText {
                    Text(amount)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                } else {
                    Text("Add amount")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.4))
                }
            }
            .frame(minHeight: 40)
        }
        .listRowBackground(Theme.Palette.surface)
        .accessibilityLabel(item.amountText.map { "\(item.name), \($0)" } ?? item.name)
        .accessibilityHint("Set how much is left")
    }

    private var countLine: String {
        pantry.count == 1 ? "1 thing in your kitchen" : "\(pantry.count) things in your kitchen"
    }

    private var sections: [(title: String, items: [PantryItem])] {
        let visible = query.isEmpty
            ? pantry
            : pantry.filter { $0.name.localizedCaseInsensitiveContains(query) }
        var result: [(title: String, items: [PantryItem])] = IngredientCategory.allCases.compactMap { category in
            let items = visible.filter { $0.category == category }
            return items.isEmpty ? nil : (category.title, items)
        }
        let other = visible.filter { $0.category == nil }
        if !other.isEmpty { result.append(("Other", other)) }
        return result
    }

    private func remove(_ item: PantryItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            PantryRepository.remove(ids: [item.ingredientID], in: context)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)
            NutmegView()
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

/// Setting how much of one thing is left. Changes save as they're made;
/// there's no separate save step to forget.
struct PantryAmountEditor: View {
    let item: PantryItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var quantity: Double?
    @State private var unit: PantryUnit

    init(item: PantryItem) {
        self.item = item
        _quantity = State(initialValue: item.quantity)
        _unit = State(initialValue: PantryUnit(rawValue: item.unit ?? "") ?? .items)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.s) {
                Text(item.emoji)
                    .font(.largeTitle)
                Text(item.name)
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Theme.Palette.textPrimary)

            if let quantity {
                amountControls(quantity)
            } else {
                Text("No amount set. That's fine, most things don't need one.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                Button("Set an amount") { set(unit.starting) }
                    .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
            }

            Spacer(minLength: 0)

            Button("All gone, take it off", role: .destructive) {
                PantryRepository.remove(ids: [item.ingredientID], in: context)
                dismiss()
            }
            .font(.body.weight(.semibold))
            .frame(minHeight: 44)
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.background.ignoresSafeArea())
        .tint(Theme.Palette.amber)
        .tapFeedback(quantity)
    }

    private func amountControls(_ quantity: Double) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                stepButton("minus", direction: -1, disabled: quantity <= 0)
                Text(PantryAmount.text(quantity: quantity, unit: unit.rawValue) ?? "")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: quantity))
                    .frame(minWidth: 140)
                    .foregroundStyle(Theme.Palette.textPrimary)
                stepButton("plus", direction: 1, disabled: false)
            }

            Picker("Unit", selection: $unit) {
                ForEach(PantryUnit.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .onChange(of: unit) { _, newUnit in set(newUnit.starting) }

            Button("Clear amount") { set(nil) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
        }
    }

    private func stepButton(_ symbol: String, direction: Int, disabled: Bool) -> some View {
        Button {
            set(PantryAmount.stepped(quantity ?? 0, by: direction, unit: unit))
        } label: {
            Image(systemName: symbol)
                .font(.title2.bold())
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 60, height: 60)
                .background(Theme.Palette.surface, in: Circle())
        }
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(direction > 0 ? "More" : "Less")
    }

    private func set(_ newQuantity: Double?) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { quantity = newQuantity }
        PantryRepository.setAmount(newQuantity, unit: unit, for: item.ingredientID, in: context)
    }
}
