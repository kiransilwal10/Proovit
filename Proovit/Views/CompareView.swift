//
//  CompareView.swift
//  Proovit
//
//  The Compare tab. A segmented control switches between two modes:
//   - Side by Side: pick two dates within a tracker, view photos
//     next to each other with a Photos / Duration / Consistency
//     summary card. (Step 9 — built here.)
//   - Progress Reel: auto-generated timelapse video. (Step 12.)
//
//  The tracker chip row and the segmented control persist across both
//  modes; only the mode-specific content swaps.
//

import SwiftData
import SwiftUI

struct CompareView: View {

    enum Mode: String, Hashable, CaseIterable, Sendable {
        case sideBySide   = "Side by Side"
        case progressReel = "Progress Reel"
    }

    @Query(sort: \Tracker.sortOrder) private var trackers: [Tracker]

    @State private var mode: Mode = .sideBySide
    @State private var selectedTrackerID: UUID?
    @State private var leftDate: Date = .now
    @State private var rightDate: Date = .now
    @State private var pickingLeft: Bool = false
    @State private var pickingRight: Bool = false

    private let calendar: Calendar = .current

    private var selectedTracker: Tracker? {
        if let id = selectedTrackerID, let t = trackers.first(where: { $0.id == id }) {
            return t
        }
        return trackers.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                modePicker
                trackerChips

                switch mode {
                case .sideBySide:
                    sideBySideContent
                case .progressReel:
                    ProgressReelMode(
                        tracker: selectedTracker,
                        entries: selectedTracker?.entries ?? []
                    )
                }

                Color.clear.frame(height: Theme.Spacing.xl)
            }
            .padding(.top, Theme.Spacing.lg)
        }
        .background(Theme.background)
        // 💡 Learn: .onAppear fires before SwiftData's @Query has
        // populated `trackers`, so calling initializeIfNeeded() there
        // would see an empty array and never clamp dates to the
        // first tracker's range. .onChange(of:initial:) fires both on
        // first appearance AND once @Query lands data, so the dates
        // clamp correctly. The internal `if selectedTrackerID == nil`
        // guard prevents repeat re-clamps on later @Query refreshes.
        .onChange(of: trackers, initial: true) { _, _ in
            initializeIfNeeded()
        }
        .sheet(isPresented: $pickingLeft) {
            datePickerSheet(forLeft: true)
        }
        .sheet(isPresented: $pickingRight) {
            datePickerSheet(forLeft: false)
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("Compare")
            .font(.largeTitle.bold())
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, Theme.Spacing.lg)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(Mode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Tracker chips (single-select; "All" doesn't apply to Compare)

    private var trackerChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(trackers) { tracker in
                    chip(
                        label: tracker.name,
                        color: Theme.trackerColor(named: tracker.colorAssetName),
                        isSelected: selectedTrackerID == tracker.id
                    ) {
                        selectedTrackerID = tracker.id
                        clampDatesToTracker(tracker)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    private func chip(
        label: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(isSelected ? .white : color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.body.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : Theme.textPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Capsule().fill(isSelected ? Theme.accent : Theme.surface))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Side by Side content

    private var sideBySideContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.md) {
                dateCard(
                    label: "Day 1",
                    date: leftDate,
                    entry: leftEntry,
                    onTap: { pickingLeft = true }
                )
                dateCard(
                    label: "Day \(daysBetween + 1)",
                    date: rightDate,
                    entry: rightEntry,
                    onTap: { pickingRight = true }
                )
            }
            .padding(.horizontal, Theme.Spacing.lg)

            summaryCard
        }
    }

    private func dateCard(
        label: String,
        date: Date,
        entry: ProgressEntry?,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                .padding(Theme.Spacing.sm)

                ZStack {
                    if let entry {
                        PhotoThumbnailView(filename: entry.photoFilename)
                    } else {
                        ZStack {
                            Theme.background
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                // 💡 Learn: .aspectRatio(.fit) on the ZStack forces both
                // date cards to be the same square shape regardless of
                // the underlying photo's orientation. PhotoThumbnailView
                // handles its own .fill cropping internally.
                .aspectRatio(1, contentMode: .fit)
                .clipped()

                Text(formattedShortDate(date))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(Theme.Spacing.sm)
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
        .buttonStyle(.plain)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Summary")
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)

            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                summaryStat(value: "\(photoCount)", label: "Photos")
                summaryStat(value: durationText, label: "Duration")
                summaryStat(value: "\(Int((consistency * 100).rounded()))%", label: "Consistency")
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Date picker sheet

    private func datePickerSheet(forLeft: Bool) -> some View {
        NavigationStack {
            Group {
                if availableDates.isEmpty {
                    emptyDatesState
                } else {
                    List {
                        ForEach(availableDates, id: \.self) { date in
                            datePickerRow(date: date, forLeft: forLeft)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
                }
            }
            .navigationTitle("Choose date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if forLeft { pickingLeft = false } else { pickingRight = false }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func datePickerRow(date: Date, forLeft: Bool) -> some View {
        let isSelected = (forLeft && calendar.isDate(date, inSameDayAs: leftDate)) ||
                         (!forLeft && calendar.isDate(date, inSameDayAs: rightDate))
        return Button {
            if forLeft {
                leftDate = date
                pickingLeft = false
            } else {
                rightDate = date
                pickingRight = false
            }
        } label: {
            HStack {
                Text(formattedFullDate(date))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .listRowBackground(Theme.surface)
    }

    private var emptyDatesState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textTertiary)
            Text("No photos yet")
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("Capture a photo for this tracker first.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.Spacing.xl)
    }

    // MARK: - State helpers

    private func initializeIfNeeded() {
        if selectedTrackerID == nil, let first = trackers.first {
            selectedTrackerID = first.id
            clampDatesToTracker(first)
        }
    }

    /// Sets leftDate to the earliest entry and rightDate to the latest
    /// for the supplied tracker. If the tracker has no entries, dates
    /// stay at "now" (the cards will show empty placeholders).
    private func clampDatesToTracker(_ tracker: Tracker) {
        let dates = tracker.entries.map(\.capturedAt).sorted()
        if let earliest = dates.first { leftDate = earliest }
        if let latest = dates.last   { rightDate = latest }
    }

    // MARK: - Computed

    /// Sorted descending so the most recent dates appear first in the picker.
    private var availableDates: [Date] {
        guard let tracker = selectedTracker else { return [] }
        return Array(Set(tracker.entries.map { calendar.startOfDay(for: $0.capturedAt) }))
            .sorted(by: >)
    }

    /// First photo (any) on the requested day for the active tracker.
    /// We don't sort by time-of-day — for Compare, any photo on that
    /// day is representative.
    private var leftEntry: ProgressEntry? {
        entryOn(leftDate)
    }

    private var rightEntry: ProgressEntry? {
        entryOn(rightDate)
    }

    private func entryOn(_ date: Date) -> ProgressEntry? {
        guard let tracker = selectedTracker else { return nil }
        return tracker.entries.first {
            calendar.isDate($0.capturedAt, inSameDayAs: date)
        }
    }

    private var photoCount: Int {
        guard let tracker = selectedTracker else { return 0 }
        let lo = calendar.startOfDay(for: min(leftDate, rightDate))
        let hi = calendar.startOfDay(for: max(leftDate, rightDate))
        return tracker.entries.filter {
            let d = calendar.startOfDay(for: $0.capturedAt)
            return d >= lo && d <= hi
        }.count
    }

    /// Inclusive day count between the two dates. Always non-negative.
    private var daysBetween: Int {
        DateUtils.daysBetween(
            min(leftDate, rightDate),
            max(leftDate, rightDate),
            calendar: calendar
        )
    }

    private var durationText: String {
        let days = daysBetween + 1  // inclusive
        return "\(days) day\(days == 1 ? "" : "s")"
    }

    private var consistency: Double {
        guard selectedTracker != nil, daysBetween >= 0 else { return 0 }
        return StreakCalculator.consistency(
            photoDates: selectedTracker?.entries.map(\.capturedAt) ?? [],
            from: min(leftDate, rightDate),
            to: max(leftDate, rightDate),
            calendar: calendar
        )
    }

    // MARK: - Formatting

    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formattedFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(
            for: Tracker.self, ProgressEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    } catch {
        fatalError("Preview ModelContainer failed: \(error)")
    }

    let context = container.mainContext
    for tracker in SeedData.defaultTrackers() {
        context.insert(tracker)
    }

    return CompareView()
        .modelContainer(container)
}
