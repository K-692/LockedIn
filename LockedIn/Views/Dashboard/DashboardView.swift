// MARK: - DashboardView.swift
// Tab 1: Shows countdown, overall progress, active task, and upcoming work.
// Dates formatted as YY-MM-DD throughout.

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var editingGoal: Goal? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: LKSpacing.lg) {

                // Goal header
                if let goal = vm.activeGoal {
                    goalHeaderCard(goal: goal)
                    progressCard(goal: goal)
                    activeTaskCard(goal: goal)
                    upcomingTasksList(goal: goal)
                    milestonesCard(goal: goal)
                } else {
                    emptyGoalState
                }
            }
            .padding(LKSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $editingGoal) { goal in
            GoalFormSheet(editingGoal: goal)
                .environmentObject(vm)
        }
    }

    // MARK: - Cards

    private func goalHeaderCard(goal: Goal) -> some View {
        HStack(alignment: .top, spacing: LKSpacing.md) {
            VStack(alignment: .leading, spacing: LKSpacing.xs) {
                HStack(spacing: 6) {
                    Text("ACTIVE GOAL")
                        .font(LKFont.caption)
                        .foregroundColor(.labelSecondary)
                        .tracking(0.8)

                    Button {
                        editingGoal = goal
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                            Text("Edit")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Edit Goal Name & Target Deadline")
                }

                Text(goal.name)
                    .font(LKFont.largeTitle)
                    .foregroundColor(.labelPrimary)
                    .lineLimit(2)

                if let deadline = goal.targetDeadline {
                    Label("Target: \(deadline.formattedYYMMDD)", systemImage: "calendar")
                        .font(LKFont.caption)
                        .foregroundColor(.labelSecondary)
                }
            }

            Spacer()

            CountdownDisplay(
                daysRemaining: goal.daysRemaining,
                targetDate: goal.targetDeadline,
                isOverdue: goal.isOverdue
            )
        }
        .cardStyle()
    }

    private func progressCard(goal: Goal) -> some View {
        HStack(spacing: LKSpacing.xl) {
            // Overall ring
            VStack(spacing: LKSpacing.xs) {
                ProgressRing(
                    progress: goal.overallProgress,
                    lineWidth: 10,
                    size: 80,
                    color: .accentColor,
                    showLabel: true,
                    labelFont: LKFont.headline
                )
                Text("Overall Progress")
                    .font(LKFont.caption)
                    .foregroundColor(.labelSecondary)
            }

            Divider()
                .frame(height: 60)

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LKSpacing.sm) {
                statCell(value: "\(goal.allLeafTasks.filter { $0.status == .completed }.count)",
                         label: "Completed",
                         icon: "checkmark.circle.fill",
                         color: .green)
                statCell(value: "\(goal.allLeafTasks.filter { $0.status == .inProgress }.count)",
                         label: "In Progress",
                         icon: "circle.lefthalf.filled",
                         color: .blue)
                statCell(value: "\(goal.allLeafTasks.filter { $0.status == .notStarted }.count)",
                         label: "Not Started",
                         icon: "circle",
                         color: .gray)
                statCell(value: "\(goal.allTasks.filter { $0.isMilestone }.count)",
                         label: "Milestones",
                         icon: "flag.fill",
                         color: .yellow)
            }
        }
        .cardStyle()
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: LKSpacing.xs) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(LKFont.headline)
                    .foregroundColor(.labelPrimary)
                Text(label)
                    .font(LKFont.caption)
                    .foregroundColor(.labelSecondary)
            }
        }
    }

    private func activeTaskCard(goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            SectionHeader(title: "Active Task")

            if let task = vm.nextUpcomingTask {
                HStack(spacing: LKSpacing.md) {
                    Image(systemName: task.isMilestone ? "flag.fill" : "circle.fill")
                        .foregroundColor(task.isMilestone ? .yellow : .accentColor)
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: LKSpacing.xs) {
                        Text(task.title)
                            .font(LKFont.headline)
                            .foregroundColor(.labelPrimary)

                        if !task.notes.isEmpty {
                            Text(task.notes)
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                                .lineLimit(2)
                        }

                        HStack(spacing: LKSpacing.sm) {
                            StatusBadge(status: task.status)
                            PriorityBadge(priority: task.priority)
                            if let dl = task.deadline {
                                Label("Due: \(dl.formattedYYMMDD)", systemImage: "calendar")
                                    .font(LKFont.caption)
                                    .foregroundColor(task.isOverdue ? .red : .labelSecondary)
                            }
                        }
                    }

                    Spacer()

                    // Quick Toggle Complete Button
                    Button {
                        if let cat = goal.categories.first(where: { c in c.tasks.contains(where: { $0.id == task.id }) }) {
                            vm.toggleTaskStatus(task.id, in: cat.id, goalId: goal.id)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                            Text(task.status == .completed ? "Done" : "Mark Complete")
                                .font(LKFont.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(task.status == .completed ? Color.green.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                        .foregroundColor(task.status == .completed ? .green : .labelPrimary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle task completion")
                }
                .padding(LKSpacing.md)
                .background(Color.accentColor.opacity(0.05))
                .cornerRadius(LKRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: LKRadius.md)
                        .stroke(Color(NSColor.separatorColor).opacity(0.25), lineWidth: 1)
                )
            } else {
                Text("All tasks completed! 🎉")
                    .font(LKFont.body)
                    .foregroundColor(.labelSecondary)
                    .padding(LKSpacing.md)
            }
        }
        .cardStyle()
    }

    private func upcomingTasksList(goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            SectionHeader(title: "Upcoming Tasks")

            let upcoming = goal.allTasks
                .filter { $0.status != .completed }
                .prefix(5)

            if upcoming.isEmpty {
                Text("No upcoming tasks.")
                    .font(LKFont.body)
                    .foregroundColor(.labelSecondary)
            } else {
                ForEach(Array(upcoming)) { task in
                    upcomingTaskRow(task: task)
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func upcomingTaskRow(task: Task) -> some View {
        HStack(spacing: LKSpacing.sm) {
            Image(systemName: task.isMilestone ? "flag.fill" : task.status.icon)
                .foregroundColor(task.isMilestone ? .yellow : .labelSecondary)
                .frame(width: 16)

            Text(task.title)
                .font(LKFont.body)
                .foregroundColor(.labelPrimary)
                .lineLimit(1)

            Spacer()

            if let dl = task.deadline {
                Text(dl.formattedYYMMDD)
                    .font(LKFont.caption)
                    .foregroundColor(task.isOverdue ? .red : .labelSecondary)
            }

            PriorityBadge(priority: task.priority)
        }
        .padding(.vertical, LKSpacing.xs)

        Divider()
    }

    private func milestonesCard(goal: Goal) -> some View {
        let milestones = goal.allTasks.filter { $0.isMilestone }
        guard !milestones.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: LKSpacing.sm) {
                SectionHeader(title: "Milestones")
                ForEach(milestones) { m in
                    HStack(spacing: LKSpacing.sm) {
                        Image(systemName: m.status == .completed ? "flag.fill" : "flag")
                            .foregroundColor(m.status == .completed ? .yellow : .labelSecondary)
                        Text(m.title)
                            .font(LKFont.body)
                            .foregroundColor(.labelPrimary)
                            .strikethrough(m.status == .completed)
                        Spacer()
                        if let dl = m.deadline {
                            Text(dl.formattedYYMMDD)
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                        }
                        StatusBadge(status: m.status)
                    }
                    .padding(.vertical, 2)
                }
            }
            .cardStyle()
        )
    }

    // MARK: - Empty State

    private var emptyGoalState: some View {
        VStack(spacing: LKSpacing.md) {
            AppIconView(size: 64, cornerRadius: 14)

            Text("No goal yet")
                .font(LKFont.title2)
                .foregroundColor(.labelPrimary)

            Text("Define your first goal in the Add Tasks tab to get started.")
                .font(LKFont.body)
                .foregroundColor(.labelSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                vm.selectedTab = 1
            } label: {
                Text("Add Goal")
                    .font(LKFont.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(LKSpacing.xl)
    }
}
