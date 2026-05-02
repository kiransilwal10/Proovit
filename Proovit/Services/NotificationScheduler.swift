//
//  NotificationScheduler.swift
//  Proovit
//
//  Wraps UNUserNotificationCenter for the daily reminder. The single
//  responsibility is `sync(notificationsEnabled:reminderHour:reminderMinute:)`:
//  it cancels any existing pending reminder, then schedules a fresh
//  daily-repeating one if the user has notifications enabled and the
//  system has granted permission.
//
//  Permission flow: the first time we try to schedule, we request
//  authorization. If the user denies, the toggle stays "on" in the
//  UI but no notification fires — that's a v1.0 known quirk we don't
//  surface yet (the polish step would show a banner pointing to
//  Settings, similar to the camera-denied screen).
//

import Foundation
import Observation
import UserNotifications

@Observable
final class NotificationScheduler {

    enum AuthorizationStatus: Sendable {
        case notDetermined
        case authorized
        case provisional
        case denied
    }

    /// Stable identifier so re-syncs cancel the previous schedule
    /// rather than stacking up duplicate reminders.
    static let dailyReminderID = "proovit.daily-reminder"

    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    init() {}

    // MARK: - Public

    /// Idempotent. Removes any pending daily reminder; if the user
    /// wants notifications and has (or grants) permission, schedules
    /// a fresh one at the supplied hour:minute, repeating daily.
    func sync(
        notificationsEnabled: Bool,
        reminderHour: Int,
        reminderMinute: Int
    ) async {
        let center = UNUserNotificationCenter.current()

        // Always start by clearing the previous schedule. If the user
        // changed time or toggled off, this is the only cleanup needed.
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderID])

        guard notificationsEnabled else {
            await refreshAuthorizationStatus()
            return
        }

        let granted = await ensureAuthorized()
        guard granted else { return }

        // 💡 Learn: A `DateComponents` trigger with only hour and minute
        // set fires at that time *every day* in the user's local zone —
        // exactly what we want. Don't pass a year/month/day or it
        // becomes one-shot.
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let content = UNMutableNotificationContent()
        content.title = "Proovit"
        content.body = "Time to capture today's progress."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.dailyReminderID,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            // System refused to schedule — leave the toggle alone,
            // user will notice no notifications and either retry or
            // check Settings. v1.0 doesn't surface this case yet.
        }
    }

    // MARK: - Private

    /// Reads the current authorization state and stores it so views
    /// can render auth-dependent UI later (e.g. a banner in Profile).
    private func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = Self.map(settings.authorizationStatus)
    }

    /// Returns true if we already have permission, or if we just got it
    /// after prompting. Prompts the user only on the `.notDetermined`
    /// path — once denied, we never re-prompt (iOS would silently
    /// ignore further requests anyway).
    private func ensureAuthorized() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorizationStatus = .authorized
            return true

        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
                authorizationStatus = granted ? .authorized : .denied
                return granted
            } catch {
                authorizationStatus = .denied
                return false
            }

        case .denied:
            authorizationStatus = .denied
            return false

        @unknown default:
            authorizationStatus = .denied
            return false
        }
    }

    private static func map(_ status: UNAuthorizationStatus) -> AuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .provisional:   return .provisional
        case .authorized:    return .authorized
        case .denied:        return .denied
        case .ephemeral:     return .authorized
        @unknown default:    return .denied
        }
    }
}
