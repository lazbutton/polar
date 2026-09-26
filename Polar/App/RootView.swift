import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router
    @Environment(AppLock.self) private var lock
    @Query private var moments: [Moment]
    @Query private var medications: [Medication]
    @Query private var plans: [CarePlan]
    @Query private var safeties: [SafetyPlan]

    var body: some View {
        @Bindable var router = router
        tabs
            .tint(Palette.ink)
            .sheet(item: $router.fill) { fill in
                FillView(fill: fill)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $router.isPresenting) {
                PresentationView()
            }
            .overlay(alignment: .bottom) {
                ToastOverlay(center: ToastCenter.shared)
            }
            .overlay {
                if lock.isLocked {
                    lockScreen
                }
            }
            .overlay {
                if !preferences.didFinishOnboarding {
                    OnboardingView()
                }
            }
            .overlay {
                if scenePhase != .active, preferences.blurInSwitcher {
                    Palette.surface.ignoresSafeArea()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                lock.grace = preferences.graceDelay
                switch phase {
                case .active:
                    if preferences.faceIDEnabled, preferences.didFinishOnboarding {
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
            .onChange(of: ToastCenter.shared.message) { _, message in
                guard message != nil else { return }
                undoManager?.registerUndo(withTarget: ToastCenter.shared) { center in
                    MainActor.assumeIsolated { center.undo() }
                }
            }
            .task {
                lock.grace = preferences.graceDelay
                if preferences.faceIDEnabled, preferences.didFinishOnboarding {
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

    private var tabs: some View {
        @Bindable var router = router
        return TabView(selection: selection) {
            Tab("Aujourd'hui", systemImage: "sun.max", value: AppTab.today) {
                NavigationStack(path: $router.today) {
                    TodayView()
                        .navigationTitle("Aujourd'hui")
                        .toolbar(.hidden, for: .navigationBar)
                        .pages()
                }
            }
            Tab("Historique", systemImage: "calendar", value: AppTab.history) {
                NavigationStack(path: $router.history) {
                    HistoryView()
                        .pages()
                }
            }
            Tab("Mon plan", systemImage: "list.bullet.clipboard", value: AppTab.plan) {
                NavigationStack(path: $router.plan) {
                    PlanView()
                        .pages()
                }
            }
            Tab(value: AppTab.compose) {
                Color.clear
            } label: {
                Label("Noter", systemImage: "square.and.pencil")
                    .accessibilityLabel("Noter un moment")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.ink)
    }

    /// Noter ne devient jamais l'onglet actif : il ouvre un moment.
    private var selection: Binding<AppTab> {
        Binding(
            get: { router.tab },
            set: { tab in
                if tab == .compose {
                    if !lock.isLocked {
                        router.present(.moment(nil))
                    }
                } else {
                    router.tab = tab
                }
            }
        )
    }

    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "faceid")
                .font(.largeTitle)
                .foregroundStyle(Palette.ink)
            Text("Polar")
                .font(.largeTitle.weight(.semibold))
            callRow
            Button("Ouvrir") { lock.unlock() }
                .frame(minHeight: 56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }

    private var callRow: some View {
        let targets = LockCalls.targets(plan: plans.first, safety: safeties.first)
        return VStack(spacing: 8) {
            ForEach(targets, id: \.title) { target in
                if let url = URL(string: "tel:\(target.digits)") {
                    Link(destination: url) {
                        Text(target.title)
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Palette.surface, in: Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var scheme: ColorScheme? {
        switch preferences.appearance {
        case .alwaysLight: .light
        case .system: nil
        case .automaticNight: preferences.isNight() ? .dark : .light
        }
    }
}

enum LockCalls {
    struct Target: Hashable {
        var title: String
        var digits: String
    }

    static func targets(plan: CarePlan?, safety: SafetyPlan?) -> [Target] {
        let contacts = plan?.contacts ?? []
        func phone(_ ids: [UUID], role: ContactRole, fallback: [Contact]) -> String {
            let resolved = ids.compactMap { id in contacts.first { $0.id == id } }
            let pool = resolved.isEmpty ? fallback : resolved
            if let match = pool.first(where: { $0.role == role && !$0.digits.isEmpty }) ?? pool.first(where: { !$0.digits.isEmpty }) {
                return match.digits
            }
            if let named = contacts.first(where: { $0.role == role && !$0.digits.isEmpty }) {
                return named.digits
            }
            return ""
        }
        var targets: [Target] = []
        let person = phone(safety?.helperIDs ?? [], .trusted, safety?.helpers ?? [])
        let therapist = phone(safety?.professionalIDs ?? [], .therapist, safety?.professionals ?? [])
        if !person.isEmpty { targets.append(Target(title: "Ma personne", digits: person)) }
        if !therapist.isEmpty { targets.append(Target(title: "Ma psy", digits: therapist)) }
        targets.append(Target(title: "3114", digits: "3114"))
        targets.append(Target(title: "15", digits: "15"))
        return targets
    }
}

extension View {
    /// Les pages sont déclarées une fois et servent aux trois piles.
    func pages() -> some View {
        navigationDestination(for: Page.self) { page in
            PageView(page: page)
                .toolbar(.visible, for: .navigationBar)
                .toolbarBackground(Palette.background, for: .navigationBar)
        }
    }
}

struct PageView: View {
    let page: Page

    var body: some View {
        switch page {
        case .day(let date):
            DayPage(day: date)
        case .forPsy:
            ForPsyPage()
        case .settings:
            SettingsView()
        case .safetyPlan:
            SafetyPlanPage()
        case .pole(let pole, let stage):
            PolePage(pole: pole, focus: stage)
        case .toClassify:
            ToClassifyPage()
        case .medication(let id):
            MedicationPage(medicationID: id)
        case .labResults:
            LabResultsPage()
        case .resources:
            ResourcesPage()
        case .contact(let id):
            ContactPage(contactID: id)
        }
    }
}
