//
//  Tracker.swift
//  Proovit
//
//  A single self-improvement category the user is documenting — Fitness,
//  Skincare, Hair Growth, or anything they create themselves.
//
//  Each tracker has many `ProgressEntry` rows (one per photo). Deleting
//  the tracker cascades to its entries; `PhotoStore` is responsible for
//  removing the on-disk files when those entries are deleted.
//

import Foundation
import SwiftData

@Model
final class Tracker {

    // 💡 Learn: `@Attribute(.unique)` adds a uniqueness constraint at the
    // SwiftData layer — duplicate inserts throw at save time.
    @Attribute(.unique) var id: UUID

    var name: String

    /// One of `Theme.trackerPalette[].assetName` — the source of truth for
    /// the dot color shown on Home and the tint used on Tracker Detail.
    var colorAssetName: String

    /// SF Symbol name (e.g. `"figure.run"`). Validated against
    /// `Theme.trackerSymbols` in the Edit Tracker sheet.
    var iconSymbolName: String

    /// Display order on the Home screen. Lower comes first.
    var sortOrder: Int

    var createdAt: Date

    // 💡 Learn: This relationship is owned by `Tracker`. The `inverse`
    // points to the matching property on `ProgressEntry`, and
    // `.cascade` tells SwiftData to delete the child entries when the
    // parent tracker is deleted. PhotoStore handles the file cleanup
    // when those entries' deletes fire.
    @Relationship(deleteRule: .cascade, inverse: \ProgressEntry.tracker)
    var entries: [ProgressEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        colorAssetName: String,
        iconSymbolName: String,
        sortOrder: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorAssetName = colorAssetName
        self.iconSymbolName = iconSymbolName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
