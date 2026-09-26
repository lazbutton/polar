import Foundation
import SwiftData
import UserNotifications

enum ReminderKind {
    static let evening = "EVENING"
    static let medication = "MEDICATION"
    static let takenAction = "PRIS"
    static let snoozeAction = "SNOOZE30"
    static let skipAction = "SKIP"
    static let openDayLogAction = "OPEN_BILAN"
    static let noteAction = "NOTE_INPUT"
}

enum Reminders {
    static func requestAccess() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        registerCategories()
        return granted ?? false
    }

    static func registerCategories() {
        let taken = UNNotificationAction(identifier: ReminderKind.takenAction, title: "Pris", options: [.authenticationRequired])
        let snooze = UNNotificationAction(identifier: ReminderKind.snoozeAction, title: "Dans 30 min", options: [])
        let skip = UNNotificationAction(identifier: ReminderKind.skipAction, title: "Pas aujourd'hui", options: [])
        let medication = UNNotificationCategory(
            identifier: ReminderKind.medication,
            actions: [taken, snooze, skip],
            intentIdentifiers: [],
            options: []
        )
        let openBilan = UNNotificationAction(identifier: ReminderKind.openDayLogAction, title: "Ouvrir le bilan", options: [.foreground])
        let note = UNTextInputNotificationAction(
            identifier: ReminderKind.noteAction,
            title: "Un mot sur ma journée",
            options: [.authenticationRequired],
            textInputButtonTitle: "Enregistrer",
            textInputPlaceholder: "Un mot sur ta journée"
        )
        let evening = UNNotificationCategory(
            identifier: ReminderKind.evening,
            actions: [openBilan, note],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([medication, evening])
    }

    @MainActor
    static func reschedule(medications: [Medication]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix("polar.") }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        registerCategories()

        let preferences = Preferences.shared
        // En pause, on ne programme aucun rappel.
        guard !preferences.isPaused() else { return }

        let neutral = preferences.neutralNotifications
        if preferences.eveningReminderEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Polar"
            content.body = neutral ? "Rappel" : "Deux minutes pour ta journée ?"
            content.categoryIdentifier = ReminderKind.evening
            var components = DateComponents()
            components.hour = preferences.eveningHour
            components.minute = preferences.eveningMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "polar.evening", content: content, trigger: trigger)
            try? await center.add(request)
        }

        let calendar = Calendar.current
        for medication in medications where medication.isActive {
            guard let reminder = medication.reminder else { continue }
            let content = UNMutableNotificationContent()
            content.title = neutral ? "Polar" : medication.name
            content.body = neutral ? "Rappel" : (medication.dose.isEmpty ? "C'est l'heure." : medication.dose)
            content.categoryIdentifier = ReminderKind.medication
            content.userInfo = ["medication": medication.name]
            let components = calendar.dateComponents([.hour, .minute], from: reminder)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "polar.med.\(medication.persistentModelID.hashValue)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Reprogramme une prise dans 30 minutes (rappel unique).
    static func snooze(medicationName: String) async {
        let content = UNMutableNotificationContent()
        let neutral = await MainActor.run { Preferences.shared.neutralNotifications }
        content.title = neutral ? "Polar" : medicationName
        content.body = neutral ? "Rappel" : "C'est l'heure."
        content.categoryIdentifier = ReminderKind.medication
        content.userInfo = ["medication": medicationName]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "polar.med.snooze.\(UUID().uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let category = response.notification.request.content.categoryIdentifier
        let name = response.notification.request.content.userInfo["medication"] as? String ?? ""

        switch response.actionIdentifier {
        case ReminderKind.takenAction:
            _ = try? await MarkIntakeIntent(medicationName: name).perform()
            return
        case ReminderKind.snoozeAction:
            await Reminders.snooze(medicationName: name)
            return
        case ReminderKind.skipAction:
            await recordSkip(medicationName: name)
            return
        case ReminderKind.noteAction:
            if let text = (response as? UNTextInputNotificationResponse)?.userText, !text.isEmpty {
                await recordDayNote(text)
            }
            return
        default:
            break
        }

        if category == ReminderKind.evening {
            await MainActor.run { CaptureRouter.shared.openDayLog() }
        }
    }

    @MainActor
    private func recordSkip(medicationName: String) async {
        let context = SharedStore.container.mainContext
        let descriptor = FetchDescriptor<Medication>(predicate: #Predicate { $0.name == medicationName && $0.isActive })
        guard let medication = try? context.fetch(descriptor).first else { return }
        let startHour = UserDefaults(suiteName: SharedStore.appGroupIdentifier)?.object(forKey: "startHour") as? Int ?? 4
        guard let log = try? DayLog.findOrCreate(startHour: startHour, in: context) else { return }
        if let intake = log.intakes?.first(where: { $0.medication?.persistentModelID == medication.persistentModelID }) {
            intake.taken = false
        } else {
            context.insert(MedIntake(medication: medication, dayLog: log, taken: false))
        }
        try? context.save()
    }

    @MainActor
    private func recordDayNote(_ text: String) async {
        let context = SharedStore.container.mainContext
        let startHour = UserDefaults(suiteName: SharedStore.appGroupIdentifier)?.object(forKey: "startHour") as? Int ?? 4
        guard let log = try? DayLog.findOrCreate(startHour: startHour, in: context) else { return }
        log.note = [log.note, text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        try? context.save()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
