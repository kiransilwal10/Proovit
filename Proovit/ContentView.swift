//
//  ContentView.swift
//  Proovit
//
//  Created by Kiran Silwal on 5/1/26.
//

import SwiftUI

/// Temporary launch placeholder. Step 1 of the build order ships only the
/// foundations (Theme, data model, pure logic + tests). The real root view
/// — `RootTabView` with Home / Calendar / Camera / Compare / Profile —
/// arrives in later steps. This screen exists so the team can run the app
/// after Step 1 and verify the design tokens render correctly.
struct ContentView: View {
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Text("Proovit")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.textPrimary)

                Text("Your Progress, Proven")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)

                Text("Step 1 — Foundations")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Theme.Spacing.xl)

                // Visual sanity check: render the curated tracker palette
                // so we can see colors loaded from the Asset Catalog.
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Theme.trackerPalette) { entry in
                        Circle()
                            .fill(entry.color)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.top, Theme.Spacing.lg)
            }
            .padding(Theme.Spacing.lg)
        }
    }
}

#Preview {
    ContentView()
}
