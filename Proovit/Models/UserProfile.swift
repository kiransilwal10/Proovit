//
//  UserProfile.swift
//  Proovit
//
//  The local profile — name, avatar initials, and app preferences.
//  Singleton in practice: there is exactly one row, created at the end
//  of first-launch onboarding. Never instantiated more than once.
//
//  No auth, no backend. The whole record lives in SwiftData on-device.
//

import Foundation
import SwiftData

enum AppearancePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

@Model
final class UserProfile {

    @Attribute(.unique) var id: UUID

    var displayName: String

    /// Hour (0–23) of the daily reminder.
    var reminderHour: Int

    /// Minute (0–59) of the daily reminder.
    var reminderMinute: Int

    /// Toggling this off cancels the scheduled local notification.
    var notificationsEnabled: Bool

    var appearancePreference: AppearancePreference

    var createdAt: Date

    /// Initials used for the avatar bubble. Computed, not stored — falls back
    /// to "?" if the name is empty so the UI doesn't break.
    var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: " ")
        let firsts = parts.prefix(2).compactMap { $0.first }
        return String(firsts).uppercased()
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        reminderHour: Int = 8,
        reminderMinute: Int = 0,
        notificationsEnabled: Bool = true,
        appearancePreference: AppearancePreference = .system,
        createdAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.notificationsEnabled = notificationsEnabled
        self.appearancePreference = appearancePreference
        self.createdAt = createdAt
    }
}
