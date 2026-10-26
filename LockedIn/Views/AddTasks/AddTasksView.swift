// MARK: - AddTasksView.swift
// Tab 2: Full goal, category, task, and subtask management.
// Single-sheet architecture ensures adding and editing tasks never fails.
// Supports both quick inline task creation and detailed modal forms.

import SwiftUI

// MARK: - Active Sheet Enum

enum AddTasksSheet: Identifiable {
    case addGoal
    case editGoal(Goal)
    case addCategory(goalId: UUID)
    case editCategory(goalId: UUID, category: Category)
    case addTask(goalId: UUID, categoryId: UUID)
    case editTask(goalId: UUID, categoryId: UUID, task: Task)

    var id: String {
        switch self {
        case .addGoal:
            return "addGoal"
        case .editGoal(let g):
            return "editGoal-\(g.id)"
        case .addCategory(let gid):
            return "addCategory-\(gid)"
        case .editCategory(let gid, let c):
            return "editCategory-\(gid)-\(c.id)"
        case .addTask(let gid, let cid):
            return "addTask-\(gid)-\(cid)"
        case .editTask(let gid, let cid, let t):
            return "editTask-\(gid)-\(cid)-\(t.id)"
        }
    }
}

// MARK: - AddTasksView

struct AddTasksView: View {
    @EnvironmentObject var vm: AppViewModel

