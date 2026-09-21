//
//  ScanReview.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation
import Observation

/// The confirm step after a scan: which detected items the person is keeping,
/// and anything they added by hand. "Looks right" items start checked, "Maybe"
/// items start unchecked, and nothing is final until they continue.
@Observable
final class ScanReview {
    let suggestions: [DetectedItem]
    let usedModel: Bool
    private(set) var added: [ResolvedItem] = []
    private(set) var checked: Set<String>

    init(result: ScanResult) {
        suggestions = result.items
        usedModel = result.usedModel
        checked = Set(result.items.filter { $0.tier == .looksRight }.map(\.id))
    }

    var looksRight: [ResolvedItem] { suggestions.filter { $0.tier == .looksRight }.map(\.item) }
    var maybe: [ResolvedItem] { suggestions.filter { $0.tier == .maybe }.map(\.item) }

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
    }

    /// Everything the person is keeping: suggestions first, then their own.
    var selected: [ResolvedItem] {
        let fromScan = suggestions.map(\.item).filter { checked.contains($0.id) }
        let byHand = added.filter { checked.contains($0.id) }
        return fromScan + byHand
    }
}
