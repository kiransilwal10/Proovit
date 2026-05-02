//
//  DayPhotosSheet.swift
//  Proovit
//
//  Shows every photo a tracker has on a specific day. Tap a thumbnail
//  to open the full-screen viewer (defined inline at the bottom of the
//  file because it's small and tightly coupled to this flow).
//

import SwiftData
import SwiftUI
import UIKit

struct DayPhotosSheet: View {
    let date: Date
    let entries: [ProgressEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var presentedEntry: ProgressEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                if entries.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }
            }
            .background(Theme.background)
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(item: $presentedEntry) { entry in
                FullScreenPhotoView(entry: entry)
            }
        }
    }

    private var photoGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
            ],
            spacing: Theme.Spacing.sm
        ) {
            ForEach(entries) { entry in
                Button {
                    presentedEntry = entry
                } label: {
                    PhotoThumbnailView(filename: entry.photoFilename)
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.lg)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textTertiary)
            Text("No photos this day")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xxl)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

/// Tap-a-thumbnail full-screen viewer. Lives in this file because it's
/// only used here and its lifecycle is tied to DayPhotosSheet.
private struct FullScreenPhotoView: View {
    let entry: ProgressEntry

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()
                    closeButton
                }
                .padding(Theme.Spacing.lg)

                Spacer()

                if let trackerName = entry.tracker?.name {
                    trackerChip(name: trackerName)
                        .padding(.bottom, Theme.Spacing.xl)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await load()
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.black.opacity(0.4)))
        }
    }

    private func trackerChip(name: String) -> some View {
        Text(name)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Capsule().fill(.black.opacity(0.4)))
    }

    private func load() async {
        guard let store = try? PhotoStore() else { return }
        image = store.image(for: entry.photoFilename)
    }
}
