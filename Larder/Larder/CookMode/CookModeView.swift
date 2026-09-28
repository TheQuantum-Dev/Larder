//
//  CookModeView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftData
import SwiftUI
import UIKit

/// Cook Mode: get set up, then one big step at a time with timers, then done.
/// The screen stays awake while it's open, because a phone that goes dark
/// halfway through a recipe is no help to someone with wet hands.
struct CookModeView: View {
    let diets: Set<Diet>
    let onFinish: () -> Void
    let onClose: () -> Void

    @State private var session: CookSession
    @State private var confirmingExit = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Query private var pantry: [PantryItem]
    @AppStorage(AppSettings.orderOutPriceKey) private var orderOutPrice = AppSettings.defaultOrderOutPrice
    @AppStorage(AppSettings.healthSyncKey) private var healthSync = false
    @AppStorage(AppSettings.autoAddToShoppingKey) private var autoAddToShopping = true
    /// What the person says ran out, kept here so closing with the X counts it too.
    @State private var usedUp: Set<String> = []
    @State private var made: MadeResult?
    @State private var askingForNotifications = false
    @AppStorage(AppSettings.askedTimerNotificationsKey) private var askedTimerNotifications = false

    init(recipe: Recipe, diets: Set<Diet>, startAt phase: CookSession.Phase = .gather,
         onFinish: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.diets = diets
        self.onFinish = onFinish
        self.onClose = onClose
        _session = State(initialValue: CookSession(recipe: recipe, phase: phase))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if !session.ringing.isEmpty {
                RingingBar(session: session)
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.top, Theme.Spacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            ZStack {
                content
                    .id(session.phase)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: session.phase)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: session.ringing)
        // A timer going off rings, with a buzz, until someone taps Stop.
        .onChange(of: session.ringing.isEmpty) { _, isQuiet in
            if isQuiet { TimerAlarm.shared.stop() } else { TimerAlarm.shared.start() }
        }
        .onChange(of: session.timersStarted) { _, _ in offerNotifications() }
        .sheet(isPresented: $askingForNotifications) {
            TimerNotificationAsk { allowed in
                askingForNotifications = false
                session.notificationsOff = !allowed
                if allowed { session.rescheduleNotifications() }
            }
            .presentationDetents([.medium])
        }
        .alert("Stop cooking?", isPresented: $confirmingExit) {
            Button("Keep cooking", role: .cancel) {}
            Button("Stop", role: .destructive) { onClose() }
        } message: {
            Text("Your timers will stop.")
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            session.notifier = TimerNotifications.shared
            Task { session.notificationsOff = await TimerNotifications.status() == .denied }
            startDebugTimer()
            startDebugMade()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            session.stop()
            TimerAlarm.shared.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // A timer can run out while the app is asleep, so check on return.
            // It has already rung through its notification, so it doesn't
            // start ringing again here.
            if newPhase == .active {
                session.refresh(canRing: false)
                session.appIsActive = true
            } else {
                session.appIsActive = false
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button(action: requestClose) {
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Theme.Palette.surface, in: Circle())
            }
            .accessibilityLabel("Close Cook Mode")

            ProgressBar(progress: session.progress)

            Text(stepLabel)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .frame(minWidth: 50, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.top, Theme.Spacing.xs)
    }

    private var stepLabel: String {
        switch session.phase {
        case .gather: "Ready"
        case .step(let index): "\(index + 1)/\(session.stepCount)"
        case .done: "Done"
        case .made: "Made it!"
        }
    }

    private func requestClose() {
        switch session.phase {
        case .step: confirmingExit = true
        case .made: finishMade(usedUp)   // the meal is already saved
        default: onClose()
        }
    }

    /// The first time someone starts a timer, and only if they've never
    /// been asked, Nutmeg offers a notification for when it's done.
    private func offerNotifications() {
        guard !askedTimerNotifications else { return }
        Task {
            guard await TimerNotifications.status() == .notDetermined else { return }
            askedTimerNotifications = true
            askingForNotifications = true
        }
    }

    // MARK: - Phases

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .gather:
            GatherView(session: session, diets: diets) { session.begin() }
        case .step(let index):
            StepView(session: session, index: index)
        case .done:
            DoneView(recipe: session.recipe, onMade: { recordMade(servingsEaten: $0) }, onBack: { session.back() })
        case .made:
            MadeItView(result: made ?? MadeResult(summary: MealSummary(recipe: session.recipe, orderOutPrice: orderOutPrice),
                                                  isFirstMeal: false,
                                                  stats: MealStats(mealCount: 0, mealsThisWeek: 0, totalSaved: 0)),
                       candidates: runOutCandidates,
                       usedUp: $usedUp,
                       onDone: finishMade)
        }
    }

    // MARK: - Marking it as made

    /// Saves the meal, works out the savings, and moves to the celebration.
    private func recordMade(servingsEaten: Int) {
        let summary = MealSummary(recipe: session.recipe, orderOutPrice: orderOutPrice, servingsEaten: servingsEaten)
        let previousDates = MealLog.meals(in: context).map(\.cookedAt)
        let isFirst = previousDates.isEmpty
        let meal = MealLog.record(summary, in: context)
        if healthSync {
            let entry = HealthMeal(recipeID: summary.recipeID, title: summary.title, date: meal.cookedAt,
                                   macros: summary.nutritionEaten)
            Task { await Health.shared.logMeal(entry) }
        }
        made = MadeResult(summary: summary, isFirstMeal: isFirst,
                          stats: MealStats.compute(from: MealLog.meals(in: context)),
                          streak: StreakProgress.after(cookingAt: meal.cookedAt, previousDates: previousDates))
        session.finish()
    }

    /// Pantry ingredients the recipe used, for the "anything run out?" chips.
    private var runOutCandidates: [ResolvedItem] {
        #if DEBUG
        if let ids = UserDefaults.standard.string(forKey: "madeCandidates") {
            return ids.split(separator: ",")
                .compactMap { IngredientCatalog.ingredient(withID: String($0)) }
                .map(ResolvedItem.init)
        }
        #endif
        let inPantry = Set(pantry.map(\.ingredientID))
        return PantryUse.usedIngredientIDs(by: session.recipe, pantry: inPantry)
            .compactMap { id in pantry.first { $0.ingredientID == id }?.resolved }
    }

    /// Takes the finished ingredients off the pantry, then leaves Cook Mode.
    private func finishMade(_ usedUp: Set<String>) {
        let ranOut = runOutCandidates.filter { usedUp.contains($0.id) }
        PantryRepository.remove(ids: usedUp, in: context)
        ShoppingRepository.addRunOut(ranOut, enabled: autoAddToShopping, in: context)
        onFinish()
    }

    /// `-cookPhase made` shows the celebration with sample numbers, without saving anything
    /// (debug builds only). Add `-madeFirst YES` for the first-meal version,
    /// `-madeCandidates egg,rice` for the "anything run out?" chips, and
    /// `-madeStreak 2` for the streak card after two days in a row already.
    private func startDebugMade() {
        #if DEBUG
        if session.phase == .made, made == nil {
            let earlier = UserDefaults.standard.integer(forKey: "madeStreak")
            let previous = (0..<earlier).compactMap { Calendar.current.date(byAdding: .day, value: -($0 + 1), to: Date()) }
            made = MadeResult(summary: MealSummary(recipe: session.recipe, orderOutPrice: orderOutPrice),
                              isFirstMeal: UserDefaults.standard.bool(forKey: "madeFirst"),
                              stats: MealStats(mealCount: 3, mealsThisWeek: 2, totalSaved: 31.40),
                              streak: StreakProgress.after(cookingAt: Date(), previousDates: previous))
        }
        #endif
    }

    /// `-cookTimer YES` starts the timer on the current step, `-cookTimerStep 2`
    /// starts the one on step 2, and `-cookRinging YES` shows the current
    /// step's timer ringing, and `-askTimerNotifications YES` shows Nutmeg's offer
    /// to ping you (debug builds only).
    private func startDebugTimer() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "cookTimer"), let step = session.currentStep {
            session.startTimer(step)
        }
        if UserDefaults.standard.bool(forKey: "cookRinging"), let step = session.currentStep {
            session.debugRing(step)
        }
        if UserDefaults.standard.bool(forKey: "askTimerNotifications") { askingForNotifications = true }
        if let number = Int(UserDefaults.standard.string(forKey: "cookTimerStep") ?? "") {
            session.startTimer(number - 1)
        }
        #endif
    }
}

