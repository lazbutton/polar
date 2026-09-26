import Foundation

enum Daylight {
    /// Durée entre le lever et le coucher, calcul local, sans service externe.
    static func duration(on day: Date, latitude: Double, longitude: Double, calendar: Calendar = .current) -> TimeInterval? {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: day) ?? 1
        let gamma = 2 * Double.pi / 365 * (Double(dayOfYear) - 1)
        let equationOfTime = 229.18 * (
            0.000075
                + 0.001868 * cos(gamma)
                - 0.032077 * sin(gamma)
                - 0.014615 * cos(2 * gamma)
                - 0.040849 * sin(2 * gamma)
        )
        let declination = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148 * sin(3 * gamma)
        let latitudeRadians = latitude * .pi / 180
        let zenith = 90.833 * .pi / 180
        let cosineHourAngle = cos(zenith) / (cos(latitudeRadians) * cos(declination)) - tan(latitudeRadians) * tan(declination)
        guard cosineHourAngle >= -1, cosineHourAngle <= 1 else { return nil }
        let hourAngle = acos(cosineHourAngle)
        let sunrise = 720 - 4 * (longitude + hourAngle * 180 / .pi) - equationOfTime
        let sunset = 720 - 4 * (longitude - hourAngle * 180 / .pi) - equationOfTime
        return (sunset - sunrise) * 60
    }

    static func label(for duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes / 60) h \(String(format: "%02d", minutes % 60))"
    }
}
