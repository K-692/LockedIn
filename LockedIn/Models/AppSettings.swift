// MARK: - AppSettings.swift
// All user-configurable preferences persisted in UserDefaults.

import Foundation
import SwiftUI

// MARK: - AppearancePreference

enum AppearancePreference: String, Codable, CaseIterable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"

    /// Maps to SwiftUI's ColorScheme for manual override.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - NotificationFrequency

enum NotificationFrequency: String, Codable, CaseIterable {
    case daily   = "Daily"
    case weekly  = "Weekly"
    case never   = "Never"
}

// MARK: - AppSettings

struct AppSettings: Codable {
    // Appearance
    var appearance: AppearancePreference = .system

    // Target deadline display
    var showCountdownInMenuBar: Bool = true
    var showProgressInMenuBar: Bool = true

    // Notifications
    var notificationsEnabled: Bool = true
    var notificationFrequency: NotificationFrequency = .daily
    var notifyOnTaskDeadline: Bool = true
    var notifyOnMilestoneReached: Bool = true
    var notifyOnGoalDeadlineApproach: Bool = true
    var goalDeadlineWarningDays: Int = 7

    // Launch
    var launchAtLogin: Bool = false

    // Menu Bar Alternating Display
    var alternateNearestTaskInMenuBar: Bool = true

    // Onboarding
    var hasCompletedOnboarding: Bool = false

    // Active goal & task
    var activeGoalId: UUID?
    var activeTaskId: UUID?
}
