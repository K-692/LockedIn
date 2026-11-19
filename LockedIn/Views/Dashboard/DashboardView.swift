// MARK: - DashboardView.swift
// Tab 1: Shows countdown, overall progress, active task, and upcoming work.
// Dates formatted as YY-MM-DD throughout.

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var editingGoal: Goal? = nil
    @State private var showNewGoal = false

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
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $editingGoal) { goal in
            GoalFormSheet(editingGoal: goal)
                .environmentObject(vm)
        }
        .sheet(isPresented: $showNewGoal) {
            GoalFormSheet(editingGoal: nil)
                .environmentObject(vm)
        }
    }

    // MARK: - Cards

    private func goalHeaderCard(goal: Goal) -> some View {
        HStack(alignment: .top, spacing: LKSpacing.md) {
            VStack(alignment: .leading, spacing: LKSpacing.xs) {
                HStack(spacing: 8) {
                    // Glowing Green Active Goal Badge
                    GlowingActiveBadge(title: "ACTIVE GOAL")

                    Button {
                        editingGoal = goal
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                            Text("Edit")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.lkChip)
                    .focusable(false)
                    .help("Edit Goal Name & Target Deadline")
                }

                Text(goal.name)
                    .font(LKFont.largeTitle)
                    .foregroundColor(.labelPrimary)
                    .lineLimit(2)

                if let deadline = goal.targetDeadline {
                    Label("Target: \(deadline.formattedDDMMYYYY)", systemImage: "calendar")
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
                statCell(value: "\(goal.allLeafTasks.filter { $0.isMilestone }.count)",
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
                                Label("Due: \(dl.formattedDDMMYYYY)", systemImage: "calendar")
                                    .font(LKFont.caption)
                                    .foregroundColor(task.isOverdue ? .red : .labelSecondary)
                            }
                        }
                    }

                    Spacer()

                    // Quick Toggle Complete Button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.toggleTaskInActiveGoal(task.id) }
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
                    .focusable(false)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Mark the active task complete (⌘↩)")
                }
                .padding(LKSpacing.md)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(LKRadius.md)
            } else if goal.allLeafTasks.isEmpty {
                HStack {
                    Text("No tasks yet.")
                        .font(LKFont.body)
                        .foregroundColor(.labelSecondary)
                    Button("Add Tasks") { vm.selectedTab = 1 }
                        .buttonStyle(.borderless)
                }
                .padding(LKSpacing.sm)
            } else {
                Text("All tasks completed! 🎉")
                    .font(LKFont.body)
                    .foregroundColor(.labelSecondary)
                    .padding(LKSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func upcomingTasksList(goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            SectionHeader(title: "Upcoming Tasks")

            // Skip the task already featured in the Active Task card.
            let upcoming = vm.pendingTasksByUrgency.dropFirst().prefix(5)

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func upcomingTaskRow(task: Task) -> some View {
        HStack(spacing: LKSpacing.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { vm.toggleTaskInActiveGoal(task.id) }
            } label: {
                Image(systemName: "circle")
                    .foregroundColor(.labelSecondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .help("Mark complete")

            if task.isMilestone {
                Image(systemName: "flag.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 11))
            }

            Text(task.title)
                .font(LKFont.body)
                .foregroundColor(.labelPrimary)
                .lineLimit(1)

            Spacer()

            if let dl = task.deadline {
                Text(dl.formattedDDMMYYYY)
                    .font(LKFont.caption)
                    .foregroundColor(task.isOverdue ? .red : .labelSecondary)
            }

            PriorityBadge(priority: task.priority)
        }
        .padding(.vertical, LKSpacing.xs)
        .padding(.horizontal, 4)
        .hoverHighlight()

        Divider()
    }

    private func milestonesCard(goal: Goal) -> some View {
        let milestones = goal.allLeafTasks.filter { $0.isMilestone }.sortedByUrgency()
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
                            Text(dl.formattedDDMMYYYY)
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                        }
                        StatusBadge(status: m.status)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                    .hoverHighlight()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.toggleTaskInActiveGoal(m.id) }
                    }
                    .help(m.status == .completed ? "Click to reopen" : "Click to mark complete")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

            Text("Define your first goal to start tracking progress toward it.")
                .font(LKFont.body)
                .foregroundColor(.labelSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                showNewGoal = true
            } label: {
                Text("Create Goal")
                    .font(LKFont.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(LKSpacing.xl)
    }
}
