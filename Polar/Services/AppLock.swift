import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLock {
    var isLocked = false
    /// Délai de grâce : Face ID seulement si l'app est restée en arrière-plan plus longtemps.
    var grace: TimeInterval = 300
    private var backgroundedAt: Date?
    private var evaluation: Task<Void, Never>?

    /// Note l'entrée en arrière-plan (le flou du sélecteur reste piloté à part, sans délai).
    func noteBackground() {
        backgroundedAt = .now
    }

    /// Vrai si le délai de grâce est dépassé au retour au premier plan.
    func shouldLockOnForeground() -> Bool {
        defer { backgroundedAt = nil }
        guard let backgroundedAt else { return false }
        return Date.now.timeIntervalSince(backgroundedAt) > grace
    }

    func lockIfNeeded(enabled: Bool) {
        guard enabled else {
            evaluation?.cancel()
            evaluation = nil
            isLocked = false
            return
        }
        guard evaluation == nil else { return }
        isLocked = true
    }

    func unlock() {
        guard isLocked, evaluation == nil else { return }
        evaluation = Task { await evaluate() }
    }

    private func evaluate() async {
        defer { evaluation = nil }
        let context = LAContext()
        context.localizedCancelTitle = "Plus tard"
        context.localizedFallbackTitle = "Code"

        var error: NSError?
        let faceID = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        guard faceID || context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isLocked = false
            return
        }

        let policy: LAPolicy = faceID ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: "Ouvrir Polar")
            guard !Task.isCancelled else { return }
            if success {
                isLocked = false
            } else {
                isLocked = true
            }
        } catch is CancellationError {
            return
        } catch let authError as LAError {
            guard !Task.isCancelled else { return }
            switch authError.code {
            case .userFallback, .biometryLockout:
                await evaluatePasscode()
            case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled:
                isLocked = false
            default:
                isLocked = true
            }
        } catch {
            guard !Task.isCancelled else { return }
            isLocked = true
        }
    }

    private func evaluatePasscode() async {
        let context = LAContext()
        context.localizedCancelTitle = "Plus tard"
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Ouvrir Polar")
            guard !Task.isCancelled else { return }
            isLocked = !success
        } catch let authError as LAError {
            guard !Task.isCancelled else { return }
            if authError.code == .passcodeNotSet {
                isLocked = false
            } else {
                isLocked = true
            }
        } catch {
            guard !Task.isCancelled else { return }
            isLocked = true
        }
    }
}
