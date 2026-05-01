//
//  SeedDataTests.swift
//  ProovitTests
//
//  Pins the default tracker set so an accidental edit (renaming
//  "Hair Growth", removing the Lilac swatch from the palette, etc.)
//  fails loudly here instead of confusing first-launch users.
//

import Foundation
import Testing
@testable import Proovit

// 💡 Learn: @MainActor on the test struct runs every test on the main
// actor. We need this because @Model classes (Tracker) inherit the
// project's MainActor default, so constructing them off-main-actor
// would be a Swift 6 isolation error.
@MainActor
struct SeedDataTests {

    @Test func defaultTrackersReturnsThree() {
        #expect(SeedData.defaultTrackers().count == 3)
    }

    @Test func defaultTrackersHaveExpectedNamesInOrder() {
        let names = SeedData.defaultTrackers().map(\.name)
        #expect(names == ["Fitness", "Skincare", "Hair Growth"])
    }

    @Test func defaultTrackersUseSortOrderZeroOneTwo() {
        let sortOrders = SeedData.defaultTrackers().map(\.sortOrder)
        #expect(sortOrders == [0, 1, 2])
    }

    @Test func defaultTrackerColorsAreInThemePalette() {
        let paletteAssetNames = Set(Theme.trackerPalette.map(\.assetName))
        for tracker in SeedData.defaultTrackers() {
            #expect(
                paletteAssetNames.contains(tracker.colorAssetName),
                "Default tracker '\(tracker.name)' uses color '\(tracker.colorAssetName)' which is not in Theme.trackerPalette"
            )
        }
    }

    @Test func defaultTrackerSymbolsAreInThemeSymbolList() {
        let knownSymbols = Set(Theme.trackerSymbols)
        for tracker in SeedData.defaultTrackers() {
            #expect(
                knownSymbols.contains(tracker.iconSymbolName),
                "Default tracker '\(tracker.name)' uses symbol '\(tracker.iconSymbolName)' which is not in Theme.trackerSymbols"
            )
        }
    }
}
