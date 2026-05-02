//
//  VideoComposer.swift
//  Proovit
//
//  Composes a tracker's photos into an MP4 timelapse with date overlays.
//
//  Pipeline per frame:
//   1. Load JPEG from PhotoStore as UIImage
//   2. Render onto a 1080×1080 canvas: black bg → aspect-fill photo →
//      bottom gradient → date text overlay
//   3. Convert that UIImage to a CVPixelBuffer
//   4. Append to AVAssetWriterInputPixelBufferAdaptor at the right
//      presentation time
//
//  Timing: each frame is held for `frameDuration` (0.5s by default).
//  A 30-photo reel is therefore ~15 seconds.
//

@preconcurrency import AVFoundation
import CoreVideo
import Foundation
import UIKit

nonisolated enum VideoComposer {

    enum ComposerError: LocalizedError {
        case noEntries
        case writerFailed
        case bufferAllocationFailed
        case appendFailed
        case imageLoadFailed

        var errorDescription: String? {
            switch self {
            case .noEntries:               return "No photos to compose."
            case .writerFailed:            return "Video encoder couldn't start."
            case .bufferAllocationFailed:  return "Couldn't allocate frame buffer."
            case .appendFailed:            return "Couldn't write a frame to the video."
            case .imageLoadFailed:         return "A photo couldn't be loaded from disk."
            }
        }
    }

    /// Square output. Picks for it: every photo crops cleanly regardless
    /// of source aspect ratio, the file is small enough to share over
    /// any channel, and most modern devices target square thumbnails.
    private static let outputSize: CGSize = CGSize(width: 1080, height: 1080)

    /// Each photo is held for this duration. Smaller value = quicker reel.
    /// 0.5s feels like a brisk slideshow without rushing the eye.
    private static let frameDuration: CMTime = CMTime(value: 1, timescale: 2)

    // MARK: - Entry point

    /// Renders the supplied entries into an MP4 in a temp directory.
    /// Returns the file URL — caller is responsible for sharing or
    /// cleaning up.
    static func compose(
        entries: [ProgressEntry],
        photoStore: PhotoStore
    ) async throws -> URL {

        let sortedEntries = entries.sorted { $0.capturedAt < $1.capturedAt }
        guard !sortedEntries.isEmpty else { throw ComposerError.noEntries }

        let outputURL = makeOutputURL()
        try? FileManager.default.removeItem(at: outputURL)

        // Build the writer + input + adaptor.
        let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  outputSize.width,
                AVVideoHeightKey: outputSize.height,
            ]
        )
        input.expectsMediaDataInRealTime = false

        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String:  outputSize.width,
            kCVPixelBufferHeightKey as String: outputSize.height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: pixelBufferAttrs
        )

        guard writer.canAdd(input) else { throw ComposerError.writerFailed }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? ComposerError.writerFailed
        }
        writer.startSession(atSourceTime: .zero)

        // Append each photo as one frame.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"

        for (index, entry) in sortedEntries.enumerated() {
            guard let image = photoStore.image(for: entry.photoFilename) else {
                throw ComposerError.imageLoadFailed
            }

            let dateText = dateFormatter.string(from: entry.capturedAt)
            let frame = renderFrame(image: image, dateText: dateText, size: outputSize)

            guard let pixelBuffer = makePixelBuffer(from: frame, size: outputSize) else {
                throw ComposerError.bufferAllocationFailed
            }

            // 💡 Learn: AVAssetWriterInput throttles us via this flag.
            // Polling with a short sleep keeps memory pressure low —
            // we don't decode 1000 photos and fight the writer's queue.
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(10))
            }

            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))

            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? ComposerError.appendFailed
            }
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw writer.error ?? ComposerError.writerFailed
        }
        return outputURL
    }

    // MARK: - Frame composition

    /// Renders one frame: black background, aspect-filled photo, bottom
    /// gradient for legibility, date text bottom-left.
    private static func renderFrame(image: UIImage, dateText: String, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Background
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Aspect-fill the photo (cover-mode, cropping if necessary).
            let scale = max(size.width / image.size.width,
                            size.height / image.size.height)
            let scaled = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            let origin = CGPoint(
                x: (size.width  - scaled.width)  / 2,
                y: (size.height - scaled.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: scaled))

            // Bottom gradient so the date text stays legible over light photos.
            drawBottomGradient(in: ctx.cgContext, size: size)

            // Date text (bottom-left).
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            let attributed = NSAttributedString(string: dateText, attributes: attrs)
            let textRect = CGRect(
                x: 32,
                y: size.height - 64,
                width: size.width - 64,
                height: 48
            )
            attributed.draw(in: textRect)
        }
    }

    private static func drawBottomGradient(in cg: CGContext, size: CGSize) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors: [CGColor] = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.6).cgColor,
        ]
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors as CFArray,
            locations: [0, 1]
        ) else { return }

        let rect = CGRect(
            x: 0,
            y: size.height * 0.55,
            width: size.width,
            height: size.height * 0.45
        )
        cg.saveGState()
        cg.clip(to: rect)
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: rect.minY),
            end:   CGPoint(x: 0, y: rect.maxY),
            options: []
        )
        cg.restoreGState()
    }

    // MARK: - Pixel buffer

    /// Bridges UIImage → CVPixelBuffer for AVAssetWriterInput.
    private static func makePixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String:        true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pb = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        let pixelData = CVPixelBufferGetBaseAddress(pb)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        guard let cg = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        // 💡 Learn: CV pixel buffers are top-down; CG draws bottom-up.
        // Without this flip, our frame would render upside down.
        cg.translateBy(x: 0, y: size.height)
        cg.scaleBy(x: 1, y: -1)

        UIGraphicsPushContext(cg)
        image.draw(in: CGRect(origin: .zero, size: size))
        UIGraphicsPopContext()

        return pb
    }

    // MARK: - URL

    private static func makeOutputURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(
                path: "proovit-reel-\(UUID().uuidString).mp4",
                directoryHint: .notDirectory
            )
    }
}
