//
//  CalendarGridView.swift
//  Proovit
//
//  Month calendar grid. Each cell shows the day number; cells for days
//  the user logged a photo are filled with `Theme.accentMuted`; today
//  is filled with solid `Theme.accent`. Tapping a cell calls back —
//  the parent decides whether to open the Day Photos sheet.
//

import SwiftUI

struct CalendarGridView: View {

    @Binding var visibleMonth: Date
    let loggedDays: Set<Date>
    let onDayTap: (Date) -> Void

    private let calendar: Calendar = .current

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            monthHeader
            dayOfWeekRow
            daysGrid
        }
    }

    // MARK: - Header with prev/next

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 32, height: 32)
            }

            Spacer()

            Text(monthYearText)
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 32, height: 32)
            }
        }
    }

    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleMonth)
    }

    private func shiftMonth(by months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: visibleMonth) {
            visibleMonth = next
        }
    }

    // MARK: - Day-of-week header row

    private var dayOfWeekRow: some View {
        HStack(spacing: 4) {
            // 💡 Learn: Single-letter weekday symbols repeat (S/T appear
            // twice), so id: \.self triggers SwiftUI's "duplicate ID"
            // runtime warning. Iterating with the index as id avoids it.
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Single-letter weekday labels ("S","M","T","W","T","F","S"),
    /// rotated to start at the user's first weekday (Sunday in the US,
    /// Monday in much of Europe).
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        let firstWeekday = calendar.firstWeekday
        let offset = firstWeekday - 1
        guard offset > 0, symbols.count == 7 else { return symbols }
        return Array(symbols[offset..<symbols.count]) + Array(symbols[0..<offset])
    }

    // MARK: - Day grid

    private var daysGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 4) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(date: day)
                } else {
                    Color.clear.frame(height: 36)
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    /// Days of the visible month, padded with `nil` at the start (to
    /// align the first day to its weekday column) and at the end (to
    /// finish the last week).
    private var monthDays: [Date?] {
        let components = calendar.dateComponents([.year, .month], from: visibleMonth)
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: visibleMonth) else {
            return []
        }

        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)
        var startPad = weekdayOfFirst - calendar.firstWeekday
        if startPad < 0 { startPad += 7 }

        var result: [Date?] = Array(repeating: nil, count: startPad)

        for dayOffset in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) {
                result.append(date)
            }
        }

        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }

    private func dayCell(date: Date) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let isLogged = loggedDays.contains(calendar.startOfDay(for: date))
        let isToday = calendar.isDateInToday(date)

        return Button {
            onDayTap(date)
        } label: {
            ZStack {
                cellBackground(isLogged: isLogged, isToday: isToday)
                Text("\(dayNumber)")
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(cellForeground(isLogged: isLogged, isToday: isToday))
            }
            .frame(height: 36)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func cellBackground(isLogged: Bool, isToday: Bool) -> some View {
        if isToday {
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(Theme.accent)
        } else if isLogged {
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(Theme.accentMuted)
        } else {
            Color.clear
        }
    }

    private func cellForeground(isLogged: Bool, isToday: Bool) -> Color {
        if isToday { return .white }
        if isLogged { return Theme.textPrimary }
        return Theme.textTertiary
    }
}

#Preview {
    @Previewable @State var month = Date()
    let today = Calendar.current.startOfDay(for: Date())
    let logged: Set<Date> = [
        Calendar.current.date(byAdding: .day, value: -1, to: today),
        Calendar.current.date(byAdding: .day, value: -2, to: today),
        Calendar.current.date(byAdding: .day, value: -5, to: today),
    ].compactMap { $0 }.reduce(into: Set()) { $0.insert($1) }

    return CalendarGridView(
        visibleMonth: $month,
        loggedDays: logged,
        onDayTap: { _ in }
    )
    .padding()
    .background(Theme.surface)
    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    .padding()
    .background(Theme.background)
}
