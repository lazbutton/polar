import Foundation
import UserNotifications

enum ReminderKind {
    static let evening = "EVENING"
    static let medication = "MEDICATION"
    static let takenAction = "PRIS"
}

enum Reminders {
    static func requestAccess() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        registerCategories()
        return granted ?? false
    }

    static func registerCategories() {
        let taken = UNNotificationAction(
            identifier: ReminderKind.takenAction,
            title: "Pris",
            options: [.authenticationRequired]
        )
        let medication = UNNotificationCategory(
            identifier: ReminderKind.medication,
            actions: [taken],
            intentIdentifiers: [],
            options: []
        )
        let evening = UNNotificationCategory(
            identifier: ReminderKind.evening,
            actions: [],
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
        if preferences.eveningReminderEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Polar"
            content.body = "Deux minutes pour ta journée ?"
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
            content.title = medication.name
            content.body = medication.dose.isEmpty ? "C'est l'heure." : medication.dose
            content.categoryIdentifier = ReminderKind.medication
            content.userInfo = ["medication": medication.name]
            var components = calendar.dateComponents([.hour, .minute], from: reminder)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "polar.med.\(medication.persistentModelID.hashValue)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let category = response.notification.request.content.categoryIdentifier
        if response.actionIdentifier == ReminderKind.takenAction {
            let name = response.notification.request.content.userInfo["medication"] as? String ?? ""
            let intent = MarkIntakeIntent(medicationName: name)
            _ = try? await intent.perform()
            return
        }
        if category == ReminderKind.evening {
            await MainActor.run {
                CaptureRouter.shared.openDayLog()
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
