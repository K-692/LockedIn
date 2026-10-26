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

    // MARK: Computed

    /// All tasks across every category, flattened.
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

    /// Days remaining until target deadline.
    var daysRemaining: Int? {
        guard let deadline = targetDeadline else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        return components.day
    }

    /// True when the target deadline has passed.
    var isOverdue: Bool {
        guard let deadline = targetDeadline else { return false }
        return deadline < Date()
    }
}
