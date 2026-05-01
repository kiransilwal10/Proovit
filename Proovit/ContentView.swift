//
//  ContentView.swift
//  Proovit
//
//  Created by Kiran Silwal on 5/1/26.
//

import SwiftData
import SwiftUI

/// The app's routing root. Decides between the onboarding flow (no
/// UserProfile yet) and the main experience.
///
/// In Step 3 the main experience is `HomeView` standalone. Step 4 wraps
/// it in `RootTabView` (Home / Calendar / Camera / Compare / Profile).
struct ContentView: View {
    // 💡 Learn: @Query is reactive — when the underlying SwiftData
    // store changes (here, when onboarding inserts the first
    // UserProfile), this view re-renders automatically and the
    // `if profiles.isEmpty` branch flips to HomeView.
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first {
            HomeView(profile: profile)
        } else {
            OnboardingView()
        }
    }
}

#Preview("Onboarding") {
    ContentView()
        .modelContainer(
            for: [Tracker.self, ProgressEntry.self, UserProfile.self],
            inMemory: true
        )
}

#Preview("Home (post-onboarding)") {
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