// MARK: - Get set up

private struct GatherView: View {
    let session: CookSession
    let diets: Set<Diet>
    let onStart: () -> Void

    /// Nutmeg puts his chef's hat on and gives an approving nod as Cook Mode
    /// opens: you picked a good one.
    @State private var nod = 0
    @State private var hatLift: CGFloat = 90
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(spacing: Theme.Spacing.s) {
                    NutmegView(nod: nod, hat: .chef, hatLift: hatLift)
                        .frame(width: 80)
                        .task {
                            try? await Task.sleep(for: .milliseconds(300))
                            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6)) {
                                hatLift = 0
                            }
                            try? await Task.sleep(for: .milliseconds(450))
                            nod += 1
                        }
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Let's get set up")
                            .font(.title2.bold())
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Tick things off as you get them.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !session.recipe.equipment.isEmpty {
                    group("You'll need") {
                        ForEach(session.recipe.equipment, id: \.self) { equipment in
                            CheckRow(title: equipment.title, isOn: session.checkedEquipment.contains(equipment)) {
                                session.checkedEquipment.formSymmetricDifference([equipment])
                            }
                        }
                    }
                }

                group("Ingredients") {
                    let lines = session.recipe.visibleIngredients(for: diets)
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        CheckRow(title: line.amount + (line.isOptional ? " (optional)" : ""),
                                 isOn: session.checkedIngredients.contains(index)) {
                            session.checkedIngredients.formSymmetricDifference([index])
                        }
                    }
                }
            }
            .padding(Theme.Spacing.s)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Start cooking", action: onStart)
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.top, Theme.Spacing.xs)
                .background(Theme.Palette.background)
        }
        .tapFeedback(session.checkedEquipment)
        .tapFeedback(session.checkedIngredients)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            content()
        }
    }
}

