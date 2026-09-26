import Foundation
import Observation

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case alwaysLight
    case system
    case automaticNight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .alwaysLight: "Toujours clair"
        case .system: "Suivre le système"
        case .automaticNight: "Nuit automatique"
        }
    }
}

struct AlertRule: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case shortSleep
        case elevated
        case depressed

        var id: String { rawValue }

        var label: String {
            switch self {
            case .shortSleep: "Sommeil sous"
            case .elevated: "Humeur haute à"
            case .depressed: "Humeur basse à"
            }
        }
    }

    var id: UUID
    var kind: Kind
    var threshold: Double
    var span: Int

    init(id: UUID = UUID(), kind: Kind, threshold: Double, span: Int) {
        self.id = id
        self.kind = kind
        self.threshold = threshold
        self.span = span
    }
}

@MainActor
@Observable
final class Preferences {
    static let shared = Preferences()

    private let defaults: UserDefaults

    var startHour: Int
    var eveningReminderEnabled: Bool
    var eveningHour: Int
    var eveningMinute: Int
    var trackDepressed: Bool
    var trackElevated: Bool
    var trackIrritability: Bool
    var trackAnxiety: Bool
    var trackPsychotic: Bool
    var trackWeight: Bool
    var trackTherapy: Bool
    var customPointNames: [String]
    var behaviorTags: [String]
    var faceIDEnabled: Bool
    var blurInSwitcher: Bool
    var healthWriteEnabled: Bool
    var cloudKitEnabled: Bool
    var companionPhrases: Bool
    var aiEnabled: Bool
    var appearance: AppearanceMode
    var nightStartHour: Int
    var alertRules: [AlertRule]
    var latitude: Double?
    var longitude: Double?

