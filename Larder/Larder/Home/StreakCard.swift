//
//  StreakCard.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import SwiftUI

/// The seven days of this week as seven little Nutmegs. A day you cooked has
/// an awake, smiling one; today, if you haven't yet, has a sleepy one with a
/// gently pulsing ring; days gone by are a quiet outline, never a mark against
/// you; days still to come are dashed.
struct StreakWeekView: View {
    let week: StreakWeek
    /// Today's Nutmeg starts asleep and wakes up a moment after this appears.
    /// Used on the "you made it" screen, right when the day fills in.
    var wakesToday = false
    /// Whether waking up gets a haptic, and whether it's the bigger milestone one.
    var playsHaptic = true
    var isMilestone = false
    var glyphSize: CGFloat = 40

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var todayAwake = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(week.days) { day in
                DaySlot(day: day, awake: isAwake(day), size: glyphSize)
            }
        }
        .task(id: wakesToday) {
            guard wakesToday else { return }
            if reduceMotion {
                todayAwake = true
                return
            }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { todayAwake = true }
        }
        .sensoryFeedback(trigger: todayAwake) { _, awake in
            guard awake, wakesToday, playsHaptic else { return nil }
            return isMilestone ? .success : .impact(weight: .medium)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.summary(of: week))
    }

    private func isAwake(_ day: StreakWeek.Day) -> Bool {
        guard day.state == .cooked else { return false }
        return day.isToday && wakesToday ? todayAwake : true
    }

    /// "Cooked 4 of 7 days this week. Monday cooked, ..."
    static func summary(of week: StreakWeek) -> String {
        let days = week.days.map { day -> String in
            let name = day.date.formatted(.dateTime.weekday(.wide))
            switch day.state {
            case .cooked: return "\(name) cooked"
            case .today: return "\(name), today, not cooked yet"
            case .missed: return "\(name) not cooked"
            case .upcoming: return "\(name) still to come"
            }
        }
        return "Cooked \(week.cookedCount) of 7 days this week. " + days.joined(separator: ". ")
    }
}

/// One day of the week: its Nutmeg and its weekday letter.
private struct DaySlot: View {
    let day: StreakWeek.Day
    let awake: Bool
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var sparkle = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                NutmegGlyph(face: day.state == .upcoming ? .outline : .asleep)
                    .opacity(awake ? 0 : (day.state == .missed ? 0.5 : 1))

                if day.isToday, !awake { ring }

                NutmegGlyph(face: .awake)
                    .scaleEffect(awake ? 1 : 0.5)
                    .opacity(awake ? 1 : 0)

