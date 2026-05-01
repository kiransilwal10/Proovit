//
//  TrackerRow.swift
//  Proovit
//
//  One row in any tracker list — Home today, Tracker Detail's parent
//  picker tomorrow. The row only renders; tapping is the caller's
//  responsibility (wrap it in a `Button`, or stick a NavigationLink
//  around it).
//

import SwiftUI

struct TrackerRow: View {
    let tracker: Tracker
    let streakDays: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Theme.trackerColor(named: tracker.colorAssetName))
                .frame(width: 10, height: 10)

            Image(systemName: tracker.iconSymbolName)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 24)

            Text(tracker.name)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)

            Spacer(minLength: Theme.Spacing.sm)

            // 💡 Learn: `.monospacedDigit()` keeps numerals in a fixed-width
            // glyph so "47d" and "9d" align on the right edge across rows.
            Text("\(streakDays)d")
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        // Make the whole row hit-testable, not just the text glyphs —
        // when the row is wrapped in a Button, the user can tap anywhere.
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 0) {
        TrackerRow(
            tracker: Tracker(name: "Fitness", colorAssetName: "Forest",
                             iconSymbolName: "figure.run", sortOrder: 0),
            streakDays: 47
        )
        Rectangle().fill(Theme.divider).frame(height: 1)
        TrackerRow(
            tracker: Tracker(name: "Skincare", colorAssetName: "Lilac",
                             iconSymbolName: "drop.fill", sortOrder: 1),
            streakDays: 9
        )
        Rectangle().fill(Theme.divider).frame(height: 1)
        TrackerRow(
            tracker: Tracker(name: "Hair Growth", colorAssetName: "Amber",
                             iconSymbolName: "scissors", sortOrder: 2),
            streakDays: 0
        )
    }
    .background(Theme.surface)
    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    .padding(Theme.Spacing.lg)
    .background(Theme.background)
}
