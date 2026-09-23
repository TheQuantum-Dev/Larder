//
//  ScanConfirmView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// Shows what the scan found and lets the person fix it: uncheck what's
/// wrong, tap the maybes they do have, and add whatever was missed. Nothing
/// the scan guessed is trusted until they continue.
struct ScanConfirmView: View {
    let review: ScanReview
    let onContinue: () -> Void

    @State private var query: String
    @FocusState private var searchFocused: Bool

    init(review: ScanReview, initialQuery: String = "", onContinue: @escaping () -> Void) {
        self.review = review
        self.onContinue = onContinue
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header

                if !review.looksRight.isEmpty {
                    section("Looks right") {
                        chips(review.looksRight, isMaybe: false)
                    }
                }

                if !review.maybe.isEmpty {
                    section("Not sure about these", note: "Tap the ones you actually have.") {
                        chips(review.maybe, isMaybe: true)
                    }
                }

                if !review.added.isEmpty {
                    section("You added") {
                        chips(review.added, isMaybe: false)
                    }
                }

                addSection
            }
            .padding(Theme.Spacing.s)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(continueTitle, action: onContinue)
                .buttonStyle(PillButtonStyle())
                .disabled(review.selected.isEmpty)
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.top, Theme.Spacing.xs)
                .background(Theme.Palette.background)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        // A light tick whenever something is checked or unchecked.
        .tapFeedback(review.checked)
    }

    // MARK: - Pieces

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
        if review.isManual { return "What's in your kitchen?" }
        return review.foundNothing ? "I couldn't spot much" : "Here's what I spotted"
    }

    private var subheadline: String {
        if review.isManual { return "Tap what you have, or search for anything else." }
        return review.foundNothing
            ? "No worries. Add what you have and I'll cook something up."
            : "Tap anything I got wrong, and add what I missed."
    }

    private func section<Content: View>(_ title: String, note: String? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chips(_ items: [ResolvedItem], isMaybe: Bool) -> some View {
        FlowLayout {
            ForEach(items) { item in
                ItemChip(item: item, isChecked: review.isChecked(item), isMaybe: isMaybe) {
                    review.toggle(item)
                }
            }
        }
    }

    // MARK: - Adding what was missed

    private var addSection: some View {
        section("Add what I missed") {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.5))
                TextField("Search or type an ingredient", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(addTypedText)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.s)
            .frame(minHeight: 50)
            .background(Theme.Palette.surface, in: Capsule())

            FlowLayout {
                ForEach(addOptions) { item in
                    ItemChip(item: item, isChecked: review.isChecked(item)) {
                        review.isChecked(item) ? review.toggle(item) : review.add(item)
                    }
                }
            }
        }
    }

    /// What to offer under the search box: matches for what's typed, plus the
    /// typed text itself if it isn't in the list, or the quick-add grid when
    /// nothing is typed.
    private var addOptions: [ResolvedItem] {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return IngredientCatalog.quickAdd.map(ResolvedItem.init) }

        var options = IngredientCatalog.search(typed).prefix(12).map(ResolvedItem.init)
        if let custom = IngredientCatalog.resolve(typed), custom.isCustom {
            options.append(custom)
        }
        return options
    }

    private func addTypedText() {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return }
        if let item = IngredientCatalog.resolve(typed) {
            review.add(item)
            query = ""
        }
    }

    private var continueTitle: String {
        let count = review.selected.count
        switch count {
        case 0: return "Add something to continue"
        case 1: return "Find recipes with 1 item"
        default: return "Find recipes with \(count) items"
        }
    }
}

#if DEBUG
extension ScanReview {
    /// Sample scan results for previews and screenshots.
    static func sample(empty: Bool = false) -> ScanReview {
        func detected(_ name: String, _ tier: ScanTier) -> DetectedItem {
            DetectedItem(item: IngredientCatalog.resolve(name)!, tier: tier,
                         votes: tier == .looksRight ? 3 : 1, runs: 3, hasVisionSupport: false)
        }
        let items = empty ? [] : [
            detected("eggs", .looksRight), detected("onion", .looksRight),
            detected("apple", .looksRight), detected("cheese", .looksRight),
            detected("banana", .maybe), detected("carrot", .maybe), detected("milk", .maybe),
        ]
        return ScanReview(result: ScanResult(items: items, usedModel: true))
    }
}

#Preview("Found some") {
    ScanConfirmView(review: .sample()) {}
}

#Preview("Found nothing") {
    ScanConfirmView(review: .sample(empty: true)) {}
}
#endif
