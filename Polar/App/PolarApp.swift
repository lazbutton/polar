import SwiftData
import SwiftUI
import UserNotifications

@main
struct PolarApp: App {
    @State private var preferences = Preferences.shared
    @State private var router = CaptureRouter.shared
    @State private var lock = AppLock()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private static let notifications = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = Self.notifications
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(preferences)
                .environment(router)
                .environment(lock)
                .background(Palette.background)
        }
        .modelContainer(SharedStore.container)
    }
}
