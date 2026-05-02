//
//  EditTrackerSheet.swift
//  Proovit
//
//  Modal sheet for creating a new tracker. The sheet picks color and
//  SF Symbol from the curated lists in Theme so the Home screen stays
//  visually coherent. Step 5 wires Add mode from Home; Step 7 will
//  extend this sheet (or its caller) to handle Edit + Delete from
//  Tracker Detail's toolbar.
//

import SwiftData
import SwiftUI

struct EditTrackerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // 💡 Learn: We pull the existing trackers so we can compute the
    // sortOrder for a new one (max + 1). @Query reads from the same
    // context the sheet inserts into.
    @Query(sort: \Tracker.sortOrder) private var trackers: [Tracker]

    @State private var name: String = ""
    @State private var colorAssetName: String = Theme.trackerPalette.first?.assetName ?? "Forest"
    @State private var iconSymbolName: String = Theme.trackerSymbols.first ?? "star.fill"

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                colorSection
                iconSection
            }
            // 💡 Learn: scrollContentBackground(.hidden) lets us replace
            // Form's grouped-gray background with our Theme.background.
            // Without this, the sheet would have iOS's default chrome.
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("New tracker")
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
                // 💡 Learn: strokeBorder draws inside the bounds (vs stroke
                // which centers on the path), keeping the selected swatch
                // exactly the same diameter as unselected ones.
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

    // MARK: - Save

    private func save() {
        guard canSave else { return }

        // Append to the end of the list — preserves the user's existing
        // ordering and matches Home's first-insert-first-shown behavior.
        let nextSortOrder = (trackers.map(\.sortOrder).max() ?? -1) + 1

        let newTracker = Tracker(
            name: trimmedName,
            colorAssetName: colorAssetName,
            iconSymbolName: iconSymbolName,
            sortOrder: nextSortOrder
        )
        modelContext.insert(newTracker)
        try? modelContext.save()

        dismiss()
    }
}

#Preview {
    EditTrackerSheet()
        .modelContainer(
            for: [Tracker.self, ProgressEntry.self, UserProfile.self],
            inMemory: true
        )
}
