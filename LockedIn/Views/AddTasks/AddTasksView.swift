// MARK: - AddTasksView.swift
// Tab 2: Full goal, category, task, and subtask management.
// All labels are generalized — no domain assumptions.

import SwiftUI

struct AddTasksView: View {
    @EnvironmentObject var vm: AppViewModel

    // Sheet states
    @State private var showAddGoal: Bool = false
    @State private var showAddCategory: Bool = false
    @State private var showAddTask: Bool = false
    @State private var editingGoal: Goal? = nil
    @State private var editingCategory: Category? = nil
    @State private var editingTask: Task? = nil
    @State private var selectedCategoryId: UUID? = nil
    @State private var expandedCategories: Set<UUID> = []

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar: goal selector
            goalSidebar
                .frame(width: 220)
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
                    action: { showAddGoal = true },
                    actionLabel: "Create Goal"
                )
            }
        }
        .sheet(isPresented: $showAddGoal) {
            GoalFormSheet(editingGoal: nil)
                .environmentObject(vm)
        }
        .sheet(item: $editingGoal) { goal in
            GoalFormSheet(editingGoal: goal)
                .environmentObject(vm)
        }
        .sheet(isPresented: $showAddCategory) {
            if let goalId = vm.activeGoal?.id {
                CategoryFormSheet(goalId: goalId, editingCategory: nil)
                    .environmentObject(vm)
            }
        }
        .sheet(item: $editingCategory) { category in
            if let goalId = vm.activeGoal?.id {
                CategoryFormSheet(goalId: goalId, editingCategory: category)
                    .environmentObject(vm)
            }
        }
        .sheet(isPresented: $showAddTask) {
            if let goalId = vm.activeGoal?.id, let catId = selectedCategoryId {
                TaskFormSheet(goalId: goalId, categoryId: catId, editingTask: nil)
                    .environmentObject(vm)
            }
        }
        .sheet(item: $editingTask) { task in
            if let goalId = vm.activeGoal?.id, let catId = selectedCategoryId {
                TaskFormSheet(goalId: goalId, categoryId: catId, editingTask: task)
                    .environmentObject(vm)
            }
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
                Button { showAddGoal = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add Goal")
            }
            .padding(LKSpacing.md)

            Divider()

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(vm.goals) { goal in
                        goalRow(goal)
                    }
                }
                .padding(LKSpacing.sm)
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        HStack(spacing: LKSpacing.sm) {
            Circle()
                .fill(vm.activeGoal?.id == goal.id ? Color.accentColor : Color.labelSecondary.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                    .font(LKFont.body)
                    .foregroundColor(.labelPrimary)
                    .lineLimit(1)

                Text("\(goal.allLeafTasks.count) tasks · \(Int(goal.overallProgress * 100))%")
                    .font(LKFont.caption)
                    .foregroundColor(.labelSecondary)
            }

            Spacer()

            Menu {
                Button("Set as Active") { vm.setActiveGoal(goal) }
                Button("Edit") { editingGoal = goal }
                Divider()
                Button("Delete", role: .destructive) { vm.deleteGoal(id: goal.id) }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.labelSecondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(LKSpacing.sm)
        .background(
            vm.activeGoal?.id == goal.id
            ? Color.accentColor.opacity(0.08)
            : Color.clear
        )
        .cornerRadius(LKRadius.sm)
        .onTapGesture { vm.setActiveGoal(goal) }
    }

    // MARK: - Main Content

    private func mainContent(goal: Goal) -> some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(goal.name)
                    .font(LKFont.title2)
                    .foregroundColor(.labelPrimary)

                Spacer()

                ProgressRing(
                    progress: goal.overallProgress,
                    lineWidth: 5,
                    size: 32,
                    color: .accentColor,
                    showLabel: false
                )
                Text("\(Int(goal.overallProgress * 100))%")
                    .font(LKFont.headline)
                    .foregroundColor(.accentColor)

                Button {
                    showAddCategory = true
                } label: {
                    Label("Add Category", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
            }
            .padding(LKSpacing.md)

            Divider()

            // Categories & Tasks
            if goal.categories.isEmpty {
                EmptyStateView(
                    icon: "folder.badge.plus",
                    title: "No categories yet",
                    message: "Organize your tasks into categories like Writing, Prep, or Training.",
                    action: { showAddCategory = true },
                    actionLabel: "Add Category"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: LKSpacing.md, pinnedViews: [.sectionHeaders]) {
                        ForEach(goal.categories) { category in
                            categorySection(category: category, goalId: goal.id)
                        }
                    }
                    .padding(LKSpacing.md)
                }
            }
        }
    }

    private func categorySection(category: Category, goalId: UUID) -> some View {
        let isExpanded = expandedCategories.contains(category.id)

        return VStack(spacing: 0) {
            // Category header
            HStack(spacing: LKSpacing.sm) {
                Button {
                    if isExpanded {
                        expandedCategories.remove(category.id)
                    } else {
                        expandedCategories.insert(category.id)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.labelSecondary)
                }
                .buttonStyle(.plain)

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
                    .background(Color(NSColor.separatorColor).opacity(0.5))
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

                Menu {
                    Button("Add Task") {
                        selectedCategoryId = category.id
                        showAddTask = true
                    }
                    Button("Edit Category") { editingCategory = category }
                    Divider()
                    Button("Delete Category", role: .destructive) {
                        vm.deleteCategory(id: category.id, from: goalId)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.labelSecondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)

                Button {
                    selectedCategoryId = category.id
                    showAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add task to \(category.name)")
            }
            .padding(LKSpacing.sm)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(LKRadius.sm)

            // Tasks
            if isExpanded || !expandedCategories.isEmpty {
                if category.tasks.isEmpty {
                    HStack {
                        Text("No tasks yet")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                            .italic()
                        Spacer()
                        Button("Add Task") {
                            selectedCategoryId = category.id
                            showAddTask = true
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                        .font(LKFont.caption)
                    }
                    .padding(.horizontal, LKSpacing.lg)
                    .padding(.vertical, LKSpacing.sm)
                } else {
                    VStack(spacing: 2) {
                        ForEach(category.tasks) { task in
                            TaskRowView(
                                task: task,
                                categoryId: category.id,
                                goalId: goalId,
                                onEdit: {
                                    selectedCategoryId = category.id
                                    editingTask = task
                                }
                            )
                            .environmentObject(vm)
                        }
                    }
                    .padding(.leading, LKSpacing.lg)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(LKRadius.md)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        .onAppear {
            // Expand all categories by default
            expandedCategories.insert(category.id)
        }
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
                    Text(dl.formatted(date: .abbreviated, time: .omitted))
                        .font(LKFont.caption)
                        .foregroundColor(task.isOverdue ? .red : .labelSecondary)
                }

                StatusBadge(status: task.status)
                PriorityBadge(priority: task.priority)

                Menu {
                    Button("Edit") { onEdit() }
                    Divider()
                    Button("Delete", role: .destructive) {
                        vm.deleteTask(id: task.id, from: categoryId, goalId: goalId)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.labelSecondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
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
                .padding(.leading, 44)
        }
    }

    private func subtaskRow(_ sub: Task) -> some View {
        HStack(spacing: LKSpacing.sm) {
            Spacer().frame(width: 28)

            Image(systemName: sub.status == .completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(sub.status == .completed ? .green : .labelSecondary.opacity(0.7))
                .font(.system(size: 14))

            Text(sub.title)
                .font(LKFont.caption)
                .foregroundColor(sub.status == .completed ? .labelSecondary : .labelPrimary)
                .strikethrough(sub.status == .completed)

            Spacer()
        }
        .padding(.horizontal, LKSpacing.md)
        .padding(.vertical, 4)
    }
}

// MARK: - Color(hex:) extension

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8) & 0xFF) / 255
        let b = Double(val & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
