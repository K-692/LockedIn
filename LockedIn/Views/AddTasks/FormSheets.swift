// MARK: - FormSheets.swift
// Modal form sheets for creating and editing goals, categories, and tasks.
// All dates formatted strictly as YY-MM-DD.

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

                    Toggle("Set a target deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker("Target Deadline",
                                   selection: $targetDeadline,
                                   in: Date()...,
                                   displayedComponents: .date)

                        HStack {
                            Text("Selected Target Date:")
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                            Text(targetDeadline.formattedYYMMDD)
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
                Spacer()
                Button(isEditing ? "Save Changes" : "Create Goal") {
                    commit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(LKSpacing.md)
        }
        .frame(width: 440, height: 320)
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
                Spacer()
                Button(isEditing ? "Save Changes" : "Create Category") { commit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(LKSpacing.md)
        }
        .frame(width: 420, height: 280)
        .onAppear {
            if let c = editingCategory {
                name     = c.name
                colorHex = c.colorHex
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
    @State private var deadline: Date = Date()
    @State private var isMilestone: Bool = false
    @State private var subtaskTitles: [String] = []
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
                            Text("Target Date:")
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                            Text(deadline.formattedYYMMDD)
                                .font(LKFont.mono)
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                Section("Subtasks") {
                    ForEach(subtaskTitles.indices, id: \.self) { idx in
                        HStack {
                            Image(systemName: "circle")
                                .foregroundColor(.labelSecondary)
                                .font(.system(size: 12))
                            TextField("Subtask \(idx + 1)", text: $subtaskTitles[idx])
                            Spacer()
                            Button {
                                subtaskTitles.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
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
                Spacer()
                Button(isEditing ? "Save Changes" : "Add Task") { commit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(LKSpacing.md)
        }
        .frame(width: 480, height: 580)
        .onAppear {
            if let t = editingTask {
                title         = t.title
                notes         = t.notes
                status        = t.status
                priority      = t.priority
                hasDeadline   = t.deadline != nil
                deadline      = t.deadline ?? Date()
                isMilestone   = t.isMilestone
                subtaskTitles = t.subtasks.map { $0.title }
            }
        }
    }

    private func addSubtask() {
        let trimmed = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        subtaskTitles.append(trimmed)
        newSubtask = ""
    }

    private func commit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let subs = subtaskTitles
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { Task(title: $0) }

        if var t = editingTask {
            t.title       = trimmed
            t.notes       = notes
            t.status      = status
            t.priority    = priority
            t.deadline    = hasDeadline ? deadline : nil
            t.isMilestone = isMilestone
            t.subtasks    = subs
            vm.updateTask(t, in: categoryId, goalId: goalId)
        } else {
            var t = Task(title: trimmed)
            t.notes       = notes
            t.status      = status
            t.priority    = priority
            t.deadline    = hasDeadline ? deadline : nil
            t.isMilestone = isMilestone
            t.subtasks    = subs
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

    var body: some View {
        Circle()
            .fill(Color(hex: hex) ?? .accentColor)
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
            )
            .onTapGesture(perform: onSelect)
    }
}

