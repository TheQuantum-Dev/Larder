//
//  CookModeView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

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
            ZStack {
                content
                    .id(session.phase)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: session.phase)
        // A timer going off gets its own buzz, different from a tap.
        .sensoryFeedback(.warning, trigger: session.finishedCount)
        .alert("Stop cooking?", isPresented: $confirmingExit) {
            Button("Keep cooking", role: .cancel) {}
            Button("Stop", role: .destructive) { onClose() }
        } message: {
            Text("Your timers will stop.")
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            startDebugTimer()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            session.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // A timer can run out while the app is asleep, so check on return.
            if newPhase == .active { session.refresh() }
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
        }
    }

    private func requestClose() {
        if case .step = session.phase {
            confirmingExit = true
        } else {
            onClose()
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
            DoneView(recipe: session.recipe, onFinish: onFinish, onBack: { session.back() })
        }
    }

    /// `-cookTimer YES` starts the timer on the current step, and `-cookTimerStep 2`
    /// starts the one on step 2 (debug builds only).
    private func startDebugTimer() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "cookTimer"), let step = session.currentStep {
            session.startTimer(step)
        }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(spacing: Theme.Spacing.s) {
                    NutmegView()
                        .frame(width: 80)
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
        .sensoryFeedback(.selection, trigger: session.checkedEquipment)
        .sensoryFeedback(.selection, trigger: session.checkedIngredients)
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

    private var step: RecipeStep { session.recipe.steps[index] }
    private var isLast: Bool { index == session.stepCount - 1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                OtherTimersStrip(session: session)

                Text("Step \(index + 1) of \(session.stepCount)")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))

                Text(step.text)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if session.timers[index] != nil {
                    TimerPanel(session: session, step: index)
                }

                // Timer steps already fill the screen, so the preview is for the quieter ones.
                if session.timers[index] == nil, index + 1 < session.stepCount {
                    NextUpCard(text: session.recipe.steps[index + 1].text)
                }
            }
            .padding(Theme.Spacing.s)
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
            VStack(spacing: Theme.Spacing.m) {
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let remaining = timer.remaining(at: context.date)
                    ZStack {
                        Circle()
                            .stroke(Theme.Palette.surface, lineWidth: 16)
                        Circle()
                            .trim(from: 0, to: timer.isFinished ? 1 : remaining / timer.duration)
                            .stroke(Theme.Palette.amber, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(timer.isFinished ? "Time's up!" : ClockText.text(seconds: Int(ceil(remaining))))
                            .font(.system(size: timer.isFinished ? 36 : 54, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                    .frame(width: 240, height: 240)
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
        HStack(spacing: Theme.Spacing.s) {
            if timer.isIdle {
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
    let onFinish: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)

            NutmegView()
                .frame(height: 180)

            VStack(spacing: Theme.Spacing.xs) {
                Text("All done!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Your \(recipe.title.lowercased()) is ready. Dig in while it's hot.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.xs) {
                Button("I made it!", action: onFinish)
                    .buttonStyle(PillButtonStyle())
                Button("Back to the steps", action: onBack)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(minHeight: 44)
            }
        }
        .padding(Theme.Spacing.s)
    }
}
