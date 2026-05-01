//
//  ProovitApp.swift
//  Proovit
//
//  Created by Kiran Silwal on 5/1/26.
//

import SwiftUI
import SwiftData

@main
struct ProovitApp: App {

    // 💡 Learn: A `ModelContainer` owns the SwiftData store. The schema
    // lists every `@Model` type the app persists — adding a new model
    // means updating this list (and likely a migration plan, eventually).
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Tracker.self,
            ProgressEntry.self,
            UserProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // The app is unusable without persistence. Crashing here is
            // intentional — it surfaces the configuration error loudly
            // rather than silently corrupting data.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
