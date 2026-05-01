//
//  ProgressEntry.swift
//  Proovit
//
//  One captured photo. SwiftData stores only the metadata — the JPEG
//  itself lives on disk and is referenced by `photoFilename`. See
//  `PhotoStore` for the read/write pipeline.
//

import Foundation
import SwiftData

@Model
final class ProgressEntry {

    @Attribute(.unique) var id: UUID

    /// Filename only — `PhotoStore.url(for:)` resolves it to a full URL.
    /// Storing just the filename means the data survives changes to the
    /// app's container path (which can shift across iOS versions).
    var photoFilename: String

    var capturedAt: Date

    // 💡 Learn: The relationship is optional because SwiftData briefly
    // sets it to `nil` during a cascade delete. Treat a `nil` tracker
    // as "this entry is on its way out" — never insert one with `nil`.
    var tracker: Tracker?

    init(
        id: UUID = UUID(),
        photoFilename: String,
        capturedAt: Date = .now,
        tracker: Tracker? = nil
    ) {
        self.id = id
        self.photoFilename = photoFilename
        self.capturedAt = capturedAt
        self.tracker = tracker
    }
}
