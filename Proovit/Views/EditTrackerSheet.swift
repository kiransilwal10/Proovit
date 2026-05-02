//
//  EditTrackerSheet.swift
//  Proovit
//
//  Modal sheet for creating, renaming, or deleting a tracker. Color
//  and SF Symbol come from the curated lists in Theme so Home stays
//  visually coherent.
//
//  Mode is determined by the `editing:` parameter:
//   - `nil`  → Add: creates a new Tracker on Save
//   - non-nil → Edit: mutates the supplied Tracker on Save; Delete
//                     wipes the tracker, its entries (cascade), and
//                     each entry's JPEG on disk (PhotoStore.delete)
//

import SwiftData
import SwiftUI

struct EditTrackerSheet: View {

    let editing: Tracker?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // 💡 Learn: We pull the existing trackers so we can compute the
    // sortOrder for a new one (max + 1). @Query reads from the same
    // context the sheet inserts into.
    @Query(sort: \Tracker.sortOrder) private var trackers: [Tracker]

    @State private var name: String
    @State private var colorAssetName: String
    @State private var iconSymbolName: String
    @State private var showingDeleteConfirm: Bool = false

    init(editing: Tracker? = nil) {
        self.editing = editing
        // 💡 Learn: Initializing @State in init requires the underscore
        // syntax. We pre-fill from `editing` if present so Edit mode
        // shows the current values; otherwise sensible defaults.
        _name = State(initialValue: editing?.name ?? "")
        _colorAssetName = State(
            initialValue: editing?.colorAssetName ?? Theme.trackerPalette.first?.assetName ?? "Forest"
        )
        _iconSymbolName = State(
            initialValue: editing?.iconSymbolName ?? Theme.trackerSymbols.first ?? "star.fill"
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    private var titleText: String {
        editing == nil ? "New tracker" : "Edit tracker"
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                colorSection
                iconSection
                if editing != nil {
                    deleteSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField("e.g. Reading, Meditation", text: $name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit {
                    if canSave { save() }
                }
        } header: {
            Text("NAME")
                .foregroundStyle(Theme.textSecondary)
        }
        .listRowBackground(Theme.surface)
    }

    private var colorSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(Theme.trackerPalette) { entry in
                        Button {
                            colorAssetName = entry.assetName
                        } label: {
                            colorSwatch(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        } header: {
            Text("COLOR")
                .foregroundStyle(Theme.textSecondary)
        }
        .listRowBackground(Theme.surface)
    }

    private func colorSwatch(_ entry: TrackerColor) -> some View {
        let isSelected = entry.assetName == colorAssetName
        return ZStack {
            Circle()
                .fill(entry.color)
                .frame(width: 36, height: 36)

            if isSelected {
                Circle()
                    .strokeBorder(Theme.textPrimary, lineWidth: 2)
                    .frame(width: 44, height: 44)
            }
        }
        .frame(width: 48, height: 48)
    }

    private var iconSection: some View {
        Section {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 60), spacing: Theme.Spacing.sm)],
                spacing: Theme.Spacing.sm
            ) {
                ForEach(Theme.trackerSymbols, id: \.self) { symbol in
                    Button {
                        iconSymbolName = symbol
                    } label: {
                        symbolCell(symbol)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        } header: {
            Text("ICON")
                .foregroundStyle(Theme.textSecondary)
        }
        .listRowBackground(Theme.surface)
    }

    private func symbolCell(_ symbol: String) -> some View {
        let isSelected = symbol == iconSymbolName
        let activeColor = Theme.trackerColor(named: colorAssetName)

        return Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(isSelected ? .white : Theme.textPrimary)
            .frame(width: 56, height: 56)
            .background(isSelected ? activeColor : Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete tracker")
                    Spacer()
                }
            }
        }
        .listRowBackground(Theme.surface)
        .confirmationDialog(
            "Delete \(editing?.name ?? "this tracker")?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteTracker()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes all photos for this tracker. This cannot be undone.")
        }
    }

    // MARK: - Save / Delete

    private func save() {
        guard canSave else { return }

        if let editing {
            editing.name = trimmedName
            editing.colorAssetName = colorAssetName
            editing.iconSymbolName = iconSymbolName
        } else {
            // Append to the end — preserves the user's existing ordering
            // and matches Home's first-insert-first-shown behavior.
            let nextSortOrder = (trackers.map(\.sortOrder).max() ?? -1) + 1
            let newTracker = Tracker(
                name: trimmedName,
                colorAssetName: colorAssetName,
                iconSymbolName: iconSymbolName,
                sortOrder: nextSortOrder
            )
            modelContext.insert(newTracker)
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteTracker() {
        guard let editing else { return }

        // 💡 Learn: We delete the photo files BEFORE the tracker. The
        // SwiftData cascade on Tracker.entries fires when the tracker
        // is deleted, removing the ProgressEntry rows — but it doesn't
        // know about the JPEGs on disk. We grab the filenames first,
        // then remove the files, then remove the tracker.
        if let store = try? PhotoStore() {
            for entry in editing.entries {
                try? store.delete(entry.photoFilename)
            }
        }

        modelContext.delete(editing)
        try? modelContext.save()
        dismiss()
    }
}

#Preview("Add") {
    EditTrackerSheet()
        .modelContainer(
            for: [Tracker.self, ProgressEntry.self, UserProfile.self],
            inMemory: true
        )
}
