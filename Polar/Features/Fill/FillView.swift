import SwiftData
import SwiftUI

struct FillView: View {
    let fill: Fill
    @Environment(Router.self) private var router

    var body: some View {
        NavigationStack {
            switch fill {
            case .moment(let id):
                CaptureSheet(momentID: id, voice: router.captureVoice)
            case .dayLog(let day):
                DayLogSheet(date: day).modifier(DoneButton())
            case .weekly:
                WeeklyCheckPage().modifier(DoneButton())
            case .newMedication:
                MedicationForm()
            case .newLabResult:
                LabResultForm()
            case .newSignal:
                SignalForm()
            case .newContact:
                ContactForm()
            }
        }
        .tint(Palette.ink)
    }
}

/// Terminé ferme la feuille : tout est déjà enregistré.
struct DoneButton: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") { dismiss() }
            }
        }
    }
}
