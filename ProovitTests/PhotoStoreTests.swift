//
//  PhotoStoreTests.swift
//  ProovitTests
//
//  These hit a real temp directory rather than mocking `FileManager` —
//  per CLAUDE.md, integration over mocks where the I/O is the point.
//

import Foundation
import Testing
import UIKit
@testable import Proovit

struct PhotoStoreTests {

    /// Creates a fresh `PhotoStore` rooted at a unique temp directory
    /// so concurrent tests don't collide.
    private func makeTempStore() throws -> (PhotoStore, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "PhotoStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = try PhotoStore(directory: tempDir)
        return (store, tempDir)
    }

    private func cleanUp(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test func saveDataReturnsFilenameAndWritesToDisk() throws {
        let (store, dir) = try makeTempStore()
        defer { cleanUp(dir) }

        // JPEG magic header — content doesn't have to decode for save() to work.
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let filename = try store.save(bytes)

        let path = store.url(for: filename).path(percentEncoded: false)
        #expect(FileManager.default.fileExists(atPath: path))
        #expect(filename.hasSuffix(".jpg"))
    }

    @Test func dataRoundTripReturnsOriginalBytes() throws {
        let (store, dir) = try makeTempStore()
        defer { cleanUp(dir) }

        let original = Data([1, 2, 3, 4, 5])
        let filename = try store.save(original)
        let loaded = store.data(for: filename)

        #expect(loaded == original)
    }

    @Test func dataForUnknownFilenameIsNil() throws {
        let (store, dir) = try makeTempStore()
        defer { cleanUp(dir) }

        #expect(store.data(for: "does-not-exist.jpg") == nil)
    }

    @Test func deleteRemovesFile() throws {
        let (store, dir) = try makeTempStore()
        defer { cleanUp(dir) }

        let filename = try store.save(Data([0]))
        try store.delete(filename)

        #expect(store.data(for: filename) == nil)
    }

    @Test func deleteIsIdempotent() throws {
        let (store, dir) = try makeTempStore()
        defer { cleanUp(dir) }

        // Should not throw — cascading deletes from SwiftData rely on this.
        try store.delete("never-saved.jpg")
    }

    @Test func saveWithSuggestedFilenameUsesIt() throws {
        let (store, dir) = try makeTempStore()
        defer { cleanUp(dir) }

        let filename = try store.save(Data([0]), suggestedFilename: "fixed.jpg")
        #expect(filename == "fixed.jpg")
        #expect(FileManager.default.fileExists(atPath: store.url(for: "fixed.jpg").path(percentEncoded: false)))
    }
}
