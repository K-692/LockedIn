// MARK: - FocusSession.swift
// Represents one completed or ongoing Pomodoro-style focus session.
// Fully decoupled from any domain; linked to a Task by ID only.

import Foundation

// MARK: - FocusSessionState

enum FocusSessionState: String, Codable {
    case idle
    case running
    case paused
    case breakTime
    case completed
}

// MARK: - FocusSession

struct FocusSession: Identifiable, Codable {
    var id: UUID = UUID()
    var taskId: UUID?                 // optional link to the task being worked on
    var taskTitle: String = ""        // snapshot of the task title at session start
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int          // target session length in seconds
    var secondsElapsed: Int = 0       // progress within the session
    var isBreak: Bool = false
}

// MARK: - TimerSettings

struct TimerSettings: Codable, Equatable {
    var focusDurationMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var sessionsUntilLongBreak: Int = 4
    var autoStartBreak: Bool = false
    var autoStartFocus: Bool = false
    var soundEnabled: Bool = true
    var notifyOnComplete: Bool = true
}
