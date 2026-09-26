import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Preferences.self) private var preferences
    @Environment(CaptureRouter.self) private var router
    @Environment(AppLock.self) private var lock
    @Query private var moments: [Moment]
    @Query private var medications: [Medication]

    @State private var tab = HomeTab.today

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            tabs
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self) { route in
                    destination(route)
                        .toolbar(.visible, for: .navigationBar)
                        .toolbarBackground(Palette.background, for: .navigationBar)
                }
        }
        .tint(Palette.ink)
        .overlay(alignment: .bottom) {
            ToastOverlay(center: ToastCenter.shared)
        }
        .overlay(alignment: .bottomTrailing) {
            if !lock.isLocked, router.path.isEmpty, tab != .today {
                GlassPlusButton {
                    router.openCapture(voice: false)
                } longPress: {
                    router.openCapture(voice: true)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 72)
            }
        }
        .overlay {
            if lock.isLocked {
                lockScreen
            }
        }
        .overlay {
            if scenePhase != .active, preferences.blurInSwitcher {
                Palette.surface.ignoresSafeArea()
            }
        }
        .task(id: router.captureRequest) {
            await openPendingCapture()
        }
        .onChange(of: scenePhase) { _, phase in
            lock.grace = preferences.graceDelay
            switch phase {
            case .active:
                if preferences.faceIDEnabled {
                    if lock.shouldLockOnForeground() {
                        lock.lockIfNeeded(enabled: true)
                    }
                    lock.unlock()
                } else {
                    lock.lockIfNeeded(enabled: false)
                }
            case .background:
                lock.noteBackground()
            default:
                break
            }
        }
        .task {
            lock.grace = preferences.graceDelay
            if preferences.faceIDEnabled {
                lock.lockIfNeeded(enabled: true)
                if scenePhase == .active {
                    lock.unlock()
                }
            }
            context.undoManager = undoManager
            Migration.runIfNeeded(in: context)
            QuickAction.install()
            Reminders.registerCategories()
            WatchBridge.shared.activate()
            await HealthSync.catchUp(moments: moments, in: context)
            await Reminders.reschedule(medications: medications)
        }
        .preferredColorScheme(scheme)
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .moment(let id, let voice):
            CaptureSheet(momentID: id, voice: voice)
        case .day(let date):
            DayLogSheet(date: date)
        case .safetyPlan:
            SafetyPlanPage()
        case .settings:
            SettingsView()
        case .plan:
            CarePlanView()
        case .weeklyCheck:
            WeeklyCheckPage()
        case .session:
            SessionPage()
        case .medication(let id):
            MedicationForm(medicationID: id)
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Aujourd'hui", systemImage: "sun.max", value: HomeTab.today) { TodayView() }
            Tab("Calendrier", systemImage: "calendar", value: HomeTab.calendar) { MonthView() }
            Tab("Tendances", systemImage: "chart.xyaxis.line", value: HomeTab.trends) { TrendsView() }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.ink)
    }

    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "faceid")
                .font(.largeTitle)
                .foregroundStyle(Palette.ink)
            Text("Polar")
                .font(.largeTitle.weight(.semibold))
            Button("Ouvrir") { lock.unlock() }
                .frame(minHeight: 56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }

    private func openPendingCapture() async {
        guard let token = router.captureRequest else { return }
        let voice = router.captureVoice
        let moment = Moment(source: voice ? "voix" : "app")
        context.insert(moment)
        try? context.save()
        router.openMoment(moment.persistentModelID, voice: voice)
        if router.captureRequest == token {
            router.captureRequest = nil
        }
    }

    private var scheme: ColorScheme? {
        switch preferences.appearance {
        case .alwaysLight: .light
        case .system: nil
        case .automaticNight: preferences.isNight() ? .dark : .light
        }
    }
}

private enum HomeTab: Hashable {
    case today, calendar, trends
}
