//
//  PaywallView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    enum Outcome { case purchased, declined }
    private enum Plan { case semester, monthly }

    @Environment(PurchaseStore.self) private var store

    @State private var selection: Plan = .semester
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    /// Bumped by both "get it" and "not now", so the two feel exactly the same.
    @State private var tapCount = 0

    let onFinish: (Outcome) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.s) {
                header
                features
                plans
            }
            .padding(Theme.Spacing.s)
        }
        // Buy and "not now" stay on screen; only the details above scroll.
        .safeAreaInset(edge: .bottom) { actions }
        .background(Theme.Palette.background.ignoresSafeArea())
        .sensoryFeedback(.impact(flexibility: .solid), trigger: tapCount)
        .onChange(of: tapCount) { _, _ in SoundPlayer.tap() }
        .tapFeedback(selection)
        .alert("That didn't go through", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            NutmegView()
                .frame(height: 80)
            Text("Larder Plus")
                .font(.title.bold())
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Scanning and recipe matching stay free.")
                .font(.body)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            featureGroup("Free, always", icon: "checkmark.circle.fill", tint: Theme.Palette.amber, items: [
                "Unlimited pantry scans",
                "Recipes matched to what you have",
            ])
            featureGroup("With Plus", icon: "plus.circle.fill", tint: Theme.Palette.coral, items: [
                "Craving chat",
                "Budget and cost insights",
                "Cook Mode extras",
            ])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func featureGroup(_ title: String, icon: String, tint: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            ForEach(items, id: \.self) { item in
                Label {
                    Text(item).foregroundStyle(Theme.Palette.textPrimary)
                } icon: {
                    Image(systemName: icon).foregroundStyle(tint)
                }
            }
        }
    }

    @ViewBuilder
    private var plans: some View {
        switch store.loadState {
        case .loading:
            HStack(spacing: Theme.Spacing.xs) {
                ProgressView()
                Text("Nutmeg is fetching today's prices…")
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .padding(Theme.Spacing.s)
        case .failed:
            VStack(spacing: Theme.Spacing.s) {
                Text("Nutmeg couldn't fetch the prices. Check your connection and try again.")
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await store.loadOfferings() } }
                    .buttonStyle(PillButtonStyle())
            }
        case .loaded:
            VStack(spacing: Theme.Spacing.xs) {
                if let semester = store.semester {
                    planCard(.semester, package: semester, title: "Semester",
                             detail: semesterDetail(semester),
                             price: semester.storeProduct.localizedPriceString,
                             badge: semesterSavings.map { "Save \($0)%" })
                }
                if let monthly = store.monthly {
                    planCard(.monthly, package: monthly, title: "Monthly",
                             detail: "Billed every month",
                             price: "\(monthly.storeProduct.localizedPriceString)/mo",
                             badge: nil)
                }
            }
        }
    }

    private func planCard(_ plan: Plan, package: Package, title: String,
                          detail: String, price: String, badge: String?) -> some View {
        let isSelected = selection == plan
        return Button {
            selection = plan
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Theme.Palette.coral : Theme.Palette.textPrimary.opacity(0.5))
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption.bold())
                                .foregroundStyle(Theme.Palette.onAccent)
                                .padding(.horizontal, Theme.Spacing.xs)
                                .background(Theme.Palette.coral, in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
                Spacer(minLength: Theme.Spacing.xs)
                Text(price).font(.headline)
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(isSelected ? Theme.Palette.coral : .clear, lineWidth: 3)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var billingNote: some View {
        if let summary = billingSummary {
            Text(summary)
                .font(.footnote)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button("Get Larder Plus", action: purchase)
                .buttonStyle(PillButtonStyle(fill: Theme.Palette.coral))
                .disabled(selectedPackage == nil || isPurchasing)

            billingNote

            HStack(spacing: Theme.Spacing.m) {
                Button("Not now", action: decline)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Button("Restore purchases", action: restore)
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            .frame(minHeight: 44)
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.top, Theme.Spacing.xs)
        .background(Theme.Palette.background)
    }

    // MARK: - Data

    private var selectedPackage: Package? {
        switch selection {
        case .semester: store.semester ?? store.monthly
        case .monthly: store.monthly ?? store.semester
        }
    }

    private var semesterSavings: Int? {
        guard let semester = store.semester, let monthly = store.monthly else { return nil }
        return PlanMath.savingsPercent(monthlyPrice: monthly.storeProduct.price,
                                       planPrice: semester.storeProduct.price,
                                       months: 6)
    }

    private func semesterDetail(_ semester: Package) -> String {
        if let perMonth = semester.storeProduct.localizedPricePerMonth {
            return "6 months, \(perMonth)/month"
        }
        return "6 months"
    }

    private var billingSummary: String? {
        guard let package = selectedPackage else { return nil }
        let price = package.storeProduct.localizedPriceString
        let period = package === store.semester ? "every 6 months" : "every month"
        return "Renews \(period) at \(price) until you cancel."
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Actions

    private func purchase() {
        guard let package = selectedPackage, !isPurchasing else { return }
        tapCount += 1
        isPurchasing = true
        Task {
            let outcome = await store.purchase(package)
            isPurchasing = false
            switch outcome {
            case .purchased: onFinish(.purchased)
            case .cancelled: break
            case .failed(let message): errorMessage = message
            }
        }
    }

    private func decline() {
        tapCount += 1
        onFinish(.declined)
    }

    private func restore() {
        Task {
            if await store.restore() { onFinish(.purchased) }
        }
    }
}
