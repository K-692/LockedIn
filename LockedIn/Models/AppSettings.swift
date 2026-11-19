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

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AppearancePreference(rawValue: raw) ?? .system
    }
}

// MARK: - NotificationFrequency

enum NotificationFrequency: String, Codable, CaseIterable {
    case daily   = "Daily"
    case weekly  = "Weekly"
    case never   = "Never"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NotificationFrequency(rawValue: raw) ?? .daily
    }
}

// MARK: - AppSettings

struct AppSettings: Codable, Equatable {
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

    // Dock behaviour: hide the Dock icon whenever the main window is closed
    // (LockedIn keeps running in the menu bar either way).
    var hideDockIconWhenClosed: Bool = true

    // Active goal
    var activeGoalId: UUID?

    init() {}

    // Tolerant decoding: every key is optional so settings files from older
    // (or newer) versions never reset the user's preferences.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.defaults
        appearance                    = try c.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? d.appearance
        showCountdownInMenuBar        = try c.decodeIfPresent(Bool.self, forKey: .showCountdownInMenuBar) ?? d.showCountdownInMenuBar
        showProgressInMenuBar         = try c.decodeIfPresent(Bool.self, forKey: .showProgressInMenuBar) ?? d.showProgressInMenuBar
        notificationsEnabled          = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? d.notificationsEnabled
        notificationFrequency         = try c.decodeIfPresent(NotificationFrequency.self, forKey: .notificationFrequency) ?? d.notificationFrequency
        notifyOnTaskDeadline          = try c.decodeIfPresent(Bool.self, forKey: .notifyOnTaskDeadline) ?? d.notifyOnTaskDeadline
        notifyOnMilestoneReached      = try c.decodeIfPresent(Bool.self, forKey: .notifyOnMilestoneReached) ?? d.notifyOnMilestoneReached
        notifyOnGoalDeadlineApproach  = try c.decodeIfPresent(Bool.self, forKey: .notifyOnGoalDeadlineApproach) ?? d.notifyOnGoalDeadlineApproach
        goalDeadlineWarningDays       = try c.decodeIfPresent(Int.self, forKey: .goalDeadlineWarningDays) ?? d.goalDeadlineWarningDays
        launchAtLogin                 = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        alternateNearestTaskInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .alternateNearestTaskInMenuBar) ?? d.alternateNearestTaskInMenuBar
        hasCompletedOnboarding        = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? d.hasCompletedOnboarding
        hideDockIconWhenClosed        = try c.decodeIfPresent(Bool.self, forKey: .hideDockIconWhenClosed) ?? d.hideDockIconWhenClosed
        activeGoalId                  = try c.decodeIfPresent(UUID.self, forKey: .activeGoalId)
        goalDeadlineWarningDays       = min(max(goalDeadlineWarningDays, 1), 90)
    }

    private static let defaults = AppSettings()
}
