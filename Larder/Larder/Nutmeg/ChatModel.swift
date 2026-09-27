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
    /// Answers to tap, like "Something quick" after "what are you in the mood for?".
    var quickReplies: [String] = []
    /// A pantry change to confirm.
    var pantryChange: PantryProposal?
    /// Said out loud rather than typed.
    var isVoice = false
    /// Online recipes named here, kept as just their name, emoji and photo
    /// (all the recipe service lets us keep), so a card still shows after the
    /// recipe itself has been let go.
    var onlineRefs: [RecipeRef] = []
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
    /// Answers follow-ups ("yes", "show me more", "the first one") from rules.
    @ObservationIgnored private let offline = OfflineBrain()
    /// Saves things Nutmeg puts on the shopping list; set by the chat screen.
    @ObservationIgnored var onAddToList: ([ShoppingEntry]) -> Void = { _ in }

    // What the conversation is about, so short replies make sense.
    @ObservationIgnored private var pendingOffer: FollowUp?
    @ObservationIgnored private var lastRecipeIDs: [String] = []
    @ObservationIgnored private var pool: [String] = []
    @ObservationIgnored private var shown = 0

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

    func send(_ text: String, kitchen: KitchenSnapshot, isVoice: Bool = false) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }
        messages.append(ChatMessage(role: .person, text: trimmed, isVoice: isVoice))
        isThinking = true
        let started = Date()
        let reply: NutmegReply
        if let followUp = followUp(to: trimmed, in: kitchen) {
            reply = followUp
        } else {
            reply = await brain.reply(to: trimmed, in: kitchen)
        }
        remember(reply)
        if !reply.listAdditions.isEmpty { onAddToList(reply.listAdditions) }
        // The offline answer is instant; a short beat lets the reply read as
        // a reply instead of appearing before the question has settled.
        let minimum = 0.4 - Date().timeIntervalSince(started)
        if minimum > 0 { try? await Task.sleep(for: .seconds(minimum)) }
        isThinking = false
        let online = reply.recipeIDs.compactMap { id in kitchen.match(for: id)?.recipe }.filter(\.isOnline)
        messages.append(ChatMessage(role: .nutmeg, text: reply.text, recipeIDs: reply.recipeIDs,
                                    quickReplies: reply.quickReplies,
                                    pantryChange: reply.pantryChange.map { PantryProposal($0, pantry: kitchen.pantry) },
                                    onlineRefs: online.map(RecipeRef.init)))
    }

    // MARK: - Follow-ups

    /// Short replies that only make sense after what Nutmeg just said: a yes
    /// or no to his offer, "show me more", or "the first one". Nil for
    /// anything else, which goes to the brain as usual.
    func followUp(to message: String, in kitchen: KitchenSnapshot) -> NutmegReply? {
        let text = " " + IngredientCatalog.key(for: message) + " "
        let wordCount = text.split(separator: " ").count
        func has(_ phrases: [String]) -> Bool {
            phrases.contains { text.contains(" " + IngredientCatalog.key(for: $0) + " ") }
        }
        let isYes = wordCount <= 7 && (has(["yes", "yeah", "yep", "yup", "sure", "ok", "okay", "go on", "do it",
                                            "sounds good", "why not", "please do", "go for it"])
                                       || (pendingOfferIsList && has(["add"]) && !has(["no"])))
        let isNo = wordCount <= 5 && has(["no", "nah", "nope", "not now", "never mind", "nevermind", "no thanks"])

        if isNo {
            let hadOffer = pendingOffer != nil
            pendingOffer = nil
            return NutmegReply(hadOffer ? "No problem! I'm here if you change your mind." : "Okay! Anything else I can help with?")
        }
        if isYes {
            if let offer = pendingOffer { return offline.accept(offer, in: kitchen) }
            return NutmegReply("Great! What are you in the mood for?", quickReplies: OfflineBrain.moods(for: kitchen))
        }
        if wordCount <= 6, has(["more", "show me more", "anything else", "other ideas", "what else", "others",
                                "something else", "other ones"]), shown < pool.count {
            let next = Array(pool.dropFirst(shown).prefix(NutmegReply.maxRecipes))
            let left = pool.count - shown - next.count
            return NutmegReply("Here are a few more:", recipeIDs: next,
                               quickReplies: left > 0 ? ["Show me more"] : [], pool: pool)
        }
        if let id = referencedRecipe(in: text, wordCount: wordCount) {
            return offline.answer(.aboutRecipe(id), in: kitchen)
        }
        return nil
    }

    private var pendingOfferIsList: Bool {
        if case .addToList = pendingOffer { return true }
        return false
    }

    /// "The first one", "the second", "that one", "what do I need for it".
    private func referencedRecipe(in text: String, wordCount: Int) -> String? {
        guard !lastRecipeIDs.isEmpty, wordCount <= 10 else { return nil }
        let ordinals: [(String, Int)] = [("first", 0), ("1st", 0), ("second", 1), ("2nd", 1), ("third", 2), ("3rd", 2)]
        for (word, index) in ordinals where text.contains(" \(word) ") {
            return lastRecipeIDs.indices.contains(index) ? lastRecipeIDs[index] : nil
        }
        if text.contains(" last one ") { return lastRecipeIDs.last }
        let pointsBack = [" that one ", " this one ", " that ", " it "].contains { text.contains($0) }
        let asksAbout = [" need ", " make ", " cook ", " how ", " what ", " tell ", " long ", " cost "].contains { text.contains($0) }
        return pointsBack && asksAbout ? lastRecipeIDs.first : nil
    }

    /// Keeps what a reply offered and showed, for the next short reply.
    private func remember(_ reply: NutmegReply) {
        pendingOffer = reply.offer
        if !reply.recipeIDs.isEmpty {
            lastRecipeIDs = reply.recipeIDs
            if reply.pool.isEmpty {
                pool = reply.recipeIDs
                shown = reply.recipeIDs.count
            } else if reply.pool == pool {
                shown += reply.recipeIDs.count
            } else {
                pool = reply.pool
                shown = reply.recipeIDs.count
            }
        }
    }

    // MARK: - Pantry changes

    func stepChange(in messageID: UUID, line id: String, by direction: Int) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].pantryChange?.step(id, by: direction)
    }

    /// Hands the change to `apply` (which saves it), marks the card done, and
    /// has Nutmeg say what changed.
    func confirmChange(in messageID: UUID, apply: (PantryUpdate) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }),
              let proposal = messages[index].pantryChange, proposal.state == .pending else { return }
        apply(proposal.update)
        messages[index].pantryChange?.state = .applied
        messages.append(ChatMessage(role: .nutmeg, text: proposal.confirmation))
    }

    func dismissChange(in messageID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }),
              messages[index].pantryChange?.state == .pending else { return }
        messages[index].pantryChange?.state = .dismissed
        messages.append(ChatMessage(role: .nutmeg, text: "No problem, I've left your pantry as it was."))
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
