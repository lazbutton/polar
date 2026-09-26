import AppIntents

struct PolarShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickMomentIntent(),
            phrases: ["Noter une émotion dans \(.applicationName)"],
            shortTitle: "Noter une émotion",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenCaptureIntent(),
            phrases: ["Nouveau moment dans \(.applicationName)"],
            shortTitle: "Nouveau moment",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: SupportIntent(),
            phrases: ["Ça ne va pas dans \(.applicationName)"],
            shortTitle: "Ça ne va pas",
            systemImageName: "heart"
        )
    }
}
