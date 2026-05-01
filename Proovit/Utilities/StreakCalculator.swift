//
//  StreakCalculator.swift
//  Proovit
//
//  Pure streak math. No SwiftData, no UI — takes an array of capture
//  dates, returns numbers. That keeps it cheap to test and reuse from
//  any context (the home screen, the tracker detail screen, future
//  background widgets).
//
//  Strict rule (per PRD): missing any calendar day resets the streak
//  to 0. The current day is treated as "in progress" — if you logged
//  yesterday but not yet today, your streak is still alive.
//

import Foundation

nonisolated enum StreakCalculator {

    /// The current streak in days, given the dates a tracker has photo entries.
    ///
    /// Returns the number of consecutive calendar days ending at the most
    /// recent logged day. If the most recent logged day is more than 1 day
    /// before `referenceDate`, the streak is 0 (the user broke it by
    /// missing yesterday entirely).
    ///
    /// `referenceDate` defaults to "now" — pass an explicit value in tests
    /// for determinism.
    static func currentStreak(
        photoDates: [Date],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let logged = uniqueLoggedDays(photoDates: photoDates, calendar: calendar)
        guard let lastLogged = logged.last else { return 0 }

        let today = calendar.startOfDay(for: referenceDate)
        let daysSinceLast = calendar.dateComponents([.day], from: lastLogged, to: today).day ?? .max

        // Strict rule with one day of grace: if the user logged yesterday
        // but hasn't yet today, their streak is still alive. Two missed
        // days in a row resets to 0.
        guard daysSinceLast <= 1 else { return 0 }

        // Walk backwards from the most recent logged day, counting
        // consecutive days.
        var streak = 1
        var cursor = lastLogged
        for day in logged.dropLast().reversed() {
            let diff = calendar.dateComponents([.day], from: day, to: cursor).day ?? 0
            if diff == 1 {
                streak += 1
                cursor = day
            } else {
                break
            }
        }
        return streak
    }

    /// The longest streak that ever occurred in the photo history.
    /// Used for "Best Streak" on the Profile screen.
    static func bestStreak(
        photoDates: [Date],
        calendar: Calendar = .current
    ) -> Int {
        let logged = uniqueLoggedDays(photoDates: photoDates, calendar: calendar)
        guard !logged.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for i in 1 ..< logged.count {
            let diff = calendar.dateComponents([.day], from: logged[i - 1], to: logged[i]).day ?? 0
            if diff == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    /// Consistency over a date range: `loggedDays / totalDays`, in `[0, 1]`.
    /// Used for the "Consistency %" stat card on Tracker Detail and Compare.
    /// Both `start` and `end` are inclusive.
    static func consistency(
        photoDates: [Date],
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> Double {
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)
        guard normalizedStart <= normalizedEnd else { return 0 }

        let totalDays = (calendar.dateComponents([.day], from: normalizedStart, to: normalizedEnd).day ?? 0) + 1
        let loggedInRange = uniqueLoggedDays(photoDates: photoDates, calendar: calendar).filter {
            $0 >= normalizedStart && $0 <= normalizedEnd
        }.count
        return Double(loggedInRange) / Double(totalDays)
    }

    // MARK: - Private

    /// Reduces a list of capture timestamps to a sorted array of unique
    /// calendar days (each at midnight in the calendar's timezone).
    private static func uniqueLoggedDays(
        photoDates: [Date],
        calendar: Calendar
    ) -> [Date] {
        // 💡 Learn: `Set` deduplicates `Hashable` values. `Date` is `Hashable`
        // and equality compares the underlying time interval, so two
        // start-of-day dates for the same day collapse to one entry.
        let days = Set(photoDates.map { calendar.startOfDay(for: $0) })
        return days.sorted()
    }
}
