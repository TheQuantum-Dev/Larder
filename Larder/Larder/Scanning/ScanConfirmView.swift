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
///
/// When updating a pantry, things already in it get their amount checked
/// (a count from the photo is marked as a guess), and anything the photos
/// didn't show sits folded away under "Still have these?", kept unless the
/// person says it's all gone.
struct ScanConfirmView: View {
    let review: ScanReview
    var mode = ScanMode.onboarding
    /// Opens the barcode scanner; its finds join this review.
    var onScanBarcode: (() -> Void)?
    let onContinue: () -> Void

    @State private var query: String
    @State private var showsNotSpotted = false
    @FocusState private var searchFocused: Bool

    init(review: ScanReview, mode: ScanMode = .onboarding, initialQuery: String = "",
         onScanBarcode: (() -> Void)? = nil, onContinue: @escaping () -> Void) {
        self.review = review
        self.mode = mode
        self.onScanBarcode = onScanBarcode
        self.onContinue = onContinue
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header

                if !review.looksRight.isEmpty {
                    section(review.isUpdate ? "New" : "Looks right", note: "Tap + and − to say how many, if you like.") {
                        VStack(spacing: Theme.Spacing.xs) {
                            ForEach(review.looksRight) { item in
                                NewItemRow(item: item, review: review)
                            }
                        }
                    }
                }

                if !review.alreadyHave.isEmpty {
                    section("Already have: check the amounts") {
                        VStack(spacing: Theme.Spacing.xs) {
                            ForEach(review.alreadyHave, id: \.id) { have in
                                AmountRow(have: have, review: review)
                            }
                        }
                    }
                }

                if !review.maybe.isEmpty {
                    section("Not sure about these", note: "Tap the ones you actually have.") {
                        chips(review.maybe, isMaybe: true)
                    }
                }

                if !review.addedNew.isEmpty {
                    section("You added") {
                        chips(review.addedNew, isMaybe: false)
                    }
                }

                addSection

                if !review.notSpotted.isEmpty {
                    notSpottedSection
                }
            }
            .padding(Theme.Spacing.s)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(continueTitle, action: onContinue)
                .buttonStyle(PillButtonStyle())
                .disabled(canContinue == false)
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.top, Theme.Spacing.xs)
                .background(Theme.Palette.background)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        // A light tick whenever something is checked or unchecked.
        .tapFeedback(review.checked)
        .tapFeedback(review.gone)
    }

    private var canContinue: Bool {
        mode == .update && review.isUpdate ? !review.update.isEmpty : !review.selected.isEmpty
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
        if review.isUpdate {
            return review.isManual
                ? "Add what's new, check the amounts, or mark what's all gone."
                : "Check the amounts, tick anything new, and I'll update your pantry."
        }
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
            if let onScanBarcode {
                Button(action: onScanBarcode) {
                    Label("Scan a barcode", systemImage: "barcode.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(minHeight: 44)
                }
            }
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
        // Things already in the pantry have their own rows above, so the
        // quick picks leave them out.
        guard !typed.isEmpty else {
            return IngredientCatalog.quickAdd.map(ResolvedItem.init).filter { !review.isSaved($0) }
        }

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

    // MARK: - Not spotted

    /// Pantry items the photos didn't show, folded away. Photos of one shelf
    /// shouldn't nag about the rest, so everything stays unless marked gone.
    private var notSpottedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showsNotSpotted.toggle() }
            } label: {
                HStack {
                    Text(review.isManual ? "Anything all gone?" : "Still have these?")
                        .font(.headline)
                    Spacer()
                    Text("\(review.notSpotted.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    Image(systemName: "chevron.down")
                        .font(.subheadline.bold())
                        .rotationEffect(.degrees(showsNotSpotted ? 180 : 0))
                }
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(showsNotSpotted ? .isSelected : [])

            if showsNotSpotted {
                Text(review.isManual ? "Tap anything that's run out." : "I didn't see these in the photos. They stay unless you say they're gone.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                ForEach(review.notSpotted, id: \.id) { have in
                    GoneRow(have: have, isGone: review.isGone(have.id)) { review.toggleGone(have.id) }
                }
            }
        }
    }

    private var continueTitle: String {
        if mode == .update && review.isUpdate {
            let update = review.update
            return update.isEmpty ? "Nothing to update yet" : "Update pantry"
        }
        let count = review.selected.count
        if count == 0 { return "Add something to continue" }
        if mode == .update { return "Update pantry" }
        switch count {
        case 1: return "Find recipes with 1 item"
        default: return "Find recipes with \(count) items"
        }
    }
}

/// Something found by the scan that's new to the pantry: a tick to keep it,
/// and, once kept, how many. A count the model made is marked as a guess.
private struct NewItemRow: View {
    let item: ResolvedItem
    let review: ScanReview

    var body: some View {
        let isKept = review.isChecked(item)
        CountRow(emoji: item.emoji, name: item.name, note: nil,
                 amount: isKept ? review.amount(for: item.id) : nil, unit: .items, showsStepper: isKept,
                 isGuess: review.isGuess(item.id), isNew: true,
                 checkbox: (isKept, { review.toggle(item) })) { review.step(item.id, by: $0) }
    }
}

/// A pantry item the photos showed: its amount, with + and − for things you
/// count. A count from the photo is marked, so it reads as a suggestion.
private struct AmountRow: View {
    let have: PantrySnapshot
    let review: ScanReview

