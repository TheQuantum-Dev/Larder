//
//  ChatModel.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation
import Observation

nonisolated struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Role: Sendable { case person, nutmeg }

    let id = UUID()
    let role: Role
    let text: String
    var recipeIDs: [String] = []
}

/// Anything that can answer as Nutmeg. Both engines take the same frozen
/// picture of the kitchen, so swapping one for the other changes how
/// questions are understood, never what data is behind the answer.
nonisolated protocol NutmegBrain: Sendable {
    func reply(to message: String, in kitchen: KitchenSnapshot) async -> NutmegReply
}

/// The offline answer is synchronous, which satisfies the async requirement as is.
extension OfflineBrain: NutmegBrain {}

/// One conversation with Nutmeg. It lives as long as the tab does, so
/// switching away and back doesn't lose it; it isn't saved to disk.
@Observable
final class ChatModel {
    enum Engine: Sendable { case offline, model }

    private(set) var messages: [ChatMessage] = []
    private(set) var isThinking = false
    let engine: Engine
    @ObservationIgnored private let brain: any NutmegBrain

    init(engine: Engine = ChatModel.defaultEngine) {
        self.engine = engine
        brain = engine == .model ? ModelBrain() : OfflineBrain()
    }

    /// Apple Intelligence where the phone has it; the offline Nutmeg
    /// everywhere else. `-chatEngine offline|model` overrides (debug builds only).
    static var defaultEngine: Engine {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "chatEngine") {
        case "offline": return .offline
        case "model": return .model
        default: break
        }
        #endif
        return ModelBrain.isAvailable ? .model : .offline
    }

    /// Gets the on-device model loaded while the person is still reading the
    /// screen, so the first answer isn't the slow one.
    func prewarm() async {
        if let model = brain as? ModelBrain { await model.prewarm() }
    }

    func send(_ text: String, kitchen: KitchenSnapshot) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }
        messages.append(ChatMessage(role: .person, text: trimmed))
        isThinking = true
        let started = Date()
        let reply = await brain.reply(to: trimmed, in: kitchen)
        // The offline answer is instant; a short beat lets the reply read as
        // a reply instead of appearing before the question has settled.
        let minimum = 0.4 - Date().timeIntervalSince(started)
        if minimum > 0 { try? await Task.sleep(for: .seconds(minimum)) }
        isThinking = false
        messages.append(ChatMessage(role: .nutmeg, text: reply.text, recipeIDs: reply.recipeIDs))
    }

    /// Starters at first; afterwards, the ones not asked yet, so the chips
    /// always offer something new.
    var suggestions: [String] {
        let all = Self.starters + (showsNutrition ? Self.nutritionStarters : [])
        let asked = Set(messages.filter { $0.role == .person }.map { $0.text.lowercased() })
        let fresh = all.filter { !asked.contains($0.lowercased()) }
        return fresh.isEmpty ? all : fresh
    }

    /// Set from the person's goal; "just cook" keeps the number questions out.
    var showsNutrition = false

    static let nutritionStarters = [
        "How's my protein today?",
        "Something high in protein",
    ]

    static let starters = [
        "What can I make tonight?",
        "Something quick",
        "Something cheap",
        "What's in my pantry?",
        "How much have I saved?",
        "How's my streak?",
    ]
}