    @State private var activeSheet: AddTasksSheet? = nil
    @State private var expandedCategories: Set<UUID> = []
    @State private var inlineNewTaskText: [UUID: String] = [:]

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar: goal selector
            goalSidebar
                .frame(width: 230)
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Main content: categories & tasks
            if let goal = vm.activeGoal {
                mainContent(goal: goal)
            } else {
                EmptyStateView(
                    icon: "target",
                    title: "No Goals",
                    message: "Create your first goal to start organizing tasks.",
                    action: { activeSheet = .addGoal },
                    actionLabel: "Create Goal"
                )
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
                .environmentObject(vm)
        }
    }

    // MARK: - Sheet Builder

    @ViewBuilder
    private func sheetContent(for sheet: AddTasksSheet) -> some View {
        switch sheet {
        case .addGoal:
            GoalFormSheet(editingGoal: nil)
        case .editGoal(let goal):
            GoalFormSheet(editingGoal: goal)
        case .addCategory(let goalId):
            CategoryFormSheet(goalId: goalId, editingCategory: nil)
        case .editCategory(let goalId, let category):
            CategoryFormSheet(goalId: goalId, editingCategory: category)
        case .addTask(let goalId, let categoryId):
            TaskFormSheet(goalId: goalId, categoryId: categoryId, editingTask: nil)
        case .editTask(let goalId, let categoryId, let task):
            TaskFormSheet(goalId: goalId, categoryId: categoryId, editingTask: task)
        }
    }

    // MARK: - Goal Sidebar

    private var goalSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Goals")
                    .font(LKFont.headline)
                    .foregroundColor(.labelSecondary)
                Spacer()
                Button {
                    activeSheet = .addGoal
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Add Goal")
            }
            .padding(LKSpacing.md)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(vm.goals) { goal in
                        goalRow(goal)
                    }
                }
                .padding(LKSpacing.sm)
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        let isSelected = vm.activeGoal?.id == goal.id

        return HStack(spacing: LKSpacing.sm) {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.labelSecondary.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                    .font(LKFont.body)
                    .foregroundColor(.labelPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(goal.allLeafTasks.count) tasks")
                    Text("·")
                    Text("\(Int(goal.overallProgress * 100))%")
                    if let dl = goal.targetDeadline {
                        Text("·")
                        Text(dl.formattedDDMMYYYY)
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
                .font(LKFont.caption)
                .foregroundColor(.labelSecondary)
            }

            Spacer()

            if vm.isGoalActive(goal) {
                GlowingActiveBadge(title: "ACTIVE", size: 6)
            } else {
                Button {
                    vm.setActiveGoal(goal)
                } label: {
                    Text("Make Active")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Set as Active Goal")
            }

            // Quick Edit Goal Button
            Button {
                activeSheet = .editGoal(goal)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.labelSecondary)
                    .padding(4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Edit Goal")

            // Direct Delete Goal Button (No 3 dots, no arrow)
            Button {
                vm.deleteGoal(id: goal.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Delete Goal")
        }
        .padding(LKSpacing.sm)
        .background(
            isSelected
            ? Color(NSColor.selectedControlColor).opacity(0.12)
            : Color.clear
        )
        .cornerRadius(LKRadius.sm)
        .contentShape(Rectangle())
        .onTapGesture { vm.setActiveGoal(goal) }
    }

    // MARK: - Main Content

    private func mainContent(goal: Goal) -> some View {
        VStack(spacing: 0) {
            // Header Toolbar
            HStack(spacing: LKSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(goal.name)
                            .font(LKFont.title2)
                            .foregroundColor(.labelPrimary)

                        if vm.isGoalActive(goal) {
                            GlowingActiveBadge(title: "ACTIVE GOAL")
                        } else {
                            Button {
                                vm.setActiveGoal(goal)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle")
                                    Text("Make Active")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .help("Set this as your active goal")
                        }

                        // Explicit Edit Goal Button (Neutral styling, no blue border)
                        Button {
                            activeSheet = .editGoal(goal)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                Text("Edit Goal")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.labelSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(NSColor.controlColor))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .help("Edit Goal Name and Deadline")

                        // Direct Delete Goal Button (No 3 dots, no arrow)
                        Button {
                            vm.deleteGoal(id: goal.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(5)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .help("Delete Goal")
                    }

                    if let dl = goal.targetDeadline {
                        HStack(spacing: 4) {
                            Text("Target Deadline: \(dl.formattedDDMMYYYY)")
                            if let days = goal.daysRemaining {
                                Text("(\(days) days remaining)")
                                    .foregroundColor(days < 14 ? .orange : .labelSecondary)
                            }
                        }
                        .font(LKFont.caption)
                        .foregroundColor(.labelSecondary)
                    }
                }

                Spacer()

                ProgressRing(
                    progress: goal.overallProgress,
                    lineWidth: 4,
                    size: 32,
                    color: .accentColor,
                    showLabel: false
                )
                Text("\(Int(goal.overallProgress * 100))%")
                    .font(LKFont.headline)
                    .foregroundColor(.accentColor)

                Button {
                    activeSheet = .addCategory(goalId: goal.id)
                } label: {
                    Label("Add Category", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
            }
            .padding(LKSpacing.md)

            Divider()

            // Categories & Tasks List
            if goal.categories.isEmpty {
                EmptyStateView(
                    icon: "folder.badge.plus",
                    title: "No categories yet",
                    message: "Create categories like Writing, Research, or Milestone checkpoints to organize your tasks.",
                    action: { activeSheet = .addCategory(goalId: goal.id) },
                    actionLabel: "Add Category"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: LKSpacing.md) {
                        ForEach(goal.categories) { category in
                            categorySection(category: category, goalId: goal.id)
                        }
                    }
                    .padding(LKSpacing.md)
                }
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(category: Category, goalId: UUID) -> some View {
        VStack(spacing: 0) {
            // Category Header Bar
            HStack(spacing: LKSpacing.sm) {
                Circle()
                    .fill(Color(hex: category.colorHex) ?? .accentColor)
                    .frame(width: 10, height: 10)

                Text(category.name)
                    .font(LKFont.headline)
                    .foregroundColor(.labelPrimary)

                Text("\(category.tasks.count)")
                    .font(LKFont.caption)
                    .foregroundColor(.labelSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.separatorColor).opacity(0.3))
                    .cornerRadius(8)

                Spacer()

                // Category progress
                ProgressRing(
                    progress: category.progress,
                    lineWidth: 3,
                    size: 22,
                    color: Color(hex: category.colorHex) ?? .accentColor,
                    showLabel: false
                )

                // Add Detailed Task Button
                Button {
                    activeSheet = .addTask(goalId: goalId, categoryId: category.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add Task")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Add detailed task with deadline and subtasks")

                // Edit Category Button (No 3 dots, no arrow)
                Button {
                    activeSheet = .editCategory(goalId: goalId, category: category)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(.labelSecondary)
                        .padding(5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Edit Category")

                // Direct Delete Category Button (No 3 dots, no arrow)
                Button {
                    vm.deleteCategory(id: category.id, from: goalId)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(5)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Delete Category")
            }
            .padding(LKSpacing.sm)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(LKRadius.sm)

            // Tasks List
            VStack(spacing: 2) {
                // Existing Tasks
                ForEach(category.tasks) { task in
                    TaskRowView(
                        task: task,
                        categoryId: category.id,
                        goalId: goalId,
                        onEdit: {
                            activeSheet = .editTask(goalId: goalId, categoryId: category.id, task: task)
                        }
                    )
                    .environmentObject(vm)
                }

                // Inline Quick-Add Task Input Bar
                inlineQuickAddTaskBar(category: category, goalId: goalId)
            }
            .padding(.leading, LKSpacing.sm)
            .padding(.top, 4)
        }
        .padding(LKSpacing.sm)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(LKRadius.md)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Inline Quick-Add Task Bar

    private func inlineQuickAddTaskBar(category: Category, goalId: UUID) -> some View {
        let binding = Binding<String>(
            get: { inlineNewTaskText[category.id] ?? "" },
            set: { inlineNewTaskText[category.id] = $0 }
        )

        return HStack(spacing: LKSpacing.sm) {
            Image(systemName: "plus.circle")
                .foregroundColor(.accentColor)
                .font(.system(size: 14))

            TextField("Add task to \"\(category.name)\"... (Press Return to save)", text: binding)
                .textFieldStyle(.plain)
                .font(LKFont.body)
                .onSubmit {
                    submitQuickTask(category: category, goalId: goalId)
                }

            if !(inlineNewTaskText[category.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Save") {
                    submitQuickTask(category: category, goalId: goalId)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, LKSpacing.md)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(LKRadius.sm)
    }

    private func submitQuickTask(category: Category, goalId: UUID) {
        guard let text = inlineNewTaskText[category.id]?.trimmingCharacters(in: .whitespaces),
              !text.isEmpty else { return }

        let task = Task(title: text)
        vm.addTask(task, to: category.id, in: goalId)
        inlineNewTaskText[category.id] = ""
    }
}

// MARK: - TaskRowView

struct TaskRowView: View {
    @EnvironmentObject var vm: AppViewModel
    let task: Task
    let categoryId: UUID
    let goalId: UUID
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: LKSpacing.sm) {
                // Completion toggle
                Button {
                    vm.toggleTaskStatus(task.id, in: categoryId, goalId: goalId)
                } label: {
                    Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.status == .completed ? .green : .labelSecondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .focusable(false)

                // Milestone flag
                if task.isMilestone {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(LKFont.body)
                        .foregroundColor(task.status == .completed ? .labelSecondary : .labelPrimary)
                        .strikethrough(task.status == .completed)
                        .lineLimit(1)

                    if !task.subtasks.isEmpty {
                        let done = task.subtasks.filter { $0.status == .completed }.count
                        Text("\(done)/\(task.subtasks.count) subtasks")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                    }
                }

                Spacer()

                if let dl = task.deadline {
                    Text(dl.formattedDDMMYYYY)
                        .font(LKFont.mono)
                        .foregroundColor(task.isOverdue ? .red : .labelSecondary)
                }

                StatusBadge(status: task.status)
                PriorityBadge(priority: task.priority)

                // Button to make task active
                Button {
                    vm.toggleActiveTask(task)
                } label: {
                    Image(systemName: vm.isTaskActive(task) ? "target" : "scope")
                        .font(.system(size: 12))
                        .foregroundColor(vm.isTaskActive(task) ? .green : .labelSecondary.opacity(0.5))
                        .padding(4)
                        .background(vm.isTaskActive(task) ? Color.green.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(vm.isTaskActive(task) ? "Active Task (Click to unset)" : "Set as Active Task")

                // Edit Task Button
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(.labelSecondary)
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Edit task")

                // Direct Delete Task Button (No 3 dots, no arrow)
                Button {
                    vm.deleteTask(id: task.id, from: categoryId, goalId: goalId)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Delete task")
            }
            .padding(.horizontal, LKSpacing.md)
            .padding(.vertical, LKSpacing.sm)

            // Subtasks
            if !task.subtasks.isEmpty {
                ForEach(task.subtasks) { sub in
                    subtaskRow(sub)
                }
            }

            Divider()
                .padding(.leading, 36)
        }
    }

    private func subtaskRow(_ sub: Task) -> some View {
        HStack(spacing: LKSpacing.sm) {
            Spacer().frame(width: 24)

            Image(systemName: sub.status == .completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(sub.status == .completed ? .green : .labelSecondary.opacity(0.7))
                .font(.system(size: 13))

            Text(sub.title)
                .font(LKFont.caption)
                .foregroundColor(sub.status == .completed ? .labelSecondary : .labelPrimary)
                .strikethrough(sub.status == .completed)

            Spacer()
        }
        .padding(.horizontal, LKSpacing.md)
        .padding(.vertical, 3)
    }
}
