//
//  PantryProposal.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation

/// A pantry change Nutmeg suggested in the chat, waiting for a tap. It starts
/// from what was said ("add 6 eggs"), the amounts can be nudged with + and −,
/// and nothing touches the pantry until the person confirms.
nonisolated struct PantryProposal: Equatable, Sendable {
    enum State: Equatable, Sendable { case pending, applied, dismissed }

    struct Line: Identifiable, Equatable, Sendable {
        var id: String { item.id }
        let item: ResolvedItem
        let action: PantryCommand.Action
        /// How many to add, or how many there are now. Nil means "some".
        var quantity: Double?
        let unit: PantryUnit
        /// What the pantry had before, if it had any.
        let had: Double?
        let hadUnit: PantryUnit?
        let isInPantry: Bool

        /// + and − make sense for adding and setting, not for "all gone".
        var hasStepper: Bool { action != .remove }

        /// What the row says: "+6", "+2 cans", "Now 2", "All gone".
        var label: String {
            switch action {
            case .remove:
                return "All gone"
            case .add:
                guard let quantity else { return "Some" }
                return "+" + (PantryAmount.text(quantity: quantity, unit: unit.rawValue) ?? "")
            case .set:
                guard let quantity, quantity > 0 else { return "All gone" }
                return "Now " + (PantryAmount.text(quantity: quantity, unit: unit.rawValue) ?? "")
            }
        }

        /// The new total when adding to an amount that was already counted
        /// the same way: 3 eggs plus 6 is 9.
        var total: Double? {
            guard let quantity else { return nil }
            guard action == .add, let had, (hadUnit ?? .items) == unit else { return quantity }
            return had + quantity
        }
    }

    var lines: [Line]
    var state = State.pending

    init(_ command: PantryCommand, pantry: [KitchenSnapshot.Item]) {
        lines = command.lines.map { line in
            let saved = pantry.first { $0.id == line.item.id }
            let savedUnit = saved?.unit.flatMap(PantryUnit.init(rawValue:))
            return Line(item: line.item, action: line.action, quantity: line.quantity,
                        unit: line.unit ?? savedUnit ?? .items, had: saved?.quantity, hadUnit: savedUnit,
                        isInPantry: saved != nil)
        }
    }

    var isAllAdds: Bool { lines.allSatisfy { $0.action == .add } }

    /// One tap of + or −. Adding goes from "some" to 1 and back; setting stops at none.
    mutating func step(_ id: String, by direction: Int) {
        guard state == .pending, let index = lines.firstIndex(where: { $0.id == id }), lines[index].hasStepper else { return }
        let line = lines[index]
        switch line.action {
        case .add:
            guard let current = line.quantity else {
                if direction > 0 { lines[index].quantity = line.unit.starting }
                return
            }
            let next = PantryAmount.stepped(current, by: direction, unit: line.unit)
            lines[index].quantity = next > 0 ? next : nil
        case .set:
            lines[index].quantity = PantryAmount.stepped(line.quantity ?? 0, by: direction, unit: line.unit)
        case .remove:
            break
        }
    }

    /// What confirming does to the pantry.
    var update: PantryUpdate {
        var update = PantryUpdate()
        for line in lines {
            let id = line.item.id
            switch line.action {
            case .remove:
                update.remove.insert(id)
            case .add, .set:
                if line.action == .set, line.quantity == 0 {
                    if line.isInPantry { update.remove.insert(id) }
                    continue
                }
                if !line.isInPantry {
                    update.add.append(line.item)
                    if let quantity = line.quantity { update.addAmounts[id] = quantity }
                } else if let total = line.total {
                    update.amounts[id] = total
                }
                if line.quantity != nil { update.units[id] = line.unit }
            }
        }
        return update
    }

    /// What Nutmeg says once it's done.
    var confirmation: String {
        func named(_ line: Line) -> String {
            let name = line.item.name.lowercased()
            guard let quantity = line.action == .add ? line.quantity : line.total,
                  let amount = PantryAmount.text(quantity: quantity, unit: line.unit.rawValue) else { return name }
            return "\(name) (\(amount))"
        }
        var parts: [String] = []
        let added = lines.filter { $0.action == .add }.map(named)
        let set = lines.filter { $0.action == .set && $0.quantity != 0 }.map(named)
        let gone = lines.filter { $0.action == .remove || ($0.action == .set && $0.quantity == 0) }
            .map { $0.item.name.lowercased() }
        if !added.isEmpty { parts.append("added \(OfflineBrain.list(added))") }
        if !set.isEmpty { parts.append("updated \(OfflineBrain.list(set))") }
        if !gone.isEmpty { parts.append("took \(OfflineBrain.list(gone)) off") }
        return "Done! I've " + OfflineBrain.list(parts) + "."
    }
}
