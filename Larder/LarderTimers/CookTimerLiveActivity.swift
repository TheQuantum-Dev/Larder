//
//  CookTimerLiveActivity.swift
//  LarderTimers
//
//  Created by Joshua Samuel on 9/27/26.
//

import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// A Cook Mode timer on the lock screen and in the Dynamic Island: which
/// recipe and step it's for, and the time left, counting down on its own.
/// When it goes off, it says so; the ringing itself comes from the alarm.
struct CookTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CookTimerMetadata>.self) { context in
            LockScreenTimer(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Palette.background)
                .activitySystemActionForegroundColor(Palette.text)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(.timerNutmeg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimeLeft(mode: context.state.mode, tint: context.attributes.tintColor)
                        .font(.title2.bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StepLine(metadata: context.attributes.metadata)
                }
            } compactLeading: {
                Text(context.attributes.metadata?.recipeEmoji ?? "🍳")
            } compactTrailing: {
                TimeLeft(mode: context.state.mode, tint: context.attributes.tintColor)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(context.attributes.tintColor)
            }
            .keylineTint(context.attributes.tintColor)
        }
    }
}

/// Warm colors that read on the lock screen in light and dark alike.
private enum Palette {
    static let background = Color(red: 0x2E / 255, green: 0x22 / 255, blue: 0x19 / 255)
    static let text = Color(red: 0xFB / 255, green: 0xF3 / 255, blue: 0xE6 / 255)
}

private struct LockScreenTimer: View {
    let attributes: AlarmAttributes<CookTimerMetadata>
    let state: AlarmPresentationState

    var body: some View {
        HStack(spacing: 12) {
            Image(.timerNutmeg)
                .resizable()
                .scaledToFit()
                .frame(width: 54)
            StepLine(metadata: attributes.metadata)
            Spacer(minLength: 0)
            TimeLeft(mode: state.mode, tint: attributes.tintColor)
                .font(.system(size: 34, weight: .bold, design: .rounded))
        }
        .padding(16)
        .foregroundStyle(Palette.text)
    }
}

/// "🍝 Simple tomato pasta" over "Step 3 · Simmer the sauce…".
private struct StepLine: View {
    let metadata: CookTimerMetadata?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(metadata?.recipeEmoji ?? "🍳") \(metadata?.recipeTitle ?? "Cook Mode")")
                .font(.headline)
                .lineLimit(1)
            if let metadata {
                Text("Step \(metadata.step) · \(metadata.stepSnippet)")
                    .font(.subheadline)
                    .foregroundStyle(Palette.text.opacity(0.75))
                    .lineLimit(2)
            }
        }
        .foregroundStyle(Palette.text)
    }
}

/// The countdown, a paused time, or "Time's up!".
private struct TimeLeft: View {
    let mode: AlarmPresentationState.Mode
    let tint: Color

    var body: some View {
        switch mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(tint)
        case .paused(let paused):
            let left = max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)
            VStack(alignment: .trailing, spacing: 0) {
                Text(Duration.seconds(left).formatted(.time(pattern: .minuteSecond)))
                    .monospacedDigit()
                Text("Paused")
                    .font(.caption.bold())
            }
            .foregroundStyle(Palette.text.opacity(0.75))
        case .alert:
            Text("Time's up!")
                .foregroundStyle(tint)
        @unknown default:
            Image(systemName: "timer")
        }
    }
}
