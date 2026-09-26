import Foundation
import SwiftData

/// Une analyse, saisie telle quelle par le laboratoire (ex. lithémie). Sans interprétation.
@Model
final class LabResult {
    var date: Date = Date.now
    var name: String = ""       // ex. « Lithémie »
    var value: Double = 0
    var unit: String = ""       // telle qu'écrite par le laboratoire
    var note: String?

    init(name: String, value: Double, unit: String, date: Date = .now) {
        self.name = name
        self.value = value
        self.unit = unit
        self.date = date
    }
}
