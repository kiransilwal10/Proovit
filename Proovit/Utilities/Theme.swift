//
//  Theme.swift
//  Proovit
//
//  Single source of truth for design tokens — colors, spacing, radii, and curated
//  tracker palettes. See `DESIGN.md` for the rationale and approximate hex values.
//
//  All colors live in `Assets.xcassets`. Views must reference colors through this
//  enum, never `Color(red: ...)` and never raw `Color("Forest")` outside this file.
//

import SwiftUI

// 💡 Learn: `nonisolated` opts this enum out of the project's MainActor default
// (set via SWIFT_DEFAULT_ACTOR_ISOLATION). Theme is pure data and safe to read
// from any actor — views, background tasks, etc.
nonisolated enum Theme {

    // MARK: - Brand

    /// App and screen background — warm cream.
    static let background = Color("Background")

    /// Cards, sheets, list rows lifted off the background.
    static let surface = Color("Surface")

    /// Primary CTAs, FAB, today highlight, "Logged" indicator.
    static let accent = Color("Accent")

    /// Calendar logged-day fill, selection backgrounds. Derived from `accent` so
    /// changing the brand color updates this in one place.
    static let accentMuted = Color("Accent").opacity(0.12)

    // MARK: - Text

    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")

    // MARK: - Semantic

    static let success = Color("Accent")
    static let warning = Color("Amber")
    static let danger = Color("Danger")
    static let divider = Color("Divider")

    // MARK: - Tracker palette

    /// Curated tracker colors. `EditTrackerSheet` reads this list to render the picker.
    /// Order here is the order shown in the UI.
    static let trackerPalette: [TrackerColor] = [
        TrackerColor(displayName: "Forest", assetName: "Forest"),
        TrackerColor(displayName: "Lilac",  assetName: "Lilac"),
        TrackerColor(displayName: "Amber",  assetName: "Amber"),
        TrackerColor(displayName: "Coral",  assetName: "Coral"),
        TrackerColor(displayName: "Slate",  assetName: "Slate"),
        TrackerColor(displayName: "Plum",   assetName: "Plum"),
    ]

    /// Look up a `Color` by the `assetName` stored on a `Tracker`.
    /// Falls back to `accent` if the stored name isn't in the curated palette
    /// (e.g. a future palette change retired a color).
    static func trackerColor(named assetName: String) -> Color {
        if trackerPalette.contains(where: { $0.assetName == assetName }) {
            return Color(assetName)
        }
        return accent
    }

    // MARK: - Tracker SF Symbols

    /// Curated SF Symbol names for the icon picker in `EditTrackerSheet`.
    /// Keep this list short — too many choices makes the sheet feel cluttered.
    static let trackerSymbols: [String] = [
        "figure.run",
        "drop.fill",
        "scissors",
        "leaf.fill",
        "moon.stars.fill",
        "heart.fill",
        "books.vertical.fill",
        "paintpalette.fill",
        "music.note",
        "fork.knife",
        "pawprint.fill",
        "sparkles",
    ]

    // MARK: - Spacing

    /// All spacing values are multiples of 4. Don't introduce a new size without
    /// updating `DESIGN.md` first.
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner radius

    enum Radius {
        static let small:  CGFloat = 8
        static let medium: CGFloat = 14
        static let large:  CGFloat = 22
    }
}

/// A single entry in `Theme.trackerPalette`. The `assetName` is what we
/// persist on `Tracker.colorAssetName`; `displayName` is what users see.
struct TrackerColor: Identifiable, Hashable, Sendable {
    let displayName: String
    let assetName: String

    var id: String { assetName }

    /// The `Color` for this entry. Computed from `assetName` so we don't
    /// store a `Color` directly (which isn't `Hashable` cleanly).
    var color: Color { Color(assetName) }
}
