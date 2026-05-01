//
//  HomeView.swift
//  Proovit
//
//  The first thing the user sees after onboarding. Glance at all
//  trackers, see recent photos, and (in later steps) jump into capture
//  via the FAB or into a tracker via a row tap.
//
//  Step 3 ships read-only: rows render but don't navigate, "+ Add new
//  category" is not present yet (sheet wires up in Step 5), and the
//  recent-entries strip falls back to an empty state because no photos
//  have been captured yet.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    let profile: UserProfile

    // 💡 Learn: @Query is a SwiftData-aware @State equivalent that reads
    // from the model context. Sort/filter happen at the store level —
    // we don't need to re-sort in code.
    @Query(sort: \Tracker.sortOrder)
    private var trackers: [Tracker]

    @Query(sort: \ProgressEntry.capturedAt, order: .reverse)
    private var recentEntries: [ProgressEntry]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                trackersSection
                recentEntriesSection

                // Bottom padding so the last content isn't flush against
                // the safe-area edge on phones without home buttons.
                Color.clear.frame(height: Theme.Spacing.xxl)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Home")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.textPrimary)

                Text("Small steps compound. Capture today's version of yourself.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Spacing.sm)

            AvatarView(initials: profile.initials, size: 36)
                .padding(.top, Theme.Spacing.xs)
        }
    }

    // MARK: - Trackers section

    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("TRACKERS")

            VStack(spacing: 0) {
                ForEach(Array(trackers.enumerated()), id: \.element.id) { index, tracker in
                    TrackerRow(
                        tracker: tracker,
                        streakDays: streak(for: tracker)
                    )
                    if index < trackers.count - 1 {
                        Rectangle()
                            .fill(Theme.divider)
                            .frame(height: 1)
                    }
                }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
    }

    /// Today's streak for one tracker. Pulls capture dates from the
    /// SwiftData relationship and feeds them to the pure `StreakCalculator`.
    private func streak(for tracker: Tracker) -> Int {
        let dates = tracker.entries.map(\.capturedAt)
        return StreakCalculator.currentStreak(photoDates: dates)
    }

    // MARK: - Recent entries section

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("RECENT ENTRIES")

            if recentEntries.isEmpty {
                emptyRecentEntries
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.md) {
                        ForEach(recentEntries.prefix(10)) { entry in
                            RecentEntryThumbnail(entry: entry)
                        }
                    }
                }
            }
        }
    }

    private var emptyRecentEntries: some View {
        Text("No photos yet. Open a tracker to capture your first.")
            .font(.body)
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Spacing.lg)
            .padding(.horizontal, Theme.Spacing.md)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .tracking(1)
            .foregroundStyle(Theme.textSecondary)
    }
}

/// Single thumbnail in the recent-entries strip. Step 3 ships a placeholder
/// graphic — the real photo loader (`PhotoStore.image(for:)`) lights up in
/// Step 6 once we have a capture pipeline.
private struct RecentEntryThumbnail: View {
    let entry: ProgressEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(Theme.surface)

                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(width: 100, height: 120)

            Text(entry.tracker?.name ?? "—")
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)

            Text("Today")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(width: 100)
    }
}

#Preview("Empty (post-onboarding)") {
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
    let profile = UserProfile(displayName: "Kiran")
    context.insert(profile)
    for tracker in SeedData.defaultTrackers() {
        context.insert(tracker)
    }

    return HomeView(profile: profile)
        .modelContainer(container)
}
