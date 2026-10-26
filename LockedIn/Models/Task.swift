// MARK: - Task.swift
// An actionable unit of work, optionally containing subtasks.
// No domain-specific fields; works for any goal type.

import Foundation

// MARK: - TaskStatus

enum TaskStatus: String, Codable, CaseIterable {
    case notStarted  = "Not Started"
    case inProgress  = "In Progress"
    case completed   = "Completed"
    case onHold      = "On Hold"

    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed:  return "checkmark.circle.fill"
        case .onHold:     return "pause.circle"
        }
    }
}

// MARK: - TaskPriority

enum TaskPriority: String, Codable, CaseIterable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"

    var icon: String {
        switch self {
        case .low:    return "arrow.down"
        case .medium: return "minus"
        case .high:   return "arrow.up"
        }
    }
}

// MARK: - Task

struct Task: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    var status: TaskStatus = .notStarted
    var priority: TaskPriority = .medium
    var deadline: Date?                     // optional per-task deadline
    var isMilestone: Bool = false           // marks a significant checkpoint
    var subtasks: [Task] = []
    var createdAt: Date = Date()
    var completedAt: Date?

    // MARK: Computed

    /// Returns self plus all nested subtasks for flat progress calculations.
    var selfAndSubtasks: [Task] {
        [self] + subtasks.flatMap { $0.selfAndSubtasks }
    }

    /// A task has no subtasks itself — returns just [self].
    var leafTasks: [Task] {
        subtasks.isEmpty ? [self] : subtasks.flatMap { $0.selfAndSubtasks }
    }

    /// Local progress for subtask-bearing tasks.
    var progress: Double {
        let leaves = leafTasks
        guard !leaves.isEmpty else { return status == .completed ? 1 : 0 }
        let completed = leaves.filter { $0.status == .completed }.count
        return Double(completed) / Double(leaves.count)
    }

    /// Compatibility alias for target deadline
    var targetDeadline: Date? {
        get { deadline }
        set { deadline = newValue }
    }

    var daysRemaining: Int? {
        guard let dl = deadline else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end   = calendar.startOfDay(for: dl)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    var isCompleted: Bool {
        status == .completed
    }

    var isOverdue: Bool {
        guard let dl = deadline, status != .completed else { return false }
        return dl < Date()
    }
}
