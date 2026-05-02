//
//  TrackerDetailView.swift
//  Proovit
//
//  One tracker's detail screen: header, three stat cards (streak, this
//  month, consistency), the month calendar grid, and the sticky
//  "Capture <name>" CTA at the bottom.
//
//  Three modal presentations:
//   - Edit / Delete: sheet with EditTrackerSheet(editing: tracker)
//   - Day Photos: sheet with DayPhotosSheet(date:, entries:)
//   - Camera: full-screen cover with CameraView(preselectedTrackerID:)
//

import SwiftData
import SwiftUI

struct TrackerDetailView: View {
    let tracker: Tracker

    @Environment(\.dismiss) private var dismiss

    @State private var visibleMonth: Date = .now
    @State private var presentedDay: PresentedDay?
    @State private var showingCamera: Bool = false
    @State private var showingEdit: Bool = false

    /// Wrapper because Date isn't Identifiable, and `.sheet(item:)` needs
    /// an Identifiable handle for the day-photos presentation.
    private struct PresentedDay: Identifiable {
        let date: Date
        var id: Date { date }
    }

    private let calendar: Calendar = .current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                headerSection
                statsRow
                calendarCard

                // Reserve room for the sticky CTA (added via safeAreaInset).
                Color.clear.frame(height: Theme.Spacing.xxl)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
                    .foregroundStyle(Theme.accent)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            captureCTA
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.background)
        }
        .sheet(isPresented: $showingEdit) {
            EditTrackerSheet(editing: tracker)
        }
        .sheet(item: $presentedDay) { day in
            DayPhotosSheet(
                date: day.date,
                entries: entries(on: day.date)
            )
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(preselectedTrackerID: tracker.id)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(Theme.trackerColor(named: tracker.colorAssetName))
                .frame(width: 12, height: 12)

            Text(tracker.name)
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - Stat cards

    private var statsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            statCard(value: "\(currentStreak)d", label: "Streak")
            statCard(value: "\(thisMonthCount)", label: "This month")
            statCard(value: "\(Int((consistency * 100).rounded()))%", label: "Consistency")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    // MARK: - Calendar

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
    }

    // MARK: - Capture CTA

    private var captureCTA: some View {
        Button {
            showingCamera = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "camera.fill")
                Text("Capture \(tracker.name)")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
    }

    // MARK: - Computed

    private var loggedDays: Set<Date> {
        Set(tracker.entries.map { calendar.startOfDay(for: $0.capturedAt) })
    }

    private func entries(on date: Date) -> [ProgressEntry] {
        tracker.entries
            .filter { calendar.isDate($0.capturedAt, inSameDayAs: date) }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(
            photoDates: tracker.entries.map(\.capturedAt),
            calendar: calendar
        )
    }

    private var thisMonthCount: Int {
        let monthStart = startOfMonth(visibleMonth)
        let monthEnd = endOfMonth(visibleMonth)
        return tracker.entries.filter {
            $0.capturedAt >= monthStart && $0.capturedAt <= monthEnd
        }.count
    }

    private var consistency: Double {
        StreakCalculator.consistency(
            photoDates: tracker.entries.map(\.capturedAt),
            from: startOfMonth(visibleMonth),
            to: endOfMonth(visibleMonth),
            calendar: calendar
        )
    }

    private func startOfMonth(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func endOfMonth(_ date: Date) -> Date {
        let start = startOfMonth(date)
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: start),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
            return start
        }
        return calendar.startOfDay(for: lastDay)
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
    let tracker = Tracker(
        name: "Fitness",
        colorAssetName: "Forest",
        iconSymbolName: "figure.run",
        sortOrder: 0
    )
    context.insert(tracker)

    return NavigationStack {
        TrackerDetailView(tracker: tracker)
    }
    .modelContainer(container)
}
