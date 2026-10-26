// MARK: - DashboardView.swift
// Tab 1: Shows countdown, overall progress, focus timer, and upcoming tasks.

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: LKSpacing.lg) {

                // Goal header
                if let goal = vm.activeGoal {
                    goalHeaderCard(goal: goal)
                    progressCard(goal: goal)
                    activeTaskCard(goal: goal)
                    FocusTimerView()
                    upcomingTasksList(goal: goal)
                    milestonesCard(goal: goal)
                } else {
                    emptyGoalState
                }
            }
            .padding(LKSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cards

    private func goalHeaderCard(goal: Goal) -> some View {
        HStack(alignment: .top, spacing: LKSpacing.md) {
            VStack(alignment: .leading, spacing: LKSpacing.xs) {
                Text("ACTIVE GOAL")
                    .font(LKFont.caption)
                    .foregroundColor(.labelSecondary)
                    .tracking(0.8)

                Text(goal.name)
                    .font(LKFont.largeTitle)
                    .foregroundColor(.labelPrimary)
                    .lineLimit(2)

                if let deadline = goal.targetDeadline {
                    Label(deadline.formatted(date: .long, time: .omitted),
                          systemImage: "calendar")
                        .font(LKFont.caption)
                        .foregroundColor(.labelSecondary)
                }
            }

            Spacer()

            CountdownDisplay(
                daysRemaining: goal.daysRemaining,
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
                statCell(value: "\(vm.todayFocusSeconds / 60)m",
                         label: "Today's Focus",
                         icon: "flame.fill",
                         color: .orange)
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
                                Label(dl.formatted(date: .abbreviated, time: .omitted),
                                      systemImage: "calendar")
                                    .font(LKFont.caption)
                                    .foregroundColor(task.isOverdue ? .red : .labelSecondary)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        vm.activeTaskForTimer = task
                        vm.startFocusTimer(for: task)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Start focus timer for this task")
                }
                .padding(LKSpacing.md)
                .background(Color.accentColor.opacity(0.05))
                .cornerRadius(LKRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: LKRadius.md)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
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
            SectionHeader(title: "Upcoming")

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
                Text(dl.formatted(date: .abbreviated, time: .omitted))
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
                        StatusBadge(status: m.status)
                    }
                }
            }
            .cardStyle()
        )
    }

    // MARK: - Empty State

    private var emptyGoalState: some View {
        EmptyStateView(
            icon: "target",
            title: "No goal yet",
            message: "Add a goal in the Add Tasks tab to get started.",
            action: { vm.selectedTab = 1 },
            actionLabel: "Add Goal"
        )
    }
}
