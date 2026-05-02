//
//  RootTabView.swift
//  Proovit
//
//  The five-tab shell that wraps the post-onboarding experience.
//  Selection is `@State` here — the bar binds to it. The Camera FAB
//  is a separate affordance that presents a modal in Step 6; in Step 4
//  it's wired to a no-op so the visual is stable but nothing blows up.
//

import SwiftData
import SwiftUI

struct RootTabView: View {
    let profile: UserProfile

    // 💡 Learn: @State on the parent + @Binding on the bar is the
    // canonical "lift state up" pattern. The bar doesn't own which tab
    // is active — RootTabView does. The bar just renders + reports taps.
    @State private var selection: AppTab = .home
    @State private var showingCamera: Bool = false

    var body: some View {
        // 💡 Learn: safeAreaInset(edge: .bottom) is the modern replacement
        // for manually padding ScrollView content above a custom bar.
        // It both renders the bar AND tells the content how much space
        // the bar consumes — so a ScrollView's last row isn't covered.
        contentView
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(
                    selection: $selection,
                    onCameraTap: { showingCamera = true }
                )
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView()
            }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .home:
            HomeView(profile: profile)
        case .calendar:
            TabPlaceholderView(title: "Calendar", comingInStep: 8)
        case .compare:
            TabPlaceholderView(title: "Compare", comingInStep: 9)
        case .profile:
            TabPlaceholderView(title: "Profile", comingInStep: 10)
        }
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
    let profile = UserProfile(displayName: "Kiran")
    context.insert(profile)
    for tracker in SeedData.defaultTrackers() {
        context.insert(tracker)
    }

    return RootTabView(profile: profile)
        .modelContainer(container)
}
