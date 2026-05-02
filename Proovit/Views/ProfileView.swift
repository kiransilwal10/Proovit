//
//  ProfileView.swift
//  Proovit
//
//  The Profile tab: identity (avatar + name + member-since), three
//  lifetime-stat cards, a Preferences card (reminder time, appearance,
//  notifications), and an Account card (privacy, export, help).
//
//  Reminder time is stored on UserProfile; Step 11 (notifications)
//  reads it to schedule the daily local notification. Appearance
//  preference flows up to RootTabView's preferredColorScheme.
//

import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query private var trackers: [Tracker]
    @Query private var entries: [ProgressEntry]

    var body: some View {
        if let profile = profiles.first {
            ProfileContent(
                profile: profile,
                trackers: trackers,
                entries: entries
            )
        } else {
            // Onboarding guarantees a profile exists; this branch is
            // a safety net rather than a path the user reaches.
            EmptyView()
        }
    }
}

// MARK: - Main content

/// The profile body. Split out so we can use `@Bindable` on the
/// guaranteed-non-nil profile (instead of binding through optional
/// chaining at every preference toggle).
private struct ProfileContent: View {
    @Bindable var profile: UserProfile
    let trackers: [Tracker]
    let entries: [ProgressEntry]

    @State private var showingEditProfile = false
    @State private var showingTimePicker = false
    @State private var showingPrivacy = false

    private let calendar: Calendar = .current

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                identitySection
                statsRow
                preferencesCard
                accountCard

                Color.clear.frame(height: Theme.Spacing.xl)
            }
            .padding(.top, Theme.Spacing.lg)
        }
        .background(Theme.background)
        .sheet(isPresented: $showingEditProfile) {
            EditProfileSheet(profile: profile)
        }
        .sheet(isPresented: $showingTimePicker) {
            ReminderTimeSheet(profile: profile)
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacySheet()
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button {
                showingEditProfile = true
            } label: {
                AvatarView(initials: profile.initials, size: 72)
            }
            .buttonStyle(.plain)

            Text(profile.displayName)
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)

            Text("Member since \(formattedMonthYear(profile.createdAt))")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            statCard(value: "\(entries.count)", label: "Total Photos")
            statCard(value: "\(bestStreak)", label: "Best Streak")
            statCard(value: "\(trackers.count)", label: "Trackers")
        }
        .padding(.horizontal, Theme.Spacing.lg)
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

    private var bestStreak: Int {
        StreakCalculator.bestStreak(
            photoDates: entries.map(\.capturedAt),
            calendar: calendar
        )
    }

    // MARK: - Preferences card

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("PREFERENCES")

            VStack(spacing: 0) {
                Button {
                    showingTimePicker = true
                } label: {
                    SettingsRow(label: "Reminder Time", value: reminderTimeText, showsChevron: true)
                }
                .buttonStyle(.plain)

                rowDivider

                appearanceRow

                rowDivider

                notificationsRow
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var appearanceRow: some View {
        HStack {
            Text("Appearance")
                .font(.body)
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            // 💡 Learn: A Picker bound to a SwiftData property updates
            // the model on selection. The .menu style renders as a
            // button that opens a system menu, which keeps the row
            // height consistent with the others.
            Picker("Appearance", selection: $profile.appearancePreference) {
                ForEach(AppearancePreference.allCases) { pref in
                    Text(pref.displayName).tag(pref)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.textSecondary)
            .labelsHidden()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var notificationsRow: some View {
        HStack {
            Text("Notifications")
                .font(.body)
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Toggle("", isOn: $profile.notificationsEnabled)
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var reminderTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let now = Date()
        let date = calendar.date(
            bySettingHour: profile.reminderHour,
            minute: profile.reminderMinute,
            second: 0,
            of: now
        ) ?? now
        return formatter.string(from: date)
    }

    // MARK: - Account card

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("ACCOUNT")

            VStack(spacing: 0) {
                Button {
                    showingPrivacy = true
                } label: {
                    SettingsRow(label: "Privacy", value: nil, showsChevron: true)
                }
                .buttonStyle(.plain)

                rowDivider

                exportRow

                rowDivider

                helpRow
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    /// Tap → system share sheet with every captured photo. iOS 17+'s
    /// `ShareLink(items:)` accepts URL collections (URL is Transferable).
    @ViewBuilder
    private var exportRow: some View {
        if photoURLs.isEmpty {
            SettingsRow(label: "Export Data", value: "No photos yet", showsChevron: false)
        } else {
            ShareLink(items: photoURLs) {
                SettingsRow(
                    label: "Export Data",
                    value: "\(photoURLs.count) photo\(photoURLs.count == 1 ? "" : "s")",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textPrimary)
        }
    }

    private var photoURLs: [URL] {
        guard let store = try? PhotoStore() else { return [] }
        return entries.map { store.url(for: $0.photoFilename) }
    }

    @ViewBuilder
    private var helpRow: some View {
        if let mailto = URL(string: "mailto:support@proovit.app") {
            Link(destination: mailto) {
                SettingsRow(label: "Help & Support", value: nil, showsChevron: true)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
            .padding(.leading, Theme.Spacing.md)
    }

    private func formattedMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Settings row primitive

/// Generic right-aligned-value row used by Preferences and Account.
private struct SettingsRow: View {
    let label: String
    let value: String?
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(label)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            if let value {
                Text(value)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Reminder time sheet

private struct ReminderTimeSheet: View {
    @Bindable var profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @State private var pickedTime: Date

    init(profile: UserProfile) {
        self.profile = profile
        let date = Calendar.current.date(
            bySettingHour: profile.reminderHour,
            minute: profile.reminderMinute,
            second: 0,
            of: Date()
        ) ?? Date()
        _pickedTime = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Reminder time",
                    selection: $pickedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(Theme.background)
            .navigationTitle("Reminder time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let cal = Calendar.current
        profile.reminderHour = cal.component(.hour, from: pickedTime)
        profile.reminderMinute = cal.component(.minute, from: pickedTime)
        dismiss()
    }
}

// MARK: - Privacy sheet

private struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    privacyParagraph(
                        title: "Local Storage",
                        body: "Proovit keeps every photo and tracker on this device. Nothing is uploaded to a server. There is no account, no cloud sync, and no analytics."
                    )

                    privacyParagraph(
                        title: "Camera-Only Capture",
                        body: "Photos are captured directly through the camera. You can't import from your photo library — this is a deliberate product decision so your progress record stays authentic and timestamped."
                    )

                    privacyParagraph(
                        title: "Deletion",
                        body: "Deleting a tracker removes its photos from disk immediately. Deleting the app removes everything permanently — there is no remote copy."
                    )
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.background)
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func privacyParagraph(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
            Text(body)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - AppearancePreference display

private extension AppearancePreference {
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
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
    context.insert(UserProfile(displayName: "Kiran"))
    for tracker in SeedData.defaultTrackers() {
        context.insert(tracker)
    }

    return ProfileView()
        .modelContainer(container)
}
