// MARK: - NotificationService.swift
// Manages all local notifications — domain-neutral wording only.

import Foundation
import UserNotifications

final class NotificationService {

    // MARK: - Permission

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    // MARK: - Goal Deadline Approach

    /// Schedules a notification when the goal deadline is N days away.
    static func scheduleGoalDeadlineWarning(goal: Goal, daysWarning: Int) {
        guard let deadline = goal.targetDeadline else { return }
        let warningDate = Calendar.current.date(byAdding: .day, value: -daysWarning, to: deadline) ?? deadline

        let content = UNMutableNotificationContent()
        content.title = "⏳ Deadline Approaching"
        content.body  = "\"\(goal.name)\" is due in \(daysWarning) days. Stay focused!"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: warningDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "goal-warning-\(goal.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Daily Reminder

    static func scheduleDailyReminder(at hour: Int = 9, minute: Int = 0, goalName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🔒 LockedIn"
        content.body  = "Time to make progress on \"\(goalName)\"."
        content.sound = .default

        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }


    // MARK: - Milestone Reached

    static func sendMilestoneNotification(milestoneName: String, goalName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🎯 Milestone Reached!"
        content.body  = "\"\(milestoneName)\" in \"\(goalName)\" is complete!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request  = UNNotificationRequest(identifier: "milestone-\(UUID())", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Remove

    static func removePendingNotifications(forGoalId id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["goal-warning-\(id)"])
    }

    static func removeAllPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
