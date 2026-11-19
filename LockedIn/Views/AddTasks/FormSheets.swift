// MARK: - FormSheets.swift
// Modal form sheets for creating and editing goals, categories, and tasks.
// All dates formatted strictly as DD-MM-YYYY. Return confirms, Escape cancels.

import SwiftUI

// MARK: - GoalFormSheet

struct GoalFormSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let editingGoal: Goal?

    @State private var name: String = ""
    @State private var hasDeadline: Bool = false
    @State private var targetDeadline: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    var isEditing: Bool { editingGoal != nil }

    var body: some View {
        VStack(spacing: 0) {
            formHeader(title: isEditing ? "Edit Goal" : "New Goal")

            Form {
                Section("Goal Details") {
                    TextField("Goal name (e.g. Complete my project)", text: $name)
                        .onSubmit(commit)

                    Toggle("Set a target deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker("Target Deadline",
                                   selection: $targetDeadline,
                                   in: min(Calendar.current.startOfDay(for: Date()), editingGoal?.targetDeadline ?? .distantFuture)...,
                                   displayedComponents: .date)

                        HStack {
                            Text("Selected Target Date (DD-MM-YYYY):")
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                            Text(targetDeadline.formattedDDMMYYYY)
                                .font(LKFont.mono)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save Changes" : "Create Goal") {
                    commit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(LKSpacing.md)
        }
        .frame(width: 460, height: 340)
        .onAppear {
            if let g = editingGoal {
                name = g.name
                hasDeadline = g.targetDeadline != nil
                targetDeadline = g.targetDeadline ?? targetDeadline
            }
        }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if var g = editingGoal {
            g.name           = trimmed
            g.targetDeadline = hasDeadline ? targetDeadline : nil
            vm.updateGoal(g)
        } else {
            var g = Goal(name: trimmed)
            g.targetDeadline = hasDeadline ? targetDeadline : nil
            vm.addGoal(g)
        }
        dismiss()
    }
}

// MARK: - CategoryFormSheet

struct CategoryFormSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let goalId: UUID
    let editingCategory: Category?

    @State private var name: String = ""
    @State private var colorHex: String = "#5E8FF7"

    private let palette: [String] = [
        "#5E8FF7", "#43C6AC", "#F7971E", "#E96C6C",
        "#A78BFA", "#34D399", "#FBBF24", "#F472B6"
    ]

    var isEditing: Bool { editingCategory != nil }

    var body: some View {
        VStack(spacing: 0) {
            formHeader(title: isEditing ? "Edit Category" : "New Category")

            Form {
                Section("Category Details") {
                    TextField("Name (e.g. Writing, Training, Research)", text: $name)
                        .onSubmit(commit)

                    VStack(alignment: .leading, spacing: LKSpacing.sm) {
                        Text("Color")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                        HStack(spacing: LKSpacing.sm) {
                            ForEach(palette, id: \.self) { hex in
                                ColorSwatchView(
                                    hex: hex,
                                    isSelected: colorHex == hex
                                ) {
                                    colorHex = hex
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save Changes" : "Create Category") { commit() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(LKSpacing.md)
        }
        .frame(width: 440, height: 290)
        .onAppear {
            if let c = editingCategory {
                name     = c.name
                colorHex = c.colorHex
            } else if let goal = vm.goals.first(where: { $0.id == goalId }) {
                // Pick the first colour not already used in this goal.
                let used = Set(goal.categories.map(\.colorHex))
                colorHex = palette.first { !used.contains($0) } ?? palette[goal.categories.count % palette.count]
            }
        }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if var c = editingCategory {
            c.name     = trimmed
            c.colorHex = colorHex
            vm.updateCategory(c, in: goalId)
        } else {
            let c = Category(name: trimmed, colorHex: colorHex)
            vm.addCategory(c, to: goalId)
        }
        dismiss()
    }
}

// MARK: - TaskFormSheet

struct TaskFormSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let goalId: UUID
    let categoryId: UUID
    let editingTask: Task?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var status: TaskStatus = .notStarted
    @State private var priority: TaskPriority = .medium
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var isMilestone: Bool = false
    @State private var subtasks: [Task] = []
    @State private var newSubtask: String = ""

    var isEditing: Bool { editingTask != nil }

    var body: some View {
        VStack(spacing: 0) {
            formHeader(title: isEditing ? "Edit Task" : "New Task")

            Form {
                Section("Task Details") {
                    TextField("Task title", text: $title)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("Options") {
                    Picker("Status", selection: $status) {
                        ForEach(TaskStatus.allCases, id: \.self) { s in
                            Label(s.rawValue, systemImage: s.icon).tag(s)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.icon).tag(p)
                        }
                    }

                    Toggle("Mark as Milestone", isOn: $isMilestone)
                    Toggle("Has Deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker("Deadline Date",
                                   selection: $deadline,
                                   displayedComponents: .date)

                        HStack {
                            Text("Target Date (DD-MM-YYYY):")
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                            Text(deadline.formattedDDMMYYYY)
                                .font(LKFont.mono)
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                Section("Subtasks") {
                    ForEach($subtasks) { $sub in
                        HStack {
                            Button {
                                sub.setStatus(sub.status == .completed ? .notStarted : .completed)
                            } label: {
                                Image(systemName: sub.status == .completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(sub.status == .completed ? .green : .labelSecondary)
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .help("Toggle subtask completion")

                            TextField("Subtask", text: $sub.title)
                                .strikethrough(sub.status == .completed)
                            Spacer()
                            Button {
                                let id = sub.id
                                subtasks.removeAll { $0.id == id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Remove subtask")
                        }
                    }

                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        TextField("Add subtask…", text: $newSubtask)
                            .onSubmit { addSubtask() }
                        Button("Add") { addSubtask() }
                            .buttonStyle(.borderless)
                            .disabled(newSubtask.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save Changes" : "Add Task") { commit() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(LKSpacing.md)
        }
        .frame(width: 500, height: 600)
        .onAppear {
            if let t = editingTask {
                title         = t.title
                notes         = t.notes
                status        = t.status
                priority      = t.priority
                hasDeadline   = t.deadline != nil
                deadline      = t.deadline ?? deadline
                isMilestone   = t.isMilestone
                subtasks      = t.subtasks
            }
        }
    }

    private func addSubtask() {
        let trimmed = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        subtasks.append(Task(title: trimmed))
        newSubtask = ""
    }

    private func commit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Keep subtask identity & completion state; drop blank ones.
        let subs: [Task] = subtasks.compactMap { sub in
            var s = sub
            s.title = s.title.trimmingCharacters(in: .whitespaces)
            return s.title.isEmpty ? nil : s
        }
        // Include a typed-but-not-added subtask instead of silently discarding it.
        let pending = newSubtask.trimmingCharacters(in: .whitespaces)
        let allSubs = pending.isEmpty ? subs : subs + [Task(title: pending)]
        let notesTrimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if var t = editingTask {
            t.title       = trimmed
            t.notes       = notesTrimmed
            t.setStatus(status)
            t.priority    = priority
            t.deadline    = hasDeadline ? deadline : nil
            t.isMilestone = isMilestone
            t.subtasks    = allSubs
            vm.updateTask(t, in: categoryId, goalId: goalId)
        } else {
            var t = Task(title: trimmed)
            t.notes       = notesTrimmed
            t.setStatus(status)
            t.priority    = priority
            t.deadline    = hasDeadline ? deadline : nil
            t.isMilestone = isMilestone
            t.subtasks    = allSubs
            vm.addTask(t, to: categoryId, in: goalId)
        }
        dismiss()
    }
}

// MARK: - Shared header helper

func formHeader(title: String) -> some View {
    HStack {
        Text(title)
            .font(LKFont.title2)
            .foregroundColor(.labelPrimary)
        Spacer()
    }
    .padding(LKSpacing.md)
}

// MARK: - ColorSwatchView

private struct ColorSwatchView: View {
    let hex: String
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                Circle()
                    .fill(Color(hex: hex) ?? .accentColor)
                    .frame(width: 24, height: 24)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(3)
            .overlay(
                Circle().stroke(Color.primary.opacity(isSelected ? 0.6 : (hovering ? 0.25 : 0)), lineWidth: 2)
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(hex)
        .accessibilityLabel("Color \(hex)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
