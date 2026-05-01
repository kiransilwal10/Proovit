//
//  DateUtils.swift
//  Proovit
//
//  Pure date helpers used by streak math, the calendar grid, and the
//  side-by-side comparison summary. Kept calendar-injectable so tests
//  can pin a fixed timezone and avoid flakes.
//

import Foundation

// 💡 Learn: `nonisolated` makes every member callable from any actor.
// Without it, this enum would inherit the project's MainActor default.
nonisolated enum DateUtils {

    /// The calendar day (year-month-day) the given moment falls in,
    /// normalized to 00:00 in the calendar's timezone.
    ///
    /// Two photos taken in the same day — even ones taken minutes apart
    /// across midnight in different time zones — group together for
    /// streak and calendar logic when reduced through this function.
    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Number of calendar days between two dates (signed).
    /// Returns `0` if `from` and `to` fall on the same day; positive if
    /// `to` is later; negative if `to` is earlier.
    static func daysBetween(
        _ from: Date,
        _ to: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        // 💡 Learn: dateComponents returns optionals because the request
        // can fail in exotic calendars (e.g. Hebrew leap months). Default
        // to 0 — every Gregorian path produces a value.
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// True if two moments fall on the same calendar day.
    static func isSameDay(
        _ a: Date,
        _ b: Date,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }
}
