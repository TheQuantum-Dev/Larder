//
//  GoalSettingsView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import SwiftUI
import UIKit

/// What you're working toward, and, if you like, a little about you so the
/// calorie target fits. It all stays on the phone.
struct GoalSettingsView: View {
    @State private var profile = ProfileStore.load()
    @AppStorage(AppSettings.useMetricKey) private var useMetric = Locale.current.measurementSystem == .metric
    @AppStorage(AppSettings.healthSyncKey) private var healthSync = false
    @State private var isFillingFromHealth = false
    @State private var healthNote: String?
    @State private var editingTarget: TargetKind?

    private var goal: FitnessGoal? { profile.fitnessGoal }

    var body: some View {
        Form {
            goalSection
            if goal?.showsNutrition ?? true {
                bodySection
                healthSection
            }
            if let targets = profile.dailyTargets {
                targetSection(targets)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Palette.background.ignoresSafeArea())
        .toolbar {
            // Number pads have no return key, so this puts the typed number in.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
        .navigationTitle("Your goal")
        .navigationBarTitleDisplayMode(.inline)
        .tapFeedback(profile.goal)
        .onChange(of: profile) { _, new in save(new) }
        .onAppear(perform: debugTargets)
        .sheet(item: $editingTarget) { kind in
            TargetEditorSheet(kind: kind, value: profile.dailyTargets.map(kind.value(in:)) ?? 0,
                              suggested: profile.suggestedTargets.map(kind.value(in:))) { custom in
                var targets = profile.customTargets ?? CustomTargets()
                targets[keyPath: kind.field] = custom
                profile.customTargets = targets.isEmpty ? nil : targets
            }
            .presentationDetents([.height(330)])
        }
    }

    /// `-customTargets 2600,140,,` sets your own calories and protein and
    /// leaves carbs and fat suggested, and `-editTarget protein` opens that
    /// target's editor (debug builds only).
    private func debugTargets() {
        #if DEBUG
        editingTarget = UserDefaults.standard.string(forKey: "editTarget").flatMap(TargetKind.init(rawValue:))
        guard let text = UserDefaults.standard.string(forKey: "customTargets") else { return }
        let values = text.split(separator: ",", omittingEmptySubsequences: false).map { Int($0) }
        func value(_ index: Int) -> Int? { values.indices.contains(index) ? values[index] : nil }
        profile.customTargets = CustomTargets(kcal: value(0), protein: value(1), carbs: value(2), fat: value(3))
        #endif
    }

    /// Only this screen's fields are written, so nothing edited elsewhere is lost.
    private func save(_ new: Profile) {
        var stored = ProfileStore.load()
        stored.goal = new.goal
        stored.bodyStats = new.bodyStats
        stored.customTargets = new.customTargets
        ProfileStore.save(stored)
    }

    // MARK: - Sections

    private var goalSection: some View {
        Section("What are you working toward?") {
            ForEach(FitnessGoal.allCases) { option in
                Button { profile.goal = option.rawValue } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        Text(option.emoji).font(.title2)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(option.title)
                                .font(.headline)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            if let detail = option.detail {
                                Text(detail)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer(minLength: Theme.Spacing.xs)
                        if goal == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Palette.amber)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(goal == option ? .isSelected : [])
                .listRowBackground(Theme.Palette.surface)
            }
        }
    }

    private var bodySection: some View {
        Section {
            Picker("Units", selection: $useMetric) {
                Text("Metric").tag(true)
                Text("US").tag(false)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Theme.Palette.surface)

            LabeledContent("Birth year") {
                TextField("Year", value: $profile.birthYear, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            .listRowBackground(Theme.Palette.surface)

            Picker("Sex", selection: sex) {
                Text("Prefer not to say").tag(BiologicalSex?.none)
                ForEach(BiologicalSex.allCases) { Text($0.title).tag(BiologicalSex?.some($0)) }
            }
            .listRowBackground(Theme.Palette.surface)

            heightRow
                .listRowBackground(Theme.Palette.surface)
            weightRow
                .listRowBackground(Theme.Palette.surface)

            Picker("Activity", selection: activity) {
                ForEach(ActivityLevel.allCases) { Text($0.title).tag($0) }
            }
            .listRowBackground(Theme.Palette.surface)
        } header: {
            Text("About you (optional)")
        } footer: {
            Text("\(profile.bodyStats.activity.detail). This only sets your daily target, and it stays on your phone. Leave anything blank and I'll go with a typical 2,000 calorie day.")
        }
    }

    @ViewBuilder
    private var heightRow: some View {
        if useMetric {
            LabeledContent("Height") {
                HStack(spacing: Theme.Spacing.xs) {
                    TextField("—", value: $profile.heightCm, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("cm")
                }
            }
        } else {
            LabeledContent("Height") {
                HStack(spacing: Theme.Spacing.xs) {
                    TextField("—", value: feet, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("ft")
                    TextField("—", value: inches, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("in")
                }
            }
        }
    }

    @ViewBuilder
    private var weightRow: some View {
        LabeledContent("Weight") {
            HStack(spacing: Theme.Spacing.xs) {
                if useMetric {
                    TextField("—", value: $profile.weightKg, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("kg")
                } else {
                    TextField("—", value: pounds, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("lb")
                }
            }
        }
    }

    private var healthSection: some View {
        Section {
            Toggle("Save meals to Apple Health", isOn: Binding(
                get: { healthSync },
                set: { on in
                    healthSync = on
                    if on { Task { await Health.shared.requestAccess() } }
                }
            ))
            .listRowBackground(Theme.Palette.surface)

            Button { fillFromHealth() } label: {
                HStack {
                    Text("Fill in from Apple Health")
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Spacer()
                    if isFillingFromHealth { ProgressView() }
                }
            }
            .disabled(isFillingFromHealth)
            .listRowBackground(Theme.Palette.surface)
        } header: {
            Text("Apple Health")
        } footer: {
            Text((healthNote.map { $0 + " " } ?? "")
                 + "Larder saves each meal you cook, with its calories and macros, and can read your height, weight and age. You can change what it sees in the Health app, under Sharing.")
        }
    }

    private func fillFromHealth() {
        isFillingFromHealth = true
        Task {
            await Health.shared.requestAccess()
            let stats = await Health.shared.readBodyStats()
            profile.merge(stats, overwrite: true)
            healthNote = stats == BodyStats() ? "Health didn't have anything to share yet." : "Filled in from Health."
            isFillingFromHealth = false
        }
    }

    /// The day's numbers as a card. Tapping one opens its editor.
    private func targetSection(_ targets: DailyTargets) -> some View {
        Section {
            DailyTargetCard(targets: targets, custom: profile.customTargets) { editingTarget = $0 }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            if targets.isCustom {
                Button("Use the suggested targets") { profile.customTargets = nil }
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .listRowBackground(Theme.Palette.surface)
            }
        } header: {
            Text("Your daily target")
        } footer: {
            Text(targetFooter(targets))
        }
    }

    private func targetFooter(_ targets: DailyTargets) -> String {
        if targets.isCustom {
            return "The ones in color are your own, and I'll use them everywhere. Tap any number to change it."
        }
        return (targets.isPersonal ? "" : "Based on a typical 2,000 calorie day until you add your stats. ")
            + "Tap a number to set your own. These are rough estimates from a standard formula, not medical advice. "
            + "For a real plan, talk to a doctor or dietitian."
    }

    // MARK: - Bindings

    private var sex: Binding<BiologicalSex?> {
        Binding(get: { profile.sex.flatMap(BiologicalSex.init(rawValue:)) },
                set: { profile.sex = $0?.rawValue })
    }

    private var activity: Binding<ActivityLevel> {
        Binding(get: { profile.bodyStats.activity },
                set: { profile.activity = $0.rawValue })
    }

    private var pounds: Binding<Double?> {
        Binding(get: { profile.weightKg.map { UnitConversion.pounds(kg: $0) } },
                set: { profile.weightKg = $0.map { UnitConversion.kg(pounds: $0) } })
    }

    private var feet: Binding<Int?> {
        Binding(get: { profile.heightCm.map { UnitConversion.feetAndInches(fromCm: $0).feet } },
                set: { newFeet in
                    let inches = profile.heightCm.map { UnitConversion.feetAndInches(fromCm: $0).inches } ?? 0
                    profile.heightCm = newFeet.map { UnitConversion.cm(feet: $0, inches: inches) }
                })
    }

    private var inches: Binding<Int?> {
        Binding(get: { profile.heightCm.map { UnitConversion.feetAndInches(fromCm: $0).inches } },
                set: { newInches in
                    let feet = profile.heightCm.map { UnitConversion.feetAndInches(fromCm: $0).feet } ?? 5
                    profile.heightCm = newInches.map { UnitConversion.cm(feet: feet, inches: $0) }
                })
    }
}
