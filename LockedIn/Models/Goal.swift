// MARK: - Goal.swift
// Top-level model representing any outcome the user wants to achieve.
// Domain-neutral: works for academic, professional, fitness, creative goals alike.

import Foundation

struct Goal: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String                         // e.g. "Finish my project", "Learn Swift"
    var targetDeadline: Date?                // optional target date
    var createdAt: Date = Date()
    var categories: [Category] = []
    var isArchived: Bool = false

    init(id: UUID = UUID(), name: String, targetDeadline: Date? = nil, createdAt: Date = Date(),
         categories: [Category] = [], isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.targetDeadline = targetDeadline
        self.createdAt = createdAt
        self.categories = categories
        self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name           = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled goal"
        targetDeadline = try c.decodeIfPresent(Date.self, forKey: .targetDeadline)
        createdAt      = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        categories     = try c.decodeIfPresent([Category].self, forKey: .categories) ?? []
        isArchived     = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    // MARK: Computed

    /// All top-level tasks across every category.
    var allTasks: [Task] {
        categories.flatMap { $0.tasks }
    }

    /// All top-level tasks and subtasks combined.
    var allLeafTasks: [Task] {
        allTasks.flatMap { $0.selfAndSubtasks }
    }

    /// Overall progress as a value in [0, 1].
    var overallProgress: Double {
        let eligible = allLeafTasks
        guard !eligible.isEmpty else { return 0 }
        let completed = eligible.filter { $0.status == .completed }.count
        return Double(completed) / Double(eligible.count)
    }

    /// Whole calendar days until the target deadline (negative when overdue).
    var daysRemaining: Int? {
        targetDeadline.map { Date.calendarDays(from: Date(), to: $0) }
    }

    /// True once the deadline's calendar day has passed.
    var isOverdue: Bool {
        guard let days = daysRemaining else { return false }
        return days < 0
    }

    /// The category that owns `taskId` (top-level or nested).
    func categoryId(containing taskId: UUID) -> UUID? {
        categories.first { $0.contains(taskId: taskId) }?.id
    }
}
