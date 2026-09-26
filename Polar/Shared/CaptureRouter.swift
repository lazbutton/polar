import Foundation
import Observation
import SwiftData

enum AppRoute: Hashable {
    case moment(PersistentIdentifier, voice: Bool)
    case day(Date)
    case safetyPlan
    case settings
    case plan
    case weeklyCheck
    case session
    case medication(PersistentIdentifier?)
}

@MainActor
@Observable
final class CaptureRouter {
    static let shared = CaptureRouter()

    var path: [AppRoute] = []
    var captureRequest: UUID?
    var captureVoice = false
    var pulseToken = 0

    func openCapture(voice: Bool = false) {
        captureVoice = voice
        captureRequest = UUID()
    }

    func openDayLog(on date: Date = .now) {
        push(.day(date))
    }

    func openMoment(_ id: PersistentIdentifier, voice: Bool = false) {
        push(.moment(id, voice: voice))
    }

    func openSupport() {
        push(.safetyPlan)
    }

    func openSafetyPlan() {
        push(.safetyPlan)
    }

    func openWeeklyCheck() {
        push(.weeklyCheck)
    }

    func openSession() {
        push(.session)
    }

    func openSettings() {
        push(.settings)
    }

    func openPlan() {
        push(.plan)
    }

    func openMedication(_ id: PersistentIdentifier?) {
        push(.medication(id))
    }

    func push(_ route: AppRoute) {
        if path.last == route { return }
        path.append(route)
    }

    func pulse() {
        pulseToken += 1
    }
}
