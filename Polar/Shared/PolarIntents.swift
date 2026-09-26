import AppIntents
import Foundation
import SwiftData

enum EmotionOption: String, AppEnum {
    case calme, joie, soulagement, anxiete, tristesse, colere, irritation, epuisement

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Émotion"
    static let caseDisplayRepresentations: [EmotionOption: DisplayRepresentation] = [
        .calme: "Calme",
        .joie: "Joie",
        .soulagement: "Soulagement",
        .anxiete: "Anxiété",
        .tristesse: "Tristesse",
        .colere: "Colère",
        .irritation: "Irritation",
        .epuisement: "Épuisement",
    ]
}

struct QuickMomentIntent: AppIntent {
    static let title: LocalizedStringResource = "Noter une émotion"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Émotion")
    var emotion: EmotionOption

    @Parameter(title: "Intensité", default: 5, inclusiveRange: (0, 10))
    var intensity: Int

    init() {}

    init(emotion: EmotionOption, intensity: Int = 5) {
        self.emotion = emotion
        self.intensity = intensity
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedStore.container.mainContext
        context.insert(Moment(emotionKey: emotion.rawValue, intensity: intensity, source: "siri"))
        try context.save()
        return .result(dialog: "C'est noté.")
    }
}

struct QuickEmotionIntent: AppIntent {
    static let title: LocalizedStringResource = "Noter une émotion seule"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Émotion")
    var emotion: EmotionOption

    init() {}

    init(emotion: EmotionOption) {
        self.emotion = emotion
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = SharedStore.container.mainContext
        context.insert(Moment(emotionKey: emotion.rawValue, intensity: nil, source: "widget"))
        try context.save()
        return .result()
    }
}

struct OpenCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Nouveau moment"
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult {
        CaptureRouter.shared.openCapture()
        return .result()
    }
}

struct SupportIntent: AppIntent {
    static let title: LocalizedStringResource = "Ça ne va pas"
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult {
        CaptureRouter.shared.openSupport()
        return .result()
    }
}

struct MarkIntakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Pris"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Traitement")
    var medicationName: String

    init() {}

    init(medicationName: String) {
        self.medicationName = medicationName
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedStore.container.mainContext
        let name = medicationName
        var descriptor = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.name == name && $0.isActive }
        )
        guard let medication = try context.fetch(descriptor).first else {
            return .result(dialog: "Traitement introuvable.")
        }
        let startHour = UserDefaults(suiteName: SharedStore.appGroupIdentifier)?.object(forKey: "startHour") as? Int ?? 4
        let log = try DayLog.findOrCreate(startHour: startHour, in: context)
        if let intake = log.intakes?.first(where: { $0.medication?.persistentModelID == medication.persistentModelID }) {
            intake.taken = true
            intake.at = .now
        } else {
            context.insert(MedIntake(medication: medication, dayLog: log, taken: true))
        }
        try context.save()
        return .result(dialog: "C'est noté.")
    }
}
