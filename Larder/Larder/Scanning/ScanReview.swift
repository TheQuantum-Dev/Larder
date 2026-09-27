//
//  ScanReview.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation
import Observation

/// A pantry item as it was when the review opened.
nonisolated struct PantrySnapshot: Hashable, Sendable {
    let item: ResolvedItem
    let quantity: Double?
    let unit: PantryUnit?

    init(item: ResolvedItem, quantity: Double? = nil, unit: PantryUnit? = nil) {
        self.item = item
        self.quantity = quantity
        self.unit = unit
    }

    var id: String { item.id }

    /// Whether + and − make sense: things you count, not things you weigh.
    var isCountable: Bool {
        guard let unit else { return true }
        return [.items, .packs, .cans, .bags, .bottles].contains(unit)
    }
}

extension PantrySnapshot {
    init(_ saved: PantryItem) {
        self.init(item: saved.resolved, quantity: saved.quantity, unit: saved.unit.flatMap(PantryUnit.init(rawValue:)))
    }
}

/// What confirming an update does to the pantry.
nonisolated struct PantryUpdate: Equatable, Sendable {
    var add: [ResolvedItem] = []
    /// New amounts for things already there, by ingredient id.
    var amounts: [String: Double] = [:]
    var remove: Set<String> = []

    var isEmpty: Bool { add.isEmpty && amounts.isEmpty && remove.isEmpty }
}

/// The confirm step after a scan: which detected items the person is keeping,
/// and anything they added by hand. "Looks right" items start checked, "Maybe"
/// items start unchecked, and nothing is final until they continue.
///
/// When it's updating a pantry that already has things in it, items already
/// there get their amount checked instead of being added again, and anything
/// the photos didn't show can be marked as all gone. A count the model made
/// from the photo is only ever a suggestion shown here, never saved on its own.
@Observable
final class ScanReview {
    let suggestions: [DetectedItem]
    let usedModel: Bool
    /// True when the person skipped the photo and is listing things by hand.
    let isManual: Bool
    /// What was in the pantry before, in the order it was added.
    let pantry: [PantrySnapshot]
    private(set) var added: [ResolvedItem] = []
    private(set) var checked: Set<String>
    /// Amounts changed here (or counted from the photo) for things already in the pantry.
    private(set) var amounts: [String: Double] = [:]
    /// Which of those amounts came from the photo and haven't been touched.
    private(set) var guessed: Set<String> = []
    /// Pantry items marked as all gone.
    private(set) var gone: Set<String> = []

    private let saved: [String: PantrySnapshot]

    init(result: ScanResult, isManual: Bool = false, pantry: [PantrySnapshot] = []) {
        suggestions = result.items
        usedModel = result.usedModel
        self.isManual = isManual
        self.pantry = pantry
        saved = Dictionary(pantry.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        checked = Set(result.items.filter { $0.tier == .looksRight }.map(\.id))
        for detected in result.items {
            guard let count = detected.count, let have = saved[detected.id], have.isCountable else { continue }
            amounts[detected.id] = Double(count)
            guessed.insert(detected.id)
        }
    }

    /// An empty review for people who'd rather type than take a photo.
    static func manual(pantry: [PantrySnapshot] = []) -> ScanReview {
        ScanReview(result: ScanResult(items: [], usedModel: false), isManual: true, pantry: pantry)
    }

    /// True when there's an existing pantry to update, rather than a first one to fill.
    var isUpdate: Bool { !pantry.isEmpty }

    private func isNew(_ item: ResolvedItem) -> Bool { saved[item.id] == nil }

    /// Whether it was already in the pantry before this review.
    func isSaved(_ item: ResolvedItem) -> Bool { saved[item.id] != nil }

    var looksRight: [ResolvedItem] { suggestions.filter { $0.tier == .looksRight }.map(\.item).filter(isNew) }
    var maybe: [ResolvedItem] { suggestions.filter { $0.tier == .maybe }.map(\.item).filter(isNew) }
    /// Things added by hand that weren't already in the pantry.
    var addedNew: [ResolvedItem] { added.filter(isNew) }

    /// Pantry items the photos showed (or that were added again by hand).
    var alreadyHave: [PantrySnapshot] {
        let seen = Set(suggestions.map(\.id)).union(added.map(\.id))
        return pantry.filter { seen.contains($0.id) }
    }

    /// Pantry items the photos didn't show. They stay unless marked all gone.
    var notSpotted: [PantrySnapshot] {
        let seen = Set(alreadyHave.map(\.id))
        return pantry.filter { !seen.contains($0.id) }
    }

    var foundNothing: Bool { suggestions.isEmpty }

    func isChecked(_ item: ResolvedItem) -> Bool { checked.contains(item.id) }

    func toggle(_ item: ResolvedItem) {
        if checked.contains(item.id) {
            checked.remove(item.id)
        } else {
            checked.insert(item.id)
        }
    }

    /// Adds something the scan missed. An item the scan already suggested is
    /// just checked instead of being listed twice.
    func add(_ item: ResolvedItem) {
        let alreadyListed = suggestions.contains { $0.item == item } || added.contains(item)
        if !alreadyListed { added.append(item) }
        checked.insert(item.id)
        gone.remove(item.id)
    }

    // MARK: - Amounts

    /// How much of a pantry item there'll be: the new amount if there is one,
    /// otherwise what was saved. Nil means "some", with no number.
    func amount(for id: String) -> Double? {
        amounts[id] ?? saved[id]?.quantity
    }

    func isGuess(_ id: String) -> Bool { guessed.contains(id) }

    /// One tap of + or −. From "some" (no number), + means one and − means none left.
    func step(_ id: String, by direction: Int) {
        guard let have = saved[id], have.isCountable else { return }
        let unit = have.unit ?? .items
        if let current = amount(for: id) {
            amounts[id] = PantryAmount.stepped(current, by: direction, unit: unit)
        } else {
            amounts[id] = direction > 0 ? 1 : 0
        }
        guessed.remove(id)
    }

    func isGone(_ id: String) -> Bool { gone.contains(id) }

    func toggleGone(_ id: String) {
        if gone.contains(id) { gone.remove(id) } else { gone.insert(id) }
    }

    // MARK: - Results

    /// Everything the person is keeping: suggestions first, then their own.
    var selected: [ResolvedItem] {
        let fromScan = suggestions.map(\.item).filter { checked.contains($0.id) }
        let byHand = added.filter { checked.contains($0.id) }
        return fromScan + byHand
    }

    /// What confirming does to an existing pantry. An amount taken down to
    /// zero means it's all gone.
    var update: PantryUpdate {
        var result = PantryUpdate(add: selected.filter(isNew), remove: gone)
        for (id, value) in amounts where !gone.contains(id) && value != saved[id]?.quantity {
            if value <= 0 { result.remove.insert(id) } else { result.amounts[id] = value }
        }
        return result
    }
}
