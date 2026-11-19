// MARK: - NotificationService.swift
// Manages all local notifications — domain-neutral wording only.
// All scheduled reminders are derived from current state via `reschedule(goals:settings:)`,
// so they never drift out of sync with edits, deletions or settings changes.

import Foundation
import UserNotifications

enum NotificationService {

    /// UNUserNotificationCenter raises an exception when the process is not a proper
    /// .app bundle (e.g. `swift run`). Every entry point checks this first.
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    private static let managedPrefix = "lockedin."
    /// macOS keeps at most 64 pending requests per app.
    private static let maxPending = 60

    // MARK: - Permission

    @discardableResult
    static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let granted = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    // MARK: - Reschedule (single source of truth)

    static func reschedule(goals: [Goal], settings: AppSettings) {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(managedPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)

            guard settings.notificationsEnabled else { return }

            var requests: [UNNotificationRequest] = []
            let now = Date()
            let activeGoal = goals.first { $0.id == settings.activeGoalId } ?? goals.first

            // Digest reminder for the active goal.
            if let goal = activeGoal, settings.notificationFrequency != .never {
                var comps = DateComponents()
                comps.hour = 9
                comps.minute = 0
                if settings.notificationFrequency == .weekly { comps.weekday = 2 } // Monday
                let content = makeContent(
                    title: "LockedIn",
                    body: digestBody(for: goal)
                )
                requests.append(UNNotificationRequest(
                    identifier: managedPrefix + "digest",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                ))
            }

            // Goal deadline approach warnings.
            if settings.notifyOnGoalDeadlineApproach {
                for goal in goals {
                    guard let deadline = goal.targetDeadline,
                          let warn = Calendar.current.date(byAdding: .day, value: -settings.goalDeadlineWarningDays, to: deadline),
                          let fire = morning(of: warn), fire > now else { continue }
                    let days = settings.goalDeadlineWarningDays
                    requests.append(UNNotificationRequest(
                        identifier: managedPrefix + "goal.\(goal.id)",
                        content: makeContent(
                            title: "Deadline approaching",
                            body: "\"\(goal.name)\" is due in \(days) day\(days == 1 ? "" : "s"). Stay locked in."
                        ),
                        trigger: calendarTrigger(fire)
                    ))
                }
            }

            // Task deadline reminders (morning of the due day), earliest first.
            if settings.notifyOnTaskDeadline {
                let upcoming = goals.flatMap { goal in
                    goal.allLeafTasks.compactMap { task -> (Goal, Task, Date)? in
                        guard task.status != .completed,
                              let dl = task.deadline,
                              let fire = morning(of: dl), fire > now else { return nil }
                        return (goal, task, fire)
                    }
                }
                .sorted { $0.2 < $1.2 }

                for (goal, task, fire) in upcoming.prefix(max(0, maxPending - requests.count)) {
                    requests.append(UNNotificationRequest(
                        identifier: managedPrefix + "task.\(task.id)",
                        content: makeContent(
                            title: task.isMilestone ? "Milestone due today" : "Task due today",
                            body: "\"\(task.title)\" in \"\(goal.name)\" is due today."
                        ),
                        trigger: calendarTrigger(fire)
                    ))
                }
            }

            requests.prefix(maxPending).forEach { center.add($0) }
        }
    }

    // MARK: - Milestone Reached (immediate)

    static func sendMilestoneNotification(milestoneName: String, goalName: String) {
        guard isAvailable else { return }
        let request = UNNotificationRequest(
            identifier: "milestone-\(UUID())",
            content: makeContent(title: "Milestone reached", body: "\"\(milestoneName)\" in \"\(goalName)\" is complete!"),
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func removeAllPending() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Helpers

    private static func makeContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }

    private static func morning(of date: Date) -> Date? {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date)
    }

    private static func calendarTrigger(_ date: Date) -> UNCalendarNotificationTrigger {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    }

    private static func digestBody(for goal: Goal) -> String {
        let pct = Int((goal.overallProgress * 100).rounded())
        if let days = goal.daysRemaining, days >= 0 {
            return "\"\(goal.name)\" is \(pct)% complete with \(days) day\(days == 1 ? "" : "s") to go."
        }
        return "Time to make progress on \"\(goal.name)\" (\(pct)% complete)."
    }
}