    init(defaults: UserDefaults? = nil) {
        let store = defaults ?? UserDefaults(suiteName: SharedStore.appGroupIdentifier) ?? .standard
        self.defaults = store
        startHour = store.object(forKey: Keys.startHour) as? Int ?? 4
        eveningReminderEnabled = store.bool(forKey: Keys.eveningReminderEnabled)
        eveningHour = store.object(forKey: Keys.eveningHour) as? Int ?? 21
        eveningMinute = store.object(forKey: Keys.eveningMinute) as? Int ?? 0
        trackDepressed = store.object(forKey: Keys.trackDepressed) as? Bool ?? true
        trackElevated = store.object(forKey: Keys.trackElevated) as? Bool ?? true
        trackIrritability = store.object(forKey: Keys.trackIrritability) as? Bool ?? true
        trackAnxiety = store.object(forKey: Keys.trackAnxiety) as? Bool ?? true
        trackPsychotic = store.bool(forKey: Keys.trackPsychotic)
        trackWeight = store.bool(forKey: Keys.trackWeight)
        trackTherapy = store.bool(forKey: Keys.trackTherapy)
        customPointNames = store.stringArray(forKey: Keys.customPointNames) ?? []
        behaviorTags = store.stringArray(forKey: Keys.behaviorTags) ?? Self.defaultBehaviorTags
        faceIDEnabled = store.object(forKey: Keys.faceIDEnabled) as? Bool ?? true
        blurInSwitcher = store.object(forKey: Keys.blurInSwitcher) as? Bool ?? true
        healthWriteEnabled = store.bool(forKey: Keys.healthWriteEnabled)
        cloudKitEnabled = store.bool(forKey: Keys.cloudKitEnabled)
        companionPhrases = store.object(forKey: Keys.companionPhrases) as? Bool ?? true
        aiEnabled = store.bool(forKey: Keys.aiEnabled)
        appearance = AppearanceMode(rawValue: store.string(forKey: Keys.appearance) ?? "") ?? .alwaysLight
        nightStartHour = store.object(forKey: Keys.nightStartHour) as? Int ?? 22
        if let data = store.data(forKey: Keys.alertRules),
           let rules = try? JSONDecoder().decode([AlertRule].self, from: data) {
            alertRules = rules
        } else {
            alertRules = []
        }
        latitude = store.object(forKey: Keys.latitude) as? Double
        longitude = store.object(forKey: Keys.longitude) as? Double
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-polarUITest") {
            faceIDEnabled = false
            blurInSwitcher = false
        }
        #endif
    }

    func save() {
        defaults.set(startHour, forKey: Keys.startHour)
        defaults.set(eveningReminderEnabled, forKey: Keys.eveningReminderEnabled)
        defaults.set(eveningHour, forKey: Keys.eveningHour)
        defaults.set(eveningMinute, forKey: Keys.eveningMinute)
        defaults.set(trackDepressed, forKey: Keys.trackDepressed)
        defaults.set(trackElevated, forKey: Keys.trackElevated)
        defaults.set(trackIrritability, forKey: Keys.trackIrritability)
        defaults.set(trackAnxiety, forKey: Keys.trackAnxiety)
        defaults.set(trackPsychotic, forKey: Keys.trackPsychotic)
        defaults.set(trackWeight, forKey: Keys.trackWeight)
        defaults.set(trackTherapy, forKey: Keys.trackTherapy)
        defaults.set(customPointNames, forKey: Keys.customPointNames)
        defaults.set(behaviorTags, forKey: Keys.behaviorTags)
        defaults.set(faceIDEnabled, forKey: Keys.faceIDEnabled)
        defaults.set(blurInSwitcher, forKey: Keys.blurInSwitcher)
        defaults.set(healthWriteEnabled, forKey: Keys.healthWriteEnabled)
        defaults.set(cloudKitEnabled, forKey: Keys.cloudKitEnabled)
        defaults.set(companionPhrases, forKey: Keys.companionPhrases)
        defaults.set(aiEnabled, forKey: Keys.aiEnabled)
        defaults.set(appearance.rawValue, forKey: Keys.appearance)
        defaults.set(nightStartHour, forKey: Keys.nightStartHour)
        if let data = try? JSONEncoder().encode(alertRules) {
            defaults.set(data, forKey: Keys.alertRules)
        }
        defaults.set(latitude, forKey: Keys.latitude)
        defaults.set(longitude, forKey: Keys.longitude)
    }

    var eveningDate: Date {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        parts.hour = eveningHour
        parts.minute = eveningMinute
        return Calendar.current.date(from: parts) ?? .now
    }

    func isPastEveningReminder(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour > eveningHour || (hour == eveningHour && minute >= eveningMinute)
    }

    func isNight(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard appearance == .automaticNight else { return false }
        let hour = calendar.component(.hour, from: date)
        if nightStartHour == startHour { return false }
        if nightStartHour > startHour {
            return hour >= nightStartHour || hour < startHour
        }
        return hour >= nightStartHour && hour < startHour
    }

    static let defaultBehaviorTags = [
        "S'isoler",
        "Appeler quelqu'un",
        "Rester au lit",
        "Sortir marcher",
        "Dépenser",
        "Écrans",
        "Travailler tard",
    ]

    private enum Keys {
        static let startHour = "startHour"
        static let eveningReminderEnabled = "eveningReminderEnabled"
        static let eveningHour = "eveningHour"
        static let eveningMinute = "eveningMinute"
        static let trackDepressed = "trackDepressed"
        static let trackElevated = "trackElevated"
        static let trackIrritability = "trackIrritability"
        static let trackAnxiety = "trackAnxiety"
        static let trackPsychotic = "trackPsychotic"
        static let trackWeight = "trackWeight"
        static let trackTherapy = "trackTherapy"
        static let customPointNames = "customPointNames"
        static let behaviorTags = "behaviorTags"
        static let faceIDEnabled = "faceIDEnabled"
        static let blurInSwitcher = "blurInSwitcher"
        static let healthWriteEnabled = "healthWriteEnabled"
        static let cloudKitEnabled = "cloudKitEnabled"
        static let companionPhrases = "companionPhrases"
        static let aiEnabled = "aiEnabled"
        static let appearance = "appearance"
        static let nightStartHour = "nightStartHour"
        static let alertRules = "alertRules"
        static let latitude = "latitude"
        static let longitude = "longitude"
    }
}
