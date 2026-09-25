//
//  HealthSync.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import HealthKit

/// One cooked meal, as Apple Health will store it.
nonisolated struct HealthMeal: Equatable, Sendable {
    let recipeID: String
    let title: String
    let date: Date
    let macros: Macros

    /// The same meal always gets the same id, so saving it twice can't
    /// double-count it in Health.
    var syncID: String { "larder-\(recipeID)-\(Int(date.timeIntervalSince1970))" }
}

/// The four nutrients Larder writes to Health, and the units Health wants.
nonisolated enum HealthNutrients {
    struct Entry: Equatable {
        let identifier: HKQuantityTypeIdentifier
        let value: Double
        let unit: HKUnit
    }

    static let identifiers: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal,
    ]

    static func entries(for macros: Macros) -> [Entry] {
        [
            Entry(identifier: .dietaryEnergyConsumed, value: macros.kcal, unit: .kilocalorie()),
            Entry(identifier: .dietaryProtein, value: macros.protein, unit: .gram()),
            Entry(identifier: .dietaryCarbohydrates, value: macros.carbs, unit: .gram()),
            Entry(identifier: .dietaryFatTotal, value: macros.fat, unit: .gram()),
        ]
    }
}

/// Everything Larder does with Apple Health, behind a protocol so tests and
/// devices without Health can use a stand-in.
nonisolated protocol HealthSync: Sendable {
    /// False where Health data doesn't exist; everything else then does nothing.
    var isAvailable: Bool { get }
    /// Shows the system permission sheet for what Larder asks about. Denying
    /// anything is fine: the rest of the app never depends on it.
    func requestAccess() async
    /// Saves one cooked meal's calories and macros as a single food entry,
    /// for whichever of them the person allowed.
    func logMeal(_ meal: HealthMeal) async
    /// Height, weight, age and sex, for whatever Health has and allowed.
    func readBodyStats() async -> BodyStats
}

nonisolated enum Health {
    static let shared: any HealthSync = HKHealthStore.isHealthDataAvailable() ? HealthKitSync() : NoOpHealthSync()
}

/// Used where Health isn't available, and in tests.
nonisolated struct NoOpHealthSync: HealthSync {
    var isAvailable: Bool { false }
    func requestAccess() async {}
    func logMeal(_ meal: HealthMeal) async {}
    func readBodyStats() async -> BodyStats { BodyStats() }
}

/// The real thing. `HKHealthStore` is safe to use from any thread.
nonisolated final class HealthKitSync: HealthSync, @unchecked Sendable {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        Set(HealthNutrients.identifiers.map { HKQuantityType($0) })
    }

    private var readTypes: Set<HKObjectType> {
        [HKCharacteristicType(.dateOfBirth), HKCharacteristicType(.biologicalSex),
         HKQuantityType(.height), HKQuantityType(.bodyMass)]
    }

    func requestAccess() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    func logMeal(_ meal: HealthMeal) async {
        guard isAvailable else { return }
        let samples: [HKSample] = HealthNutrients.entries(for: meal.macros).compactMap { entry in
            let type = HKQuantityType(entry.identifier)
            guard entry.value > 0, store.authorizationStatus(for: type) == .sharingAuthorized else { return nil }
            return HKQuantitySample(type: type,
                                    quantity: HKQuantity(unit: entry.unit, doubleValue: entry.value),
                                    start: meal.date, end: meal.date,
                                    metadata: [HKMetadataKeySyncIdentifier: "\(meal.syncID)-\(entry.identifier.rawValue)",
                                               HKMetadataKeySyncVersion: 1])
        }
        guard !samples.isEmpty else { return }
        let food = HKCorrelation(type: HKCorrelationType(.food), start: meal.date, end: meal.date,
                                 objects: Set(samples),
                                 metadata: [HKMetadataKeyFoodType: meal.title,
                                            HKMetadataKeySyncIdentifier: meal.syncID,
                                            HKMetadataKeySyncVersion: 1])
        try? await store.save(food)
    }

    func readBodyStats() async -> BodyStats {
        guard isAvailable else { return BodyStats() }
        var stats = BodyStats()
        if let components = try? store.dateOfBirthComponents() {
            stats.birthYear = components.year
        }
        if let sex = try? store.biologicalSex().biologicalSex {
            switch sex {
            case .female: stats.sex = .female
            case .male: stats.sex = .male
            default: break
            }
        }
        stats.heightCm = await latest(.height, unit: .meterUnit(with: .centi))
        stats.weightKg = await latest(.bodyMass, unit: .gramUnit(with: .kilo))
        return stats
    }

    private func latest(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HKQuantityType(identifier))],
                                                 sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
                                                 limit: 1)
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return sample.quantity.doubleValue(for: unit)
    }
}
