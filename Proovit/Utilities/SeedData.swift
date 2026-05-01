//
//  SeedData.swift
//  Proovit
//
//  Canonical first-launch trackers. Onboarding inserts these alongside
//  the new UserProfile so the app starts with content the user can
//  explore immediately. Names, colors, and icons are pinned by tests
//  to catch accidental drift.
//

import Foundation

enum SeedData {

    /// The three default trackers shown to a brand-new user. Order in the
    /// returned array matches the intended display order on Home.
    static func defaultTrackers() -> [Tracker] {
        [
            Tracker(
                name: "Fitness",
                colorAssetName: "Forest",
                iconSymbolName: "figure.run",
                sortOrder: 0
            ),
            Tracker(
                name: "Skincare",
                colorAssetName: "Lilac",
                iconSymbolName: "drop.fill",
                sortOrder: 1
            ),
            Tracker(
                name: "Hair Growth",
                colorAssetName: "Amber",
                iconSymbolName: "scissors",
                sortOrder: 2
            ),
        ]
    }
}
