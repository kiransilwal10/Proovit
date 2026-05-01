//
//  OnboardingView.swift
//  Proovit
//
//  First-launch screen. Captures the display name and seeds the default
//  trackers in a single SwiftData transaction. Shown by ContentView only
//  when no UserProfile row exists.
//
//  We intentionally do NOT request camera or notification permissions
//  here. Those prompts fire when the user first tries the corresponding
//  feature — that gives Apple's permission dialogs the context they need
//  ("Proovit wants to use the camera to capture your progress photos").
//

import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var displayName: String = ""

    // 💡 Learn: @FocusState lets us programmatically move keyboard focus.
    // Setting it to true onAppear puts the cursor straight in the field
    // — no extra tap required to start typing.
    @FocusState private var nameFieldFocused: Bool

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Spacer()

                brandMark

                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 64, height: 1)
                    .padding(.vertical, Theme.Spacing.sm)

                prompt

                nameField

                Spacer()

                continueButton

                privacyNote
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.xxl)
        }
        .onAppear {
            nameFieldFocused = true
        }
    }

    // MARK: - Subviews

    private var brandMark: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Proovit")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)

            Text("Your Progress, Proven")
                .font(.title3)
                .foregroundStyle(Theme.accent)
        }
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Welcome.")
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)

            Text("What should we call you?")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var nameField: some View {
        TextField("Your name", text: $displayName)
            .focused($nameFieldFocused)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .onSubmit { commit() }
            .padding(Theme.Spacing.md)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    private var continueButton: some View {
        Button {
            commit()
        } label: {
            Text("Continue")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(canContinue ? Theme.accent : Theme.accent.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
        .disabled(!canContinue)
    }

    private var privacyNote: some View {
        Text("Your name stays on this device. No accounts, no sign-in.")
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
    }

    // MARK: - Actions

    /// Persists the new profile and the seed trackers, then dismisses
    /// the keyboard. ContentView's @Query reactively switches to the
    /// post-onboarding view as soon as the UserProfile row exists.
    private func commit() {
        guard canContinue else { return }
        nameFieldFocused = false

        // 💡 Learn: We insert the profile and seed trackers into the
        // same ModelContext. SwiftData groups inserts done in one tick
        // into a single transaction — explicit save() makes the write
        // durable before we lose context.
        let profile = UserProfile(displayName: trimmedName)
        modelContext.insert(profile)

        for tracker in SeedData.defaultTrackers() {
            modelContext.insert(tracker)
        }

        try? modelContext.save()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(
            for: [Tracker.self, ProgressEntry.self, UserProfile.self],
            inMemory: true
        )
}
