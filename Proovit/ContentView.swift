//
//  ContentView.swift
//  Proovit
//
//  Created by Kiran Silwal on 5/1/26.
//

import SwiftData
import SwiftUI

/// The app's routing root. Decides between the onboarding flow (no
/// UserProfile yet) and the post-onboarding experience.
///
/// In Step 2 the post-onboarding view is a placeholder that prints the
/// user's name and the seeded trackers. Step 3 replaces it with the
/// real `RootTabView` (Home / Calendar / Camera / Compare / Profile).
struct ContentView: View {
    // 💡 Learn: @Query is reactive — when the underlying SwiftData
    // store changes (here, when onboarding inserts the first
    // UserProfile), this view re-renders automatically and the
    // `if profiles.isEmpty` branch flips to the welcome view.
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first {
            PostOnboardingPlaceholder(profile: profile)
        } else {
            OnboardingView()
        }
    }
}

/// Step 2 placeholder. Replaced by `RootTabView` in Step 3.
private struct PostOnboardingPlaceholder: View {
    let profile: UserProfile

    @Query(sort: \Tracker.sortOrder) private var trackers: [Tracker]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Welcome, \(profile.displayName)")
                        .font(.title.bold())
                        .foregroundStyle(Theme.textPrimary)

                    Text("Step 2 — Onboarding + seed data")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Text("TRACKERS")
                    .font(.caption)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Theme.Spacing.lg)

                VStack(spacing: 0) {
                    ForEach(Array(trackers.enumerated()), id: \.element.id) { index, tracker in
                        trackerRow(tracker)

                        if index < trackers.count - 1 {
                            Rectangle()
                                .fill(Theme.divider)
                                .frame(height: 1)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xxl)
        }
    }

    private func trackerRow(_ tracker: Tracker) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Theme.trackerColor(named: tracker.colorAssetName))
                .frame(width: 10, height: 10)

            Image(systemName: tracker.iconSymbolName)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 24)

            Text(tracker.name)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }
}

#Preview("Onboarding") {
    ContentView()
        .modelContainer(
            for: [Tracker.self, ProgressEntry.self, UserProfile.self],
            inMemory: true
        )
}

#Preview("Post-onboarding") {
    // 💡 Learn: Building the container manually (rather than the
    // .modelContainer(for:inMemory:) modifier) lets us seed fixture
    // data before the view renders, so the preview shows the
    // post-onboarding branch with content.
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
    context.insert(UserProfile(displayName: "Kiran"))
    for tracker in SeedData.defaultTrackers() {
        context.insert(tracker)
    }

    return ContentView().modelContainer(container)
}
