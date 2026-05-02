//
//  CapturePreviewView.swift
//  Proovit
//
//  Confirms or discards a freshly-captured photo before persisting.
//  Save writes the JPEG to disk via PhotoStore and inserts the matching
//  ProgressEntry into SwiftData. Retake clears the bytes and lets
//  CameraView return to live preview.
//

import SwiftData
import SwiftUI
import UIKit

struct CapturePreviewView: View {
    let imageData: Data
    let tracker: Tracker
    let onRetake: () -> Void
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var isSaving: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 💡 Learn: SwiftUI doesn't have an Image(data:) initializer.
            // We construct a UIImage from the raw bytes and feed it to
            // Image(uiImage:). For bigger pipelines we'd cache the
            // decoded image — fine to do per-render here since this
            // view is short-lived.
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }

            VStack {
                trackerChip
                    .padding(.top, Theme.Spacing.lg)

                Spacer()

                actionRow
                    .padding(.bottom, Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .preferredColorScheme(.dark)
    }

    private var trackerChip: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(Theme.trackerColor(named: tracker.colorAssetName))
                .frame(width: 8, height: 8)
            Text(tracker.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Capsule().fill(.black.opacity(0.4)))
    }

    private var actionRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button {
                onRetake()
            } label: {
                Text("Retake")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(.black.opacity(0.4))
                    .clipShape(Capsule())
            }
            .disabled(isSaving)

            Button {
                Task { await save() }
            } label: {
                Text(isSaving ? "Saving…" : "Save")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .disabled(isSaving)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            // PhotoStore is `nonisolated` — cheap to construct here.
            // It just resolves a directory URL on init.
            let store = try PhotoStore()
            let filename = try store.save(imageData)

            let entry = ProgressEntry(
                photoFilename: filename,
                capturedAt: .now,
                tracker: tracker
            )
            modelContext.insert(entry)
            try modelContext.save()

            onSaved()
        } catch {
            // For Step 6 we silently no-op; v1.0 polish adds an error toast.
            // The captured Data is still in memory, so the user can retry
            // by tapping Save again.
        }
    }
}
