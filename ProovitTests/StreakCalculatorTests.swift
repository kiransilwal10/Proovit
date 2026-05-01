//
//  StreakCalculatorTests.swift
//  ProovitTests
//
//  Verifies the strict streak rule (per PRD): missing any calendar day
//  resets the streak to 0, with one day of grace for "today not yet
//  logged".
//

import Foundation
import Testing
@testable import Proovit

struct StreakCalculatorTests {

    // 💡 Learn: We pin the calendar to a fixed timezone in tests. Without this,
    // a CI machine in UTC and a developer's laptop in CT would compute
    // different "calendar days" for the same Date and the tests would flake.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        if let tz = TimeZone(identifier: "America/New_York") {
            cal.timeZone = tz
        }
        return cal
    }()

    /// Constructs a deterministic Date at midday in the test calendar.
    /// Using midday avoids midnight-boundary surprises around DST shifts.
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(
            calendar: calendar, year: year, month: month, day: day, hour: 12
        )
        return components.date ?? .distantPast
    }

    // MARK: - currentStreak

    @Test func emptyHistoryGivesZeroStreak() {
        #expect(StreakCalculator.currentStreak(
            photoDates: [],
            referenceDate: date(2026, 4, 15),
            calendar: calendar
        ) == 0)
    }

    @Test func singlePhotoTodayGivesOneDayStreak() {
        let today = date(2026, 4, 15)
        #expect(StreakCalculator.currentStreak(
            photoDates: [today],
            referenceDate: today,
            calendar: calendar
        ) == 1)
    }

    @Test func threeConsecutiveDaysEndingTodayGivesThree() {
        let dates = [date(2026, 4, 13), date(2026, 4, 14), date(2026, 4, 15)]
        #expect(StreakCalculator.currentStreak(
            photoDates: dates,
            referenceDate: date(2026, 4, 15),
            calendar: calendar
        ) == 3)
    }

    @Test func gapInHistoryStopsAtMostRecentRun() {
        // Logged 4/10, 4/11, then a gap, then 4/13, 4/14, 4/15.
        // Current streak is 3 — the run ending today.
        let dates = [
            date(2026, 4, 10), date(2026, 4, 11),
            date(2026, 4, 13), date(2026, 4, 14), date(2026, 4, 15),
        ]
        #expect(StreakCalculator.currentStreak(
            photoDates: dates,
            referenceDate: date(2026, 4, 15),
            calendar: calendar
        ) == 3)
    }

    @Test func loggedYesterdayButNotTodayKeepsStreakAlive() {
        // Today is in progress — yesterday's streak is still counted.
        let dates = [date(2026, 4, 13), date(2026, 4, 14)]
        #expect(StreakCalculator.currentStreak(
            photoDates: dates,
            referenceDate: date(2026, 4, 15),
            calendar: calendar
        ) == 2)
    }

    @Test func missingTwoDaysInARowResetsToZero() {
        // Logged 4/13 — today is 4/15. Missed both 4/14 and 4/15. Streak broke.
        #expect(StreakCalculator.currentStreak(
            photoDates: [date(2026, 4, 13)],
            referenceDate: date(2026, 4, 15),
            calendar: calendar
        ) == 0)
    }

    @Test func multiplePhotosOnSameDayCountAsOneDay() {
        let dates = [date(2026, 4, 15), date(2026, 4, 15), date(2026, 4, 15)]
        #expect(StreakCalculator.currentStreak(
            photoDates: dates,
            referenceDate: date(2026, 4, 15),
            calendar: calendar
        ) == 1)
    }

    // MARK: - bestStreak

    @Test func bestStreakOnEmptyHistoryIsZero() {
        #expect(StreakCalculator.bestStreak(photoDates: [], calendar: calendar) == 0)
    }

    @Test func bestStreakReturnsLongestRun() {
        // 5-day run, gap, then 2-day run. Best is 5.
        let dates = [
            date(2026, 3, 1), date(2026, 3, 2), date(2026, 3, 3),
            date(2026, 3, 4), date(2026, 3, 5),
            date(2026, 3, 10), date(2026, 3, 11),
        ]
        #expect(StreakCalculator.bestStreak(photoDates: dates, calendar: calendar) == 5)
    }

    @Test func bestStreakWithSingleDayIsOne() {
        #expect(StreakCalculator.bestStreak(
            photoDates: [date(2026, 4, 15)],
            calendar: calendar
        ) == 1)
    }

    // MARK: - consistency

    @Test func consistencyOverFullyLoggedRangeIsOne() {
        let dates = (10...15).map { date(2026, 4, $0) }
        let consistency = StreakCalculator.consistency(
            photoDates: dates,
            from: date(2026, 4, 10),
            to: date(2026, 4, 15),
            calendar: calendar
        )
        #expect(consistency == 1.0)
    }

    @Test func consistencyOverHalfLoggedRangeIsHalf() {
        let dates = [date(2026, 4, 10), date(2026, 4, 12), date(2026, 4, 14)]
        let consistency = StreakCalculator.consistency(
            photoDates: dates,
            from: date(2026, 4, 10),
            to: date(2026, 4, 15),
            calendar: calendar
        )
        #expect(consistency == 0.5)
    }

    @Test func consistencyIgnoresPhotosOutsideRange() {
        let dates = [
            date(2026, 3, 1),                     // before range
            date(2026, 4, 11), date(2026, 4, 12), // inside
            date(2026, 5, 1),                     // after range
        ]
        let consistency = StreakCalculator.consistency(
            photoDates: dates,
            from: date(2026, 4, 10),
            to: date(2026, 4, 15),
            calendar: calendar
        )
        #expect(consistency == 2.0 / 6.0)
    }
}
