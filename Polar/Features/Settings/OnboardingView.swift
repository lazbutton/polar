import SwiftUI

/// Deux écrans, puis Aujourd'hui. Face ID est un choix, les notifications arrivent avec l'heure du bilan.
struct OnboardingView: View {
    @Environment(Preferences.self) private var preferences
    @State private var step = 0
    @State private var faceID = false
    @State private var time = Calendar.current.date(bySettingHour: 21, minute: 30, second: 0, of: .now) ?? .now

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            if step == 0 {
                Text("Polar t'aide à noter ce que tu vis et à repérer tôt ce qui bouge. Il ne remplace pas ta psy.")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Face ID", isOn: $faceID)
                    .tint(Palette.ink)
                    .font(.headline)
                Button("Continuer") {
                    preferences.faceIDEnabled = faceID
                    preferences.save()
                    step = 1
                }
                .buttonStyle(PolarPrimaryButton())
            } else {
                Text("À quelle heure veux-tu faire ton bilan ?")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                DatePicker("Rappel du soir", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                Button("C'est parti") { finish() }
                    .buttonStyle(PolarPrimaryButton())
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }

    private func finish() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        preferences.eveningHour = parts.hour ?? 21
        preferences.eveningMinute = parts.minute ?? 30
        preferences.eveningReminderEnabled = true
        preferences.didFinishOnboarding = true
        preferences.save()
        Task {
            _ = await Reminders.requestAccess()
            await Reminders.reschedule(medications: [])
        }
    }
}

struct PolarPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Palette.background)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Palette.ink, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
