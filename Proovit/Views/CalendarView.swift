//
//  CalendarView.swift
//  Proovit
//
//  Cross-tracker month calendar. Reuses the same `CalendarGridView` and
//  `DayPhotosSheet` Tracker Detail uses; the only new thing is the
//  filter-chip row at the top that scopes the visible logged days to a
//  single tracker (or "All" for the union across trackers).
//

import SwiftData
import SwiftUI

struct CalendarView: View {

    @Query(sort: \Tracker.sortOrder) private var trackers: [Tracker]
    @Query(sort: \ProgressEntry.capturedAt, order: .reverse) private var allEntries: [ProgressEntry]

    @State private var visibleMonth: Date = .now
    @State private var trackerFilter: UUID?  // nil = All
    @State private var presentedDay: PresentedDay?

    /// Wrapper because Date isn't Identifiable. `.sheet(item:)` needs
    /// an Identifiable handle.
    private struct PresentedDay: Identifiable {
        let date: Date
        var id: Date { date }
    }

    private let calendar: Calendar = .current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                filterChips
                calendarCard

                Color.clear.frame(height: Theme.Spacing.xl)
            }
            .padding(.top, Theme.Spacing.lg)
        }
        .background(Theme.background)
        .sheet(item: $presentedDay) { day in
            DayPhotosSheet(
                date: day.date,
                entries: entries(on: day.date)
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Calendar")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)

            Text(headerSubtitle)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var headerSubtitle: String {
        if let id = trackerFilter, let tracker = trackers.first(where: { $0.id == id }) {
            return "Filtered by \(tracker.name)"
        }
        return "All trackers"
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                chip(label: "All", color: nil, isSelected: trackerFilter == nil) {
                    trackerFilter = nil
                }
                ForEach(trackers) { tracker in
                    chip(
                        label: tracker.name,
                        color: Theme.trackerColor(named: tracker.colorAssetName),
                        isSelected: trackerFilter == tracker.id
                    ) {
                        trackerFilter = tracker.id
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    private func chip(
        label: String,
        color: Color?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let color {
                    Circle()
                        .fill(isSelected ? .white : color)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.body.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : Theme.textPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.accent : Theme.surface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Calendar card

    private var calendarCard: some View {
        CalendarGridView(
            visibleMonth: $visibleMonth,
            loggedDays: loggedDays,
            onDayTap: { date in
                if !entries(on: date).isEmpty {
                    presentedDay = PresentedDay(date: date)
                }
            }
        )
        .padding(Theme.Spacing.lg)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Filtering

    /// Entries scoped by the current `trackerFilter`. When the filter
    /// is nil ("All"), this is the full set.
    private var filteredEntries: [ProgressEntry] {
        if let filterID = trackerFilter {
            return allEntries.filter { $0.tracker?.id == filterID }
        }
        return allEntries
    }

    private var loggedDays: Set<Date> {
        Set(filteredEntries.map { calendar.startOfDay(for: $0.capturedAt) })
    }

    private func entries(on date: Date) -> [ProgressEntry] {
        filteredEntries
            .filter { calendar.isDate($0.capturedAt, inSameDayAs: date) }
            .sorted { $0.capturedAt > $1.capturedAt }
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

    return CalendarView()
        .modelContainer(container)
}
