//
//  PhotoStore.swift
//  Proovit
//
//  Owns all reads and writes of progress photos on disk.
//
//  Why files instead of `Data` inside SwiftData: photos are large (up to
//  a few MB each), and stuffing them into the SwiftData store balloons
//  the database, slows queries, and complicates migrations. Files give
//  us a clean separation: SwiftData holds metadata, the file system
//  holds bytes. Views never touch `FileManager` directly — they always
//  go through this service.
//

import Foundation
import UIKit

// 💡 Learn: `nonisolated final class : Sendable` opts this service out
// of the project's MainActor default and allows it to cross actor
// boundaries safely. All stored state is an immutable `URL`, so the
// class is thread-safe by construction.
nonisolated final class PhotoStore: Sendable {

    enum PhotoStoreError: Error {
        case invalidImageData
    }

    private let directory: URL

    /// Creates a store rooted at `Application Support/Photos`. Tests
    /// pass a custom temp directory to avoid touching the real container.
    init(directory: URL? = nil) throws {
        if let directory {
            self.directory = directory
        } else {
            // 💡 Learn: `Application Support` is the right home for files
            // the app needs to function but the user shouldn't see in
            // Files.app — by contrast `Documents` is user-visible.
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.directory = appSupport.appending(path: "Photos", directoryHint: .isDirectory)
        }
        try FileManager.default.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true
        )
    }

    /// Saves JPEG data and returns the filename to store on `ProgressEntry.photoFilename`.
    /// The filename is a fresh UUID with a `.jpg` extension unless one is supplied.
    func save(_ data: Data, suggestedFilename: String? = nil) throws -> String {
        let filename = suggestedFilename ?? "\(UUID().uuidString).jpg"
        let fileURL = directory.appending(path: filename, directoryHint: .notDirectory)
        try data.write(to: fileURL, options: .atomic)
        return filename
    }

    /// Convenience that encodes a `UIImage` to JPEG and persists it.
    /// `quality` of 0.85 keeps file sizes ~1–2 MB for full-resolution photos
    /// without visible quality loss — adjust if profiling shows storage pain.
    func save(_ image: UIImage, quality: CGFloat = 0.85) throws -> String {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw PhotoStoreError.invalidImageData
        }
        return try save(data)
    }

    /// On-disk URL for a stored filename. Use with `Image(uiImage: …)` after
    /// loading via `image(for:)`, or pass to AVFoundation when composing the
    /// Progress Reel.
    func url(for filename: String) -> URL {
        directory.appending(path: filename, directoryHint: .notDirectory)
    }

    /// Raw bytes for a stored filename, or `nil` if the file is missing.
    func data(for filename: String) -> Data? {
        try? Data(contentsOf: url(for: filename))
    }

    /// Decoded image for a stored filename, or `nil` if missing/undecodable.
    func image(for filename: String) -> UIImage? {
        guard let data = data(for: filename) else { return nil }
        return UIImage(data: data)
    }

    /// Deletes a stored photo. Idempotent — calling with a missing filename
    /// is a no-op rather than an error, so cascading deletes from SwiftData
    /// don't fail just because a file was already cleaned up.
    func delete(_ filename: String) throws {
        let fileURL = url(for: filename)
        if FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