private struct CheckRow: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Theme.Palette.amber : Theme.Palette.textPrimary.opacity(0.35))
                    .symbolEffect(.bounce, value: isOn)
                Text(title)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(isOn ? 0.6 : 1))
                    .strikethrough(isOn)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - One step

private struct StepView: View {
    let session: CookSession
    let index: Int

    @Environment(\.dynamicTypeSize) private var typeSize

    private var step: RecipeStep { session.recipe.steps[index] }
    private var isLast: Bool { index == session.stepCount - 1 }
    private var scene: CookScene { CookScene.for(step: index, in: session.recipe) }

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                OtherTimersStrip(session: session)

                HStack(spacing: Theme.Spacing.xs) {
                    Text("Step \(index + 1) of \(session.stepCount)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    Spacer(minLength: 0)
                    // At the biggest text sizes the kitchen below says it well enough.
                    if let tool = scene.tool, !typeSize.isAccessibilitySize {
                        Label(tool.title, systemImage: tool.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                            .padding(.horizontal, Theme.Spacing.xs)
                            .frame(minHeight: 30)
                            .background(Theme.Palette.surface, in: Capsule())
                    }
                }

                Text(step.text)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Nutmeg's little kitchen, doing what this step says. It takes
                // whatever room the screen has left, so no step sits half empty.
                KitchenStage(scene: scene,
                             variant: CookScene.variant(recipeID: session.recipe.id, step: index),
                             emoji: session.recipe.emoji, timer: session.timers[index],
                             cheer: session.finishedCount)
                    .frame(maxHeight: typeSize.isAccessibilitySize ? 180 : 440)

                if session.timers[index] != nil {
                    TimerPanel(session: session, step: index)
                    if session.notificationsOff {
                        Text("Timers only ring while Larder is open.")
                            .font(.footnote)
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                            .frame(maxWidth: .infinity)
                    }
                }
                if index + 1 < session.stepCount {
                    NextUpCard(text: session.recipe.steps[index + 1].text)
                }
            }
            .padding(Theme.Spacing.s)
            .frame(minHeight: proxy.size.height, alignment: .top)
        }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: Theme.Spacing.s) {
                Button("Back") { session.back() }
                    .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
                Button(isLast ? "Finish" : "Next") { session.next() }
                    .buttonStyle(PillButtonStyle())
            }
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.top, Theme.Spacing.xs)
            .background(Theme.Palette.background)
        }
    }
}

/// A peek at the following step, because people read ahead while they cook.
private struct NextUpCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Next up")
                .font(.caption.bold())
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .lineLimit(3)
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

