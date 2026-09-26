import SwiftData
import SwiftUI

struct CalendarPane: View {
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router
    @Query(sort: \DayLog.day) private var logs: [DayLog]
    @Query private var moments: [Moment]

    @State private var month = Date.now
    @State private var yearMode = false

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = French.locale
        calendar.firstWeekday = 2
        return calendar
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button {
                        yearMode.toggle()
                    } label: {
                        Text(yearMode ? month.formatted(.dateTime.year().locale(French.locale)) : French.monthTitle(month))
                            .font(.title2.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Mois précédent")
                    Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .accessibilityLabel("Mois suivant")
                }
                .foregroundStyle(Palette.ink)

                if logs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tes journées apparaîtront ici.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.inkMuted)
                        Button("Faire le bilan") { router.present(.dayLog(.now)) }
                            .buttonStyle(PolarPrimaryButton())
                    }
                }

                if yearMode {
                    yearGrid
                } else {
                    weekdayHeader
                    monthGrid
                    HStack(spacing: 16) {
                        Text("▴ humeur haute")
                        Text("▾ humeur basse")
                    }
                    .font(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .accessibilityHidden(true)
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .gesture(
            MagnificationGesture().onEnded { value in
                if value < 0.85 { yearMode = true }
                if value > 1.15 { yearMode = false }
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                shift(value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        let ordered = Array(symbols[start...]) + Array(symbols[..<start])
        return HStack {
            ForEach(ordered, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(Palette.inkFaint)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var monthGrid: some View {
        let days = daysInMonth(month)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(days.indices, id: \.self) { index in
                if let day = days[index] {
                    dayButton(day)
                } else {
                    Color.clear.frame(height: 72)
                }
            }
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let logical = day.logicalDay(startHour: preferences.startHour, calendar: calendar)
        let log = log(on: day)
        return Button {
            router.push(.day(logical))
        } label: {
            DayCell(day: day, log: log, hasMoment: hasMoment(on: day))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessLabel(day: day, log: log))
        .contextMenu {
            Button("Ouvrir") { router.push(.day(logical)) }
            Button("Modifier le bilan") { router.present(.dayLog(logical)) }
        }
    }

    private func accessLabel(day: Date, log: DayLog?) -> String {
        var parts = [French.shortDay(day)]
        guard let log else { return parts.joined(separator: ", ") }
        if log.depressed > 0 { parts.append("humeur basse \(French.level(log.depressed).lowercased())") }
        if log.elevated > 0 { parts.append("humeur haute \(French.level(log.elevated).lowercased())") }
        return parts.joined(separator: ", ")
    }

    private var yearGrid: some View {
        let year = calendar.component(.year, from: month)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(1...12, id: \.self) { monthIndex in
                if let date = calendar.date(from: DateComponents(year: year, month: monthIndex, day: 1)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(date.formatted(.dateTime.month(.abbreviated).locale(French.locale)))
                            .font(.caption)
                            .foregroundStyle(Palette.inkMuted)
                        miniMonth(date)
                    }
                    .onTapGesture {
                        month = date
                        yearMode = false
                    }
                }
            }
        }
    }

    private func miniMonth(_ date: Date) -> some View {
        let days = daysInMonth(date)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
            ForEach(days.indices, id: \.self) { index in
                if let day = days[index], let log = log(on: day) {
                    VStack(spacing: 1) {
                        Rectangle().fill(Palette.elevated).frame(height: CGFloat(log.elevated) * 2)
                        Rectangle().fill(Palette.depressed).frame(height: CGFloat(log.depressed) * 2)
                    }
                    .frame(height: 14, alignment: .center)
                } else {
                    Color.clear.frame(height: 14)
                }
            }
        }
    }

    private func shift(_ value: Int) {
        if yearMode {
            month = calendar.date(byAdding: .year, value: value, to: month) ?? month
        } else {
            month = calendar.date(byAdding: .month, value: value, to: month) ?? month
        }
    }

    private func daysInMonth(_ date: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var days = Array<Date?>(repeating: nil, count: leading)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: first))
        }
        return days
    }

    private func log(on day: Date) -> DayLog? {
        let logical = day.logicalDay(startHour: preferences.startHour, calendar: calendar)
        return logs.first { calendar.isDate($0.day, inSameDayAs: logical) }
    }

    private func hasMoment(on day: Date) -> Bool {
        !Journal.moments(moments, on: day, startHour: preferences.startHour, calendar: calendar).isEmpty
    }
}

struct DayCell: View {
    var day: Date
    var log: DayLog?
    var hasMoment: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.caption)
                .foregroundStyle(Palette.ink)
            if let log {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Palette.elevated)
                        .frame(height: CGFloat(log.elevated) * 6)
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(height: 1)
                    Rectangle()
                        .fill(Palette.depressed)
                        .frame(height: CGFloat(log.depressed) * 6)
                }
                .frame(height: 36, alignment: .center)
                HStack(spacing: 3) {
                    if log.irritability >= 2 { Circle().fill(Palette.irritability).frame(width: 5, height: 5) }
                    if log.anxiety >= 2 { Circle().fill(Palette.anxiety).frame(width: 5, height: 5) }
                    if log.intakes?.contains(where: { !$0.taken }) == true {
                        Circle().fill(Palette.ink).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            } else {
                Spacer(minLength: 0)
                if hasMoment {
                    Circle().fill(Palette.inkFaint).frame(width: 4, height: 4)
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .top)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
