import Foundation
import Observation
import SwiftData

enum AppTab: Hashable {
    case today, history, plan, compose
}

/// Écrans à consulter : ils s'empilent dans l'onglet courant, avec Retour.
enum Page: Hashable {
    case day(Date)
    case forPsy
    case settings
    case safetyPlan
    case pole(Pole, stage: Int?)
    case toClassify
    case medication(PersistentIdentifier)
    case labResults
    case resources
    case contact(UUID)
}

/// Écrans à remplir : ils montent par-dessus, avec Terminé. Une seule à la fois.
enum Fill: Hashable, Identifiable {
    case moment(PersistentIdentifier?)
    case dayLog(Date)
    case weekly
    case newMedication
    case newLabResult
    case newSignal
    case newContact

    var id: Self { self }
}

struct PsyBlock: Hashable, Identifiable {
    var title: String
    var lines: [String]
    var id: String { title }
}

@MainActor
@Observable
final class Router {
    static let shared = Router()

    var tab: AppTab = .today
    var today: [Page] = []
    var history: [Page] = []
    var plan: [Page] = []
    var fill: Fill?
    var isPresenting = false
    var slides: [PsyBlock] = []
    var captureVoice = false
    var pulseToken = 0

    /// Lien interne : la page s'ouvre sur place, Retour ramène d'où l'on vient.
    func push(_ page: Page) {
        let page = normalize(page)
        switch tab {
        case .today, .compose:
            append(page, to: &today)
        case .history:
            append(page, to: &history)
        case .plan:
            append(page, to: &plan)
        }
    }

    /// Écran à remplir, par-dessus l'onglet courant.
    func present(_ fill: Fill) {
        self.fill = normalize(fill)
    }

    /// Raccourci extérieur : la feuille s'ouvre sur Aujourd'hui, sans empiler une autre feuille.
    func presentFromOutside(_ fill: Fill) {
        self.fill = nil
        tab = .today
        today = []
        self.fill = normalize(fill)
    }

    /// Raccourci extérieur (Siri, icône, notification) : l'onglet où la page vit.
    func openFromOutside(_ page: Page) {
        fill = nil
        let page = normalize(page)
        switch page {
        case .safetyPlan, .pole, .toClassify, .medication, .labResults, .resources, .contact:
            tab = .plan
            plan = [page]
        case .day, .forPsy:
            tab = .history
            history = [page]
        case .settings:
            tab = .today
            today = [page]
        }
    }

    func openCapture(voice: Bool = false) {
        captureVoice = voice
        presentFromOutside(.moment(nil))
    }

    func openDayLog(on date: Date = .now) {
        presentFromOutside(.dayLog(date))
    }

    func openMoment(_ id: PersistentIdentifier, voice: Bool = false) {
        captureVoice = voice
        present(.moment(id))
    }

    func openSupport() {
        openFromOutside(.safetyPlan)
    }

    func openSafetyPlan() {
        openFromOutside(.safetyPlan)
    }

    func openWeeklyCheck() {
        present(.weekly)
    }

    func openSettings() {
        push(.settings)
    }

    func pulse() {
        pulseToken += 1
    }

    private func append(_ page: Page, to path: inout [Page]) {
        if path.last == page { return }
        path.append(page)
    }

    private func normalize(_ page: Page) -> Page {
        switch page {
        case .day(let date):
            return .day(date.logicalDay(startHour: Preferences.shared.startHour))
        default:
            return page
        }
    }

    private func normalize(_ fill: Fill) -> Fill {
        switch fill {
        case .dayLog(let date):
            return .dayLog(date.logicalDay(startHour: Preferences.shared.startHour))
        default:
            return fill
        }
    }
}

/// Ancien nom, le temps que les raccourcis externes parlent encore de capture.
typealias CaptureRouter = Router
