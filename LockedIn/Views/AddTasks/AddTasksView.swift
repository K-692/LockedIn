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

// MARK: - Pending Deletion

enum PendingDeletion: Identifiable {
    case goal(Goal)
    case category(goalId: UUID, category: Category)
    case task(goalId: UUID, categoryId: UUID, task: Task)

    var id: String {
        switch self {
        case .goal(let g): return "goal-\(g.id)"
        case .category(_, let c): return "category-\(c.id)"
        case .task(_, _, let t): return "task-\(t.id)"
        }
    }

    var title: String {
        switch self {
        case .goal(let g): return "Delete goal \"\(g.name)\"?"
        case .category(_, let c): return "Delete category \"\(c.name)\"?"
        case .task(_, _, let t): return "Delete task \"\(t.title)\"?"
        }
    }

    var message: String {
        switch self {
        case .goal(let g):
            let n = g.allLeafTasks.count
            return "This permanently removes the goal, its \(g.categories.count) categor\(g.categories.count == 1 ? "y" : "ies") and \(n) task\(n == 1 ? "" : "s")."
        case .category(_, let c):
            let n = c.allLeafTasks.count
            return "This permanently removes the category and its \(n) task\(n == 1 ? "" : "s")."
        case .task(_, _, let t):
            return t.subtasks.isEmpty ? "This cannot be undone." : "This also removes its \(t.subtasks.count) subtask\(t.subtasks.count == 1 ? "" : "s")."
        }
    }
}

// MARK: - AddTasksView

struct AddTasksView: View {
    @EnvironmentObject var vm: AppViewModel