                if sparkle {
                    Image(systemName: "sparkle")
                        .font(.footnote.bold())
                        .foregroundStyle(Theme.Palette.amber)
                        .offset(x: size * 0.36, y: -size * 0.32)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .animation(.spring(response: 0.45, dampingFraction: 0.55), value: awake)

            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2.weight(day.isToday ? .bold : .regular))
                .foregroundStyle(Theme.Palette.textPrimary.opacity(day.isToday ? 1 : 0.6))
        }
        .frame(maxWidth: .infinity)
        .onChange(of: awake) { _, nowAwake in
            // Only a day that really wakes up sparkles, not one drawn awake from the start.
            guard nowAwake else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { sparkle = true }
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.3)) { sparkle = false }
            }
        }
    }

    /// A ring around today's sleepy Nutmeg that breathes slowly, like a nudge.
    private var ring: some View {
        Ellipse()
            .strokeBorder(Theme.Palette.amber, lineWidth: 3)
            .frame(width: size * 0.86, height: size * 0.78)
            .offset(y: size * 0.08)
            .scaleEffect(pulse ? 1.07 : 0.98)
            .opacity(pulse ? 0.55 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

/// The streak, on Home and Insights: how long it is, the week's Nutmegs, and
/// what's next. Warm in every state, including when there isn't a streak yet.
struct StreakCard: View {
    let dates: [Date]
    var now = Date()
    /// Adds the total number of days cooked, for the fuller version on Insights.
    var showsDetails = false
    /// Makes the whole card tappable, like Home's, which opens Insights.
    var onTap: (() -> Void)?

    private var status: CookingStreak.Status { CookingStreak.status(from: dates, now: now) }

    var body: some View {
        let status = status
        let best = CookingStreak.best(from: dates)
        let week = StreakWeek.make(cookedDates: dates, now: now)

        let content = VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: status == .none ? "flame" : "flame.fill")
                    .font(.title2)
                    .foregroundStyle(status == .none ? Theme.Palette.textPrimary.opacity(0.35) : Theme.Palette.amber)
                    .symbolEffect(.bounce, value: status.days)
                Text(title(status))
                    .font(.title2.bold())
                    .contentTransition(.numericText(value: Double(status.days)))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: status.days)
                Spacer(minLength: 0)
                if best > status.days {
                    Text("Best \(best)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
            }
            Text(line(status))
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))

            StreakWeekView(week: week)
                .padding(.vertical, Theme.Spacing.xs)

            footer(status, week: week)

            if showsDetails {
                let cookedDays = Set(dates.map { Calendar.current.startOfDay(for: $0) }).count
                if cookedDays > 0 {
                    Text("\(cookedDays) \(cookedDays == 1 ? "day" : "days") cooked in total")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
                }
            }
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title(status)). \(line(status)) \(StreakWeekView.summary(of: week))")

        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
                .accessibilityHint("Opens your insights")
        } else {
            content
        }
    }

    private func title(_ status: CookingStreak.Status) -> String {
        status == .none ? "No streak yet" : "\(status.days)-day streak"
    }

    private func line(_ status: CookingStreak.Status) -> String {
        switch status {
        case .none: "Cook anything today to start one."
        case .safe: "You cooked today. See you tomorrow!"
        case .atRisk: "Cook anything today to keep it going."
        }
    }

    @ViewBuilder
    private func footer(_ status: CookingStreak.Status, week: StreakWeek) -> some View {
        if week.isPerfect {
            Label("Perfect week", systemImage: "checkmark.seal.fill")
                .font(.caption.bold())
                .foregroundStyle(Theme.Palette.onAccent)
                .padding(.horizontal, Theme.Spacing.xs)
                .frame(minHeight: 30)
                .background(Theme.Palette.sage, in: Capsule())
        } else {
            let coralEarned = NutmegLook.earned(bestStreak: CookingStreak.best(from: dates),
                                                mealCount: dates.count).contains(.coral)
            Text(StreakMilestone.line(days: status.days, coralEarned: coralEarned)
                 ?? "\(week.cookedCount) of 7 days this week")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
        }
    }
}

/// The moment after a meal that lit up a new day: the week's Nutmegs with
/// today's waking up, and the streak number to go with it.
struct StreakCelebration: View {
    let progress: StreakProgress
    /// The first meal ever has its own, bigger haptic, so this one stays quiet then.
    var playsHaptic = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.amber)
                    .symbolEffect(.bounce, value: progress.days)
                Text("\(progress.days)-day streak!")
                    .font(.title2.bold())
                Spacer(minLength: 0)
                if progress.milestone != nil {
                    Text("Milestone")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.Palette.onAccent)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .frame(minHeight: 30)
                        .background(Theme.Palette.sage, in: Capsule())
                }
            }
            Text(line)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))

            StreakWeekView(week: progress.week, wakesToday: true, playsHaptic: playsHaptic,
                           isMilestone: progress.milestone != nil)
                .padding(.vertical, Theme.Spacing.xs)

            if let next = StreakMilestone.line(days: progress.days, coralEarned: progress.coralEarned) {
                Text(next)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var line: String {
        if let milestone = progress.milestone { return "\(milestone) days in a row. Nutmeg is thrilled!" }
        if progress.days == 1 { return "A streak starts today. Cook again tomorrow to keep it going." }
        return "You kept it going."
    }
}
