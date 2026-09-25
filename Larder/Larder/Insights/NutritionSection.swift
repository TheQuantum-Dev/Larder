//
//  NutritionSection.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import SwiftUI

/// Calories and macros for the meals cooked in Larder, against the person's
/// daily targets. It's the Larder Plus part of Insights; without Plus it shows
/// what it would show instead of a blank wall. Nothing here ever turns red or
/// scolds, since a number is just a number.
struct NutritionSection: View {
    let meals: [CookedMeal]
    let onSeePlus: () -> Void

    @Environment(PurchaseStore.self) private var store
    @Environment(AppModel.self) private var app

    private var insights: NutritionInsights { NutritionInsights.compute(from: meals) }
    private var targets: DailyTargets? { app.profile.dailyTargets }

    var body: some View {
        if app.profile.showsNutrition {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack {
                    Text("Nutrition")
                        .font(.title3.bold())
                    Spacer()
                    if !store.isPlusActive {
                        Label("Plus", systemImage: "lock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    }
                }

                if !store.isPlusActive {
                    locked
                } else if app.profile.fitnessGoal == nil {
                    goalPrompt
                } else {
                    todayCard
                    weekCard
                    Text("Only counts meals you cooked in Larder. These are estimates, not medical advice.")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
                }
            }
            .foregroundStyle(Theme.Palette.textPrimary)
        }
    }

    // MARK: - With Plus

    private var todayCard: some View {
        let insights = insights
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Today")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))

            if insights.mealsToday == 0 {
                HStack(spacing: Theme.Spacing.s) {
                    NutmegView()
                        .frame(width: 60)
                    Text("Nothing cooked yet today. Make something and I'll add it up.")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let targets {
                    Text("Your target for the day is about \(targets.kcal) kcal and \(targets.protein) g protein.")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(insights.today.roundedKcal)")
                        .font(.largeTitle.bold())
                    Text(targets.map { "of \($0.kcal) kcal" } ?? "kcal")
                        .font(.title3)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
                if let targets {
                    MacroBar(title: "", value: insights.today.kcal, target: Double(targets.kcal), unit: "kcal",
                             showsLabel: false)
                }
                MacroBar(title: "Protein", value: insights.today.protein, target: targets.map { Double($0.protein) }, unit: "g")
                MacroBar(title: "Carbs", value: insights.today.carbs, target: targets.map { Double($0.carbs) }, unit: "g")
                MacroBar(title: "Fat", value: insights.today.fat, target: targets.map { Double($0.fat) }, unit: "g")
            }

            if let targets, !targets.isPersonal {
                Text("Targets use a typical 2,000 calorie day until you add your stats in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
            }
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var weekCard: some View {
        let insights = insights
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Last 7 days")
                .font(.headline)
            DayBars(days: insights.days)
            if let average = insights.dailyAverage {
                Text("On days you cook: about \(average.roundedKcal) kcal and \(average.roundedProtein) g protein.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
        }
    }

    private var goalPrompt: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(width: 60)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Pick a goal and I'll set daily targets for you.")
                    .font(.subheadline)
                Button("Choose a goal") { app.showSettings = true }
                    .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
            }
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    // MARK: - Without Plus

    private var locked: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                lockedPoint("flame.fill", "Today's calories and protein against your target")
                lockedPoint("chart.bar.fill", "Your last seven days at a glance")
                lockedPoint("figure.strengthtraining.traditional", "Averages for the days you cook")
            }
            Button("See Larder Plus", action: onSeePlus)
                .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func lockedPoint(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.Palette.amber)
                .frame(width: 30)
            Text(text)
                .font(.body)
        }
    }
}

/// One nutrient against its target. The bar just fills; it never changes
/// colour for going over.
private struct MacroBar: View {
    let title: String
    let value: Double
    let target: Double?
    let unit: String
    /// Off for calories, whose number is already the big one above.
    var showsLabel = true

    private var progress: Double {
        guard let target, target > 0 else { return 0 }
        return min(value / target, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsLabel {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(valueText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
            }
            if target != nil {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.background)
                        Capsule()
                            .fill(Theme.Palette.amber)
                            .frame(width: proxy.size.width * progress)
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progress)
                }
                .frame(height: 10)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(showsLabel ? title : "Calories")
        .accessibilityValue(valueText)
    }

    private var valueText: String {
        let done = Int(value.rounded()).formatted()
        guard let target else { return "\(done) \(unit)" }
        return "\(done) of \(Int(target.rounded()).formatted()) \(unit)"
    }
}

/// Seven columns of calories, one per day, ending today. There's no target
/// line: it only counts meals cooked here, so a line for a whole day's eating
/// would make an ordinary day of cooking look small.
private struct DayBars: View {
    let days: [NutritionInsights.Day]

    private let labelRoom: CGFloat = 20
    private let barRoom: CGFloat = 100

    private var ceiling: Double { max(days.map(\.total.kcal).max() ?? 0, 1) }

    private func barHeight(_ kcal: Double) -> CGFloat {
        kcal <= 0 ? 10 : max(10, barRoom * kcal / ceiling)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    VStack(spacing: 0) {
                        Text(day.meals > 0 ? "\(day.total.roundedKcal)" : "")
                            .font(.caption2.bold())
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .frame(height: labelRoom)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(fill(day, isToday: index == days.count - 1))
                            .frame(height: barHeight(day.total.kcal))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(label(day))
                }
            }
            .frame(height: barRoom + labelRoom, alignment: .bottom)

            HStack(spacing: Theme.Spacing.xs) {
                ForEach(days) { day in
                    Text(day.start.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: days)
    }

    private func fill(_ day: NutritionInsights.Day, isToday: Bool) -> Color {
        if day.meals == 0 { return Theme.Palette.background }
        return isToday ? Theme.Palette.amber : Theme.Palette.softAmber
    }

    private func label(_ day: NutritionInsights.Day) -> String {
        let date = day.start.formatted(.dateTime.weekday(.wide))
        return day.meals == 0 ? "\(date), nothing cooked" : "\(date), \(day.total.roundedKcal) kilocalories"
    }
}
