// MARK: - Category.swift
// A user-defined grouping of tasks within a Goal.
// Categories are fully user-controlled and carry no domain assumptions.

import Foundation

struct Category: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String                 // e.g. "Writing", "Research", "Training"
    var colorHex: String = "#5E8FF7" // display color for the category badge
    var tasks: [Task] = []
    var createdAt: Date = Date()

    // MARK: Computed

    /// Progress for this category's leaf tasks in [0, 1].
    var progress: Double {
        let leafTasks = tasks.flatMap { $0.selfAndSubtasks }
        guard !leafTasks.isEmpty else { return 0 }
        let completed = leafTasks.filter { $0.status == .completed }.count
        return Double(completed) / Double(leafTasks.count)
    }
}
