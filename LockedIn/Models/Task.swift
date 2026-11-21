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

    /// Unknown raw values (e.g. from a newer build) decode as `.notStarted` instead of failing.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TaskStatus(rawValue: raw) ?? .notStarted
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

    /// Sort weight: higher priority first.
    var rank: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TaskPriority(rawValue: raw) ?? .medium
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

    init(id: UUID = UUID(), title: String, notes: String = "", status: TaskStatus = .notStarted,
         priority: TaskPriority = .medium, deadline: Date? = nil, isMilestone: Bool = false,
         subtasks: [Task] = [], createdAt: Date = Date(), completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.deadline = deadline
        self.isMilestone = isMilestone
        self.subtasks = subtasks
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    // Tolerant decoding: missing keys fall back to defaults so older data files keep loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title       = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled task"
        notes       = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        status      = try c.decodeIfPresent(TaskStatus.self, forKey: .status) ?? .notStarted
        priority    = try c.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .medium
        deadline    = try c.decodeIfPresent(Date.self, forKey: .deadline)
        isMilestone = try c.decodeIfPresent(Bool.self, forKey: .isMilestone) ?? false
        subtasks    = try c.decodeIfPresent([Task].self, forKey: .subtasks) ?? []
        createdAt   = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    // MARK: Computed

    /// Returns self plus all nested subtasks for flat progress calculations.
    var selfAndSubtasks: [Task] {
        [self] + subtasks.flatMap { $0.selfAndSubtasks }
    }

    /// Leaf tasks below this task (or just [self] when it has no subtasks).
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

    /// Whole calendar days from today to the deadline (negative when overdue).
    var daysRemaining: Int? {
        deadline.map { Date.calendarDays(from: Date(), to: $0) }
    }

    var isCompleted: Bool {
        status == .completed
    }

    /// Overdue once the deadline's calendar day has passed.
    var isOverdue: Bool {
        guard let days = daysRemaining, status != .completed else { return false }
        return days < 0
    }

    // MARK: Mutation helpers

    /// Sets status and keeps `completedAt` consistent.
    mutating func setStatus(_ newStatus: TaskStatus) {
        status = newStatus
        if newStatus == .completed {
            if completedAt == nil { completedAt = Date() }
        } else {
            completedAt = nil
        }
    }

    /// Applies `body` to the task with `id` (self or any nested subtask). Returns true if found.
    @discardableResult
    mutating func mutateTask(id targetId: UUID, _ body: (inout Task) -> Void) -> Bool {
        if id == targetId {
            body(&self)
            return true
        }
        for i in subtasks.indices where subtasks[i].mutateTask(id: targetId, body) {
            return true
        }
        return false
    }

    /// Removes a nested subtask with `id`. Returns true if found.
    @discardableResult
    mutating func removeSubtask(id targetId: UUID) -> Bool {
        if let idx = subtasks.firstIndex(where: { $0.id == targetId }) {
            subtasks.remove(at: idx)
            return true
        }
        for i in subtasks.indices where subtasks[i].removeSubtask(id: targetId) {
            return true
        }
        return false
    }
}

// MARK: - Sorting

extension Array where Element == Task {
    /// Display order for task lists: pending tasks by earliest deadline (no deadline last),
    /// then completed tasks — also by deadline — at the bottom.
    func sortedByDeadline() -> [Task] {
        let pending = filter { $0.status != .completed }.sortedByUrgency()
        let done = filter { $0.status == .completed }.sortedByUrgency()
        return pending + done
    }

    /// Earliest deadline first (tasks without a deadline last), then priority, then creation order.
    func sortedByUrgency() -> [Task] {
        sorted { a, b in
            switch (a.deadline, b.deadline) {
            case let (x?, y?) where x != y: return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default:
                if a.priority.rank != b.priority.rank { return a.priority.rank < b.priority.rank }
                return a.createdAt < b.createdAt
            }
        }
    }
}
