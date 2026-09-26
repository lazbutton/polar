import Foundation
import HealthKit
import SwiftData

final class HealthService {
    static let shared = HealthService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(
            toShare: [HKObjectType.stateOfMindType()],
            read: [
                HKObjectType.stateOfMindType(),
                HKCategoryType(.sleepAnalysis),
                HKQuantityType(.stepCount),
                HKQuantityType(.timeInDaylight),
            ]
        )
    }

    func write(_ moment: Moment, emotion: Emotion) async throws -> UUID {
        if let existing = moment.healthSampleID {
            try? await delete(id: existing)
        }
        let sample = HKStateOfMind(
            date: moment.createdAt,
            kind: .momentaryEmotion,
            valence: emotion.valence(intensity: moment.intensity ?? 5),
            labels: emotion.healthLabel.map { [$0] } ?? [],
            associations: moment.associations.compactMap { AssociationCatalog.association(for: $0)?.healthAssociation }
        )
        try await store.save(sample)
        return sample.uuid
    }

    func delete(id: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.deleteObjects(of: HKObjectType.stateOfMindType(), predicate: HKQuery.predicateForObject(with: id)) { _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Somme du sommeil entre 18 h la veille et 14 h, sources dédoublonnées, Apple Watch prioritaire.
    func sleepHours(for logicalDay: Date, calendar: Calendar = .current) async -> Double? {
        guard isAvailable else { return nil }
        guard let end = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: logicalDay),
              let start = calendar.date(byAdding: .hour, value: -20, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, result, _ in
                continuation.resume(returning: (result as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
        let asleep = samples.filter { sample in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
            return HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
        }
        guard !asleep.isEmpty else { return nil }
        let watch = asleep.filter { sample in
            let bundle = sample.sourceRevision.source.bundleIdentifier.lowercased()
            let product = sample.sourceRevision.productType?.lowercased() ?? ""
            return bundle.contains("watch") || product.contains("watch")
        }
        return mergedHours(of: watch.isEmpty ? asleep : watch)
    }

    /// Horaires du sommeil : début du premier échantillon endormi, fin du dernier.
    func sleepTiming(for logicalDay: Date, calendar: Calendar = .current) async -> (bedtime: Date, wake: Date)? {
        guard isAvailable else { return nil }
        guard let end = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: logicalDay),
              let start = calendar.date(byAdding: .hour, value: -20, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, result, _ in
                continuation.resume(returning: (result as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
        let asleep = samples.filter { sample in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
            return HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
        }
        guard let first = asleep.map(\.startDate).min(), let last = asleep.map(\.endDate).max() else { return nil }
        return (first, last)
    }

    /// Minutes de lumière du jour (Apple Watch) et pas d'une journée.
    func dailyTotals(for day: Date, calendar: Calendar = .current) async -> (daylight: Double?, steps: Int?) {
        guard isAvailable else { return (nil, nil) }
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return (nil, nil) }
        let range = HKQuery.predicateForSamples(withStart: start, end: end)

        func sum(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) async -> Double? {
            await withCheckedContinuation { continuation in
                let descriptor = HKStatisticsQuery(
                    quantityType: HKQuantityType(id),
                    quantitySamplePredicate: range,
                    options: .cumulativeSum
                ) { _, statistics, _ in
                    continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
                }
                store.execute(descriptor)
            }
        }

        let daylight = await sum(.timeInDaylight, .minute())
        let steps = await sum(.stepCount, .count()).map { Int($0) }
        return (daylight, steps)
    }

    private func mergedHours(of samples: [HKCategorySample]) -> Double {
        let intervals = samples.map { ($0.startDate, $0.endDate) }.sorted { $0.0 < $1.0 }
        var merged: [(Date, Date)] = []
        for interval in intervals {
            if var last = merged.last, interval.0 <= last.1 {
                last.1 = max(last.1, interval.1)
                merged[merged.count - 1] = last
            } else {
                merged.append(interval)
            }
        }
        let seconds = merged.reduce(0) { $0 + $1.1.timeIntervalSince($1.0) }
        return seconds / 3600
    }
}

enum HealthSync {
    @MainActor
    static func catchUp(moments: [Moment], in context: ModelContext) async {
        guard Preferences.shared.healthWriteEnabled else { return }
        for moment in moments where moment.healthSampleID == nil {
            guard let key = moment.emotionKey,
                  let emotion = EmotionCatalog.emotion(for: key),
                  moment.intensity != nil else { continue }
            if let id = try? await HealthService.shared.write(moment, emotion: emotion) {
                moment.healthSampleID = id
            }
        }
        try? context.save()
    }
}
