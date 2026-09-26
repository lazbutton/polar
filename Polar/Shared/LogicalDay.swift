import Foundation

extension Date {
    /// Jour de rattachement d'une note : avant l'heure de bascule, c'est encore la veille.
    /// Le décalage suit l'heure civile, pour que la bascule reste à l'heure choisie.
    func logicalDay(startHour: Int = 4, calendar: Calendar = .current) -> Date {
        let shifted = calendar.date(byAdding: .hour, value: -startHour, to: self) ?? self
        return calendar.startOfDay(for: shifted)
    }
}
