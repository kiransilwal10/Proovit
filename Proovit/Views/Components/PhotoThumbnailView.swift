//
//  PhotoThumbnailView.swift
//  Proovit
//
//  Loads a stored photo by filename via PhotoStore and renders it.
//  Used by Home's recent-entries strip, the Day Photos sheet, and the
//  Compare screens later. Falls back to a "photo" SF Symbol while the
//  bytes are being read off disk.
//
//  Disk reads happen on @MainActor for now — JPEG thumbnails (~hundreds
//  of KB) decode fast enough that the frame drop is imperceptible. If
//  profiling shows pain, move the load into Task.detached and decode
//  the returned Data on main.
//

import SwiftUI
import UIKit

struct PhotoThumbnailView: View {
    let filename: String

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    // 💡 Learn: With .fill content mode, the image scales
                    // to cover the parent's frame in BOTH dimensions —
                    // which means it overflows in whichever dimension
                    // doesn't match the parent's aspect ratio. Without
                    // these two modifiers the overflow leaks past grid
                    // cell boundaries and the layout looks broken.
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ZStack {
                    Theme.surface
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        // 💡 Learn: task(id:) reruns when the id changes. Useful in
        // grids that reuse cells — when SwiftUI hands a recycled cell a
        // new filename, we cancel the previous load and start fresh.
        .task(id: filename) {
            await load()
        }
    }

    private func load() async {
        guard let store = try? PhotoStore() else { return }
        image = store.image(for: filename)
    }
}