    var body: some View {
        let amount = review.amount(for: have.id)
        let was = PantryAmount.text(quantity: have.quantity, unit: have.unit?.rawValue)
        CountRow(emoji: have.item.emoji, name: have.item.name,
                 note: was.flatMap { amount != have.quantity ? "Was \($0)" : nil },
                 amount: amount, unit: have.unit ?? .items, showsStepper: have.isCountable,
                 isGuess: review.isGuess(have.id), isNew: false) { review.step(have.id, by: $0) }
    }
}

/// One line with an amount: an optional tick, the name, and + and − around
/// the number (or just the amount, for things that are weighed).
private struct CountRow: View {
    let emoji: String
    let name: String
    let note: String?
    let amount: Double?
    let unit: PantryUnit
    let showsStepper: Bool
    let isGuess: Bool
    /// New things can't be "all gone", so their lowest is "some".
    let isNew: Bool
    var checkbox: (isOn: Bool, toggle: () -> Void)?
    let onStep: (Int) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    /// At the biggest text sizes the amount goes on its own line under the name.
    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.xs))
    }

    var body: some View {
        layout {
            HStack(spacing: Theme.Spacing.xs) {
            if let checkbox {
                Button(action: checkbox.toggle) {
                    Image(systemName: checkbox.isOn ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(checkbox.isOn ? Theme.Palette.amber : Theme.Palette.textPrimary.opacity(0.35))
                        .symbolEffect(.bounce, value: checkbox.isOn)
                        .frame(width: 30, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(checkbox.isOn ? "Keep \(name)" : "Leave out \(name)")
            }
            Text(emoji)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(checkbox?.isOn == false ? 0.6 : 1))
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
            }
            }
            Spacer(minLength: 0)
            HStack(spacing: Theme.Spacing.xs) {
            if showsStepper {
                stepButton("minus", label: "Less \(name)") { onStep(-1) }
                    .disabled(isNew ? amount == nil : amount == 0)
                VStack(spacing: 0) {
                    Text(amountText)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .contentTransition(.numericText())
                    if isGuess {
                        Text("from photo")
                            .font(.caption2)
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    }
                }
                .frame(minWidth: 60)
                stepButton("plus", label: "More \(name)") { onStep(1) }
            } else if checkbox == nil {
                Text(amountText)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            }
        }
        .padding(.vertical, typeSize.isAccessibilitySize ? Theme.Spacing.xs : 0)
        .padding(.leading, checkbox == nil ? Theme.Spacing.s : Theme.Spacing.xs)
        .padding(.trailing, Theme.Spacing.s)
        .frame(minHeight: 60)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: amount)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showsStepper)
        .tapFeedback(amount)
        .accessibilityElement(children: .contain)
    }

    private var amountText: String {
        guard let amount else { return "Some" }
        if amount == 0 { return "All gone" }
        return PantryAmount.text(quantity: amount, unit: unit.rawValue) ?? "Some"
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: 40, height: 40)
                .background(Theme.Palette.softAmber, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A pantry item the photos didn't show, with a way to say it's all gone.
private struct GoneRow: View {
    let have: PantrySnapshot
    let isGone: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(have.item.emoji)
            Text(have.item.name)
                .font(.subheadline.weight(.semibold))
                .strikethrough(isGone)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(isGone ? 0.6 : 1))
            Spacer(minLength: 0)
            Button(action: action) {
                Text(isGone ? "Keep it" : "All gone")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isGone ? Theme.Palette.textPrimary : Theme.Palette.onAccent)
                    .padding(.horizontal, Theme.Spacing.s)
                    .frame(minHeight: 40)
                    .background(isGone ? Theme.Palette.surface : Theme.Palette.softAmber, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.s)
        .frame(minHeight: 60)
        .background(Theme.Palette.surface.opacity(isGone ? 0.5 : 1), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
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

    /// An update of a sample pantry: eggs counted from the photo, cheese seen
    /// again, and rice and bread not in the photos.
    static func sampleUpdate() -> ScanReview {
        func item(_ name: String) -> ResolvedItem { IngredientCatalog.resolve(name)! }
        let pantry = [
            PantrySnapshot(item: item("eggs"), quantity: 6, unit: .items),
            PantrySnapshot(item: item("cheese")),
            PantrySnapshot(item: item("rice"), quantity: 500, unit: .grams),
            PantrySnapshot(item: item("bread"), quantity: 1, unit: .bags),
            PantrySnapshot(item: item("milk"), quantity: 1, unit: .bottles),
        ]
        let items = [
            DetectedItem(item: item("eggs"), tier: .looksRight, votes: 3, runs: 3, hasVisionSupport: true, count: 2),
            DetectedItem(item: item("cheese"), tier: .looksRight, votes: 3, runs: 3, hasVisionSupport: false),
            DetectedItem(item: item("milk"), tier: .maybe, votes: 1, runs: 3, hasVisionSupport: false),
            DetectedItem(item: item("onion"), tier: .looksRight, votes: 3, runs: 3, hasVisionSupport: false, count: 3),
            DetectedItem(item: item("apple"), tier: .looksRight, votes: 2, runs: 3, hasVisionSupport: false),
            DetectedItem(item: item("carrot"), tier: .maybe, votes: 1, runs: 3, hasVisionSupport: false),
        ]
        return ScanReview(result: ScanResult(items: items, usedModel: true), pantry: pantry)
    }
}

#Preview("Found some") {
    ScanConfirmView(review: .sample()) {}
}

#Preview("Found nothing") {
    ScanConfirmView(review: .sample(empty: true)) {}
}
#endif
