import UIKit

/// Actions rapides de l'icône (appui long) : Nouveau moment, Bilan du jour, Ça ne va pas.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        if let item = options.shortcutItem { QuickAction.handle(item) }
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickAction.handle(shortcutItem)
        completionHandler(true)
    }
}

@MainActor
enum QuickAction {
    static let moment = "moment"
    static let bilan = "bilan"
    static let aide = "aide"

    /// Enregistre les actions rapides dynamiquement (pas besoin d'Info.plist).
    static func install() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(type: moment, localizedTitle: "Nouveau moment", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "square.and.pencil")),
            UIApplicationShortcutItem(type: bilan, localizedTitle: "Bilan du jour", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "list.bullet.rectangle")),
            UIApplicationShortcutItem(type: aide, localizedTitle: "Ça ne va pas", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "heart.text.square")),
        ]
    }

    static func handle(_ item: UIApplicationShortcutItem) {
        switch item.type {
        case moment: CaptureRouter.shared.openCapture()
        case bilan: CaptureRouter.shared.openDayLog()
        case aide: CaptureRouter.shared.openSafetyPlan()
        default: break
        }
    }
}