    @State private var activeSheet: AddTasksSheet? = nil
    @State private var expandedCategories: Set<UUID> = []
    @State private var inlineNewTaskText: [UUID: String] = [:]
    @State private var pendingDeletion: PendingDeletion? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar: goal selector
            goalSidebar
                .frame(width: 260)
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
        .confirmationDialog(
            pendingDeletion?.title ?? "Delete?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { item in
            Button("Delete", role: .destructive) { performDeletion(item) }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(item.message)
        }
    }

    private func performDeletion(_ item: PendingDeletion) {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch item {
            case .goal(let g):
                vm.deleteGoal(id: g.id)
            case .category(let gid, let c):
                vm.deleteCategory(id: c.id, from: gid)
                inlineNewTaskText[c.id] = nil
            case .task(let gid, let cid, let t):
                vm.deleteTask(id: t.id, from: cid, goalId: gid)
            }
        }
        pendingDeletion = nil
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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.labelPrimary)
                Spacer()
                Button {
                    activeSheet = .addGoal
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Add")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.lkAccentChip)
                .focusable(false)
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .help("Add Goal (⇧⌘N)")
            }
            .padding(.horizontal, LKSpacing.md)
            .padding(.vertical, LKSpacing.sm)

            Divider()

            if vm.goals.isEmpty {
                VStack(spacing: LKSpacing.sm) {
                    Text("No goals yet")
                        .font(LKFont.caption)
                        .foregroundColor(.labelSecondary)
                    Button("Create Goal") { activeSheet = .addGoal }
                        .buttonStyle(.borderless)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(vm.goals) { goal in
                            goalRow(goal)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        let isSelected = vm.activeGoal?.id == goal.id

        return VStack(alignment: .leading, spacing: 6) {
            // Row 1: Status indicator, Goal Title, and Active Badge / Make Active Button
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.labelSecondary.opacity(0.35))
                    .frame(width: 8, height: 8)

                Text(goal.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.labelPrimary)
                    .lineLimit(1)

                Spacer()

                if vm.isGoalActive(goal) {
                    GlowingActiveBadge(title: "ACTIVE", size: 5)
                } else {
                    Button {
                        vm.setActiveGoal(goal)
                    } label: {
                        Text("Make Active")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.lkGreenChip)
                    .focusable(false)
                    .help("Set as Active Goal")
                }
            }

            // Row 2: Metadata (tasks count, percentage, deadline)
            HStack(spacing: 4) {
                Text("\(goal.allLeafTasks.count) task\(goal.allLeafTasks.count == 1 ? "" : "s") · \(Int((goal.overallProgress * 100).rounded()))%")
                if let dl = goal.targetDeadline {
                    Text("·")
                    Text(dl.formattedDDMMYYYY)
                        .font(.system(size: 10, design: .monospaced))
                }
            }
            .font(.system(size: 11))
            .foregroundColor(.labelSecondary)
            .lineLimit(1)

            // Row 3: Action Buttons (Edit & Delete)
            HStack(spacing: 6) {
                Spacer()

                Button {
                    activeSheet = .editGoal(goal)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                        Text("Edit")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(.lkChip)
                .focusable(false)
                .help("Edit Goal")

                Button {
                    pendingDeletion = .goal(goal)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text("Delete")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(.lkDestructiveChip)
                .focusable(false)
                .help("Delete Goal")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { vm.setActiveGoal(goal) } }
        .contextMenu {
            if !isSelected { Button("Make Active") { vm.setActiveGoal(goal) } }
            Button("Edit Goal…") { activeSheet = .editGoal(goal) }
            Button("Add Category…") { activeSheet = .addCategory(goalId: goal.id) }
            Divider()
            Button("Delete Goal…", role: .destructive) { pendingDeletion = .goal(goal) }
        }
        .help(isSelected ? goal.name : "Click to make \"\(goal.name)\" active")
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
                            .lineLimit(1)
                            .truncationMode(.tail)

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
                            }
                            .buttonStyle(.lkGreenChip)
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
                        }
                        .buttonStyle(.lkChip)
                        .focusable(false)
                        .help("Edit Goal Name and Deadline")

                        // Direct Delete Goal Button (No 3 dots, no arrow)
                        Button {
                            pendingDeletion = .goal(goal)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.lkDestructiveChip)
                        .focusable(false)
                        .help("Delete Goal")
                    }

                    if let dl = goal.targetDeadline {
                        HStack(spacing: 4) {
                            Text("Target Deadline: \(dl.formattedDDMMYYYY)")
                            if let days = goal.daysRemaining {
                                Text(days < 0 ? "(overdue by \(-days) day\(days == -1 ? "" : "s"))" : "(\(days) day\(days == 1 ? "" : "s") remaining)")
                                    .foregroundColor(days < 0 ? .red : (days < 14 ? .orange : .labelSecondary))
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
                Text("\(Int((goal.overallProgress * 100).rounded()))%")
                    .font(LKFont.headline)
                    .foregroundColor(.accentColor)
                    .frame(minWidth: 40, alignment: .leading)

                Button {
                    activeSheet = .addCategory(goalId: goal.id)
                } label: {
                    Label("Add Category", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("n", modifiers: [.command, .option])
                .help("Add Category (⌥⌘N)")
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

                Text("\(category.allLeafTasks.filter { $0.status == .completed }.count)/\(category.allLeafTasks.count)")
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
                }
                .buttonStyle(.lkAccentChip)
                .focusable(false)
                .help("Add detailed task with deadline and subtasks")

                // Edit Category Button (No 3 dots, no arrow)
                Button {
                    activeSheet = .editCategory(goalId: goalId, category: category)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.lkChip)
                .focusable(false)
                .help("Edit Category")

                // Direct Delete Category Button (No 3 dots, no arrow)
                Button {
                    pendingDeletion = .category(goalId: goalId, category: category)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.lkDestructiveChip)
                .focusable(false)
                .help("Delete Category")
            }
            .padding(LKSpacing.sm)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(LKRadius.sm)

            // Tasks List
            VStack(spacing: 2) {
                // Existing Tasks
                ForEach(category.tasks.sortedByDeadline()) { task in
                    TaskRowView(
                        task: task,
                        categoryId: category.id,
                        goalId: goalId,
                        onEdit: {
                            activeSheet = .editTask(goalId: goalId, categoryId: category.id, task: task)
                        },
                        onDelete: {
                            if task.subtasks.isEmpty {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    vm.deleteTask(id: task.id, from: category.id, goalId: goalId)
                                }
                            } else {
                                pendingDeletion = .task(goalId: goalId, categoryId: category.id, task: task)
                            }
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

            TextField("Add a task to \"\(category.name)\" — press Return to save", text: binding)
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
        withAnimation(.easeInOut(duration: 0.15)) {
            vm.addTask(task, to: category.id, in: goalId)
        }
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
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: LKSpacing.sm) {
                // Completion toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        vm.toggleTaskStatus(task.id, in: categoryId, goalId: goalId)
                    }
                } label: {
                    Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.status == .completed ? .green : .labelSecondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(task.status == .completed ? "Mark as not done" : "Mark complete")

                // Milestone flag
                if task.isMilestone {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                        .help("Milestone")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(LKFont.body)
                        .foregroundColor(task.status == .completed ? .labelSecondary : .labelPrimary)
                        .strikethrough(task.status == .completed)
                        .lineLimit(1)
                        .help(task.notes.isEmpty ? task.title : task.notes)

                    if !task.subtasks.isEmpty {
                        let done = task.subtasks.filter { $0.status == .completed }.count
                        Text("\(done)/\(task.subtasks.count) subtasks")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                    }
                }

                Spacer(minLength: 4)

                if let dl = task.deadline {
                    Text(dl.formattedDDMMYYYY)
                        .font(LKFont.mono)
                        .foregroundColor(task.isOverdue ? .red : .labelSecondary)
                        .help(task.isOverdue ? "Overdue" : "Deadline")
                }

                StatusBadge(status: task.status)
                PriorityBadge(priority: task.priority)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.lkChip)
                .focusable(false)
                .help("Edit task")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.lkDestructiveChip)
                .focusable(false)
                .help("Delete task")
            }
            .padding(.horizontal, LKSpacing.md)
            .padding(.vertical, LKSpacing.sm)
            .contentShape(Rectangle())
            .hoverHighlight()
            .onTapGesture(count: 2, perform: onEdit)
            .contextMenu {
                Button(task.status == .completed ? "Mark as Not Done" : "Mark Complete") {
                    vm.toggleTaskStatus(task.id, in: categoryId, goalId: goalId)
                }
                Menu("Set Status") {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        Button(status.rawValue) { setStatus(status) }
                    }
                }
                Menu("Set Priority") {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Button(p.rawValue) {
                            var t = task
                            t.priority = p
                            vm.updateTask(t, in: categoryId, goalId: goalId)
                        }
                    }
                }
                Divider()
                Button("Edit Task…", action: onEdit)
                Button("Delete Task", role: .destructive, action: onDelete)
            }

            // Subtasks (toggle & delete inline)
            ForEach(task.subtasks) { sub in
                subtaskRow(sub)
            }

            Divider()
                .padding(.leading, 36)
        }
    }

    private func setStatus(_ status: TaskStatus) {
        var t = task
        t.setStatus(status)
        vm.updateTask(t, in: categoryId, goalId: goalId)
    }

    private func subtaskRow(_ sub: Task) -> some View {
        HStack(spacing: LKSpacing.sm) {
            Spacer().frame(width: 24)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    vm.toggleTaskStatus(sub.id, in: categoryId, goalId: goalId)
                }
            } label: {
                Image(systemName: sub.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(sub.status == .completed ? .green : .labelSecondary.opacity(0.8))
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help(sub.status == .completed ? "Mark as not done" : "Mark complete")

            Text(sub.title)
                .font(LKFont.caption)
                .foregroundColor(sub.status == .completed ? .labelSecondary : .labelPrimary)
                .strikethrough(sub.status == .completed)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    vm.deleteTask(id: sub.id, from: categoryId, goalId: goalId)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.lkChip)
            .help("Remove subtask")
        }
        .padding(.horizontal, LKSpacing.md)
        .padding(.vertical, 3)
        .hoverHighlight()
    }
}