/// Timers still going on other steps, so a simmering pot isn't forgotten
/// while you're busy with the next thing. Tap one to jump back to it.
private struct OtherTimersStrip: View {
    let session: CookSession

    var body: some View {
        let timers = session.otherActiveTimers
        if !timers.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(timers, id: \.step) { item in
                        Button { session.jump(to: item.step) } label: {
                            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                                let text = item.timer.isFinished
                                    ? "Step \(item.step + 1) · Time's up!"
                                    : "Step \(item.step + 1) · " + ClockText.text(seconds: Int(ceil(item.timer.remaining(at: context.date))))
                                Label(text, systemImage: "timer")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.Palette.onAccent)
                                    .padding(.horizontal, Theme.Spacing.s)
                                    .frame(minHeight: 40)
                                    .background(item.timer.isFinished ? Theme.Palette.amber : Theme.Palette.softAmber, in: Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct TimerPanel: View {
    let session: CookSession
    let step: Int

    var body: some View {
        if let timer = session.timers[step] {
            // The dial and its buttons side by side, so the kitchen above has room.
            HStack(spacing: Theme.Spacing.s) {
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let remaining = timer.remaining(at: context.date)
                    ZStack {
                        Circle()
                            .stroke(Theme.Palette.surface, lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: timer.isFinished ? 1 : remaining / timer.duration)
                            .stroke(Theme.Palette.amber, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(timer.isFinished ? "Time's up!" : ClockText.text(seconds: Int(ceil(remaining))))
                            .font(.system(size: timer.isFinished ? 22 : 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                    .frame(width: 140, height: 140)
                }

                controls(for: timer)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The timer's buttons are deliberately quiet, so "Next" stays the main
    /// action on the screen.
    @ViewBuilder
    private func controls(for timer: StepTimer) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            if session.ringing.contains(step) {
                Button("Stop") { session.stopRinging(step) }
                    .buttonStyle(PillButtonStyle())
            } else if timer.isIdle {
                control("Start timer") { session.startTimer(step) }
            } else if timer.isRunning {
                control("Pause") { session.pauseTimer(step) }
                control("Reset") { session.resetTimer(step) }
            } else if timer.isPaused {
                control("Resume") { session.resumeTimer(step) }
                control("Reset") { session.resetTimer(step) }
            } else {
                control("Reset") { session.resetTimer(step) }
            }
        }
    }

    private func control(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
    }
}

// MARK: - Done

private struct DoneView: View {
    let recipe: Recipe
    let onMade: (Int) -> Void
    let onBack: () -> Void

    /// Most recipes make one serving. For the ones that make more, ask how
    /// many were eaten, so the calories logged are right.
    @State private var eaten = 1
    @State private var cheer = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            // At the biggest text sizes the page scrolls, with the buttons pinned.
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    message
                    servingsStepper
                }
                .padding(Theme.Spacing.s)
            }
            .safeAreaInset(edge: .bottom) {
                actions
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.top, Theme.Spacing.xs)
                    .background(Theme.Palette.background)
            }
        } else {
            VStack(spacing: Theme.Spacing.m) {
                Spacer(minLength: 0)
                message
                Spacer(minLength: 0)
                servingsStepper
                actions
            }
            .padding(Theme.Spacing.s)
        }
    }

    private var message: some View {
        VStack(spacing: Theme.Spacing.m) {
            // Nutmeg serving it up, with a cheer.
            KitchenStage(scene: .serve, emoji: recipe.emoji, cheer: cheer)
                .frame(height: typeSize.isAccessibilitySize ? 170 : 240)
                .task {
                    try? await Task.sleep(for: .milliseconds(500))
                    cheer += 1
                }

            VStack(spacing: Theme.Spacing.xs) {
                Text("All done!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Your \(recipe.title.lowercased()) is ready. Dig in while it's hot.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
        }
    }

    @ViewBuilder
    private var servingsStepper: some View {
        if recipe.servings > 1 {
            Stepper(value: $eaten, in: 1...recipe.servings) {
                Text("Servings you're eating: \(eaten) of \(recipe.servings)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .padding(Theme.Spacing.s)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button("I made it!") { onMade(eaten) }
                .buttonStyle(PillButtonStyle())
            Button("Back to the steps", action: onBack)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(minHeight: 44)
        }
    }
}
