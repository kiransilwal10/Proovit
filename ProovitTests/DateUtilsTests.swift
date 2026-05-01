//
//  DateUtilsTests.swift
//  ProovitTests
//
//  Sanity checks for the calendar arithmetic helpers used by streak
//  math and the calendar grid.
//

import Foundation
import Testing
@testable import Proovit

struct DateUtilsTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        if let tz = TimeZone(identifier: "America/New_York") {
            cal.timeZone = tz
        }
        return cal
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        let components = DateComponents(
            calendar: calendar, year: year, month: month, day: day, hour: hour
        )
        return components.date ?? .distantPast
    }

    @Test func startOfDayReturnsMidnightInCalendarTimezone() {
        let afternoon = date(2026, 4, 15, hour: 14)
        let start = DateUtils.startOfDay(afternoon, calendar: calendar)
        let comps = calendar.dateComponents([.hour, .minute, .second], from: start)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    @Test func daysBetweenSameDayIsZero() {
        let morning = date(2026, 4, 15, hour: 5)
        let evening = date(2026, 4, 15, hour: 23)
        #expect(DateUtils.daysBetween(morning, evening, calendar: calendar) == 0)
    }

    @Test func daysBetweenAcrossWeekIsSeven() {
        #expect(DateUtils.daysBetween(
            date(2026, 4, 8),
            date(2026, 4, 15),
            calendar: calendar
        ) == 7)
    }

    @Test func daysBetweenIsSignedWhenReversed() {
        #expect(DateUtils.daysBetween(
            date(2026, 4, 15),
            date(2026, 4, 10),
            calendar: calendar
        ) == -5)
    }

    @Test func isSameDayHandlesDifferentTimesOfDay() {
        let morning = date(2026, 4, 15, hour: 6)
        let evening = date(2026, 4, 15, hour: 22)
        #expect(DateUtils.isSameDay(morning, evening, calendar: calendar))
    }

    @Test func isSameDayDistinguishesAdjacentDays() {
        let lateNight = date(2026, 4, 14, hour: 23)
        let earlyMorning = date(2026, 4, 15, hour: 1)
        #expect(!DateUtils.isSameDay(lateNight, earlyMorning, calendar: calendar))
    }
}
