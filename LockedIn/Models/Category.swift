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

    init(id: UUID = UUID(), name: String, colorHex: String = "#5E8FF7", tasks: [Task] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.tasks = tasks
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name      = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled category"
        colorHex  = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#5E8FF7"
        tasks     = try c.decodeIfPresent([Task].self, forKey: .tasks) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    // MARK: Computed

    /// Every task and nested subtask in this category.
    var allLeafTasks: [Task] {
        tasks.flatMap { $0.selfAndSubtasks }
    }

    /// Progress for this category's tasks in [0, 1].
    var progress: Double {
        let leafTasks = allLeafTasks
        guard !leafTasks.isEmpty else { return 0 }
        let completed = leafTasks.filter { $0.status == .completed }.count
        return Double(completed) / Double(leafTasks.count)
    }

    /// True when `taskId` is a task or nested subtask of this category.
    func contains(taskId: UUID) -> Bool {
        allLeafTasks.contains { $0.id == taskId }
    }
}
