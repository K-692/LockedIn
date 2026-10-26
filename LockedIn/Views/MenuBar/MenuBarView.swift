// MARK: - MenuBarView.swift
// Persistent menu bar extra showing countdown, progress, nearest task, and task checklist.
// Focus timer completely removed; dates formatted as YY-MM-DD throughout.

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header bar with app icon
            headerBar

            Divider()

            // 2-Tab Switcher (Dashboard & Tasks)
            let pendingCount = vm.activeGoal?.allTasks.filter { $0.status != .completed }.count ?? 0

            Picker("", selection: Binding<Int>(
                get: { vm.menuBarTab },
                set: { newTab in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        vm.menuBarTab = newTab
                    }
                }
            )) {
                Label("Dashboard", systemImage: "square.grid.2x2.fill").tag(0)
                Label(pendingCount > 0 ? "Tasks (\(pendingCount))" : "Tasks", systemImage: "checklist").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, LKSpacing.sm)
            .padding(.vertical, 6)

            Divider()

            // Tab Content
            ScrollView {
                Group {
                    switch vm.menuBarTab {
                    case 0: dashboardContent
                    case 1: tasksContent
                    default: dashboardContent
                    }
                }
                .padding(LKSpacing.sm)
            }

            Divider()

            // Footer with Open App & Quit
            footerBar
        }
        .frame(width: 320)
        .frame(maxHeight: 460)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: LKSpacing.sm) {
            AppIconView(size: 24, cornerRadius: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(vm.activeGoal?.name ?? "LockedIn")
                    .font(LKFont.headline)
                    .lineLimit(1)
                if let goal = vm.activeGoal {
                    HStack(spacing: 4) {
                        ProgressView(value: goal.overallProgress)
                            .frame(width: 80)
                            .tint(.accentColor)
                        Text("\(Int(goal.overallProgress * 100))%")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                    }
                }
            }

            Spacer()

            if let goal = vm.activeGoal, let days = goal.daysRemaining {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(days)d")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(days < 14 ? .orange : .labelPrimary)
                    if let dl = goal.targetDeadline {
                        Text(dl.formattedDDMMYYYY)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.labelSecondary)
                    }
                }
            }
        }
        .padding(LKSpacing.sm)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button("Open LockedIn") {
                if vm.menuBarTab == 1 {
                    vm.selectedTab = 1
                } else {
                    vm.selectedTab = 0
                }
                AppDelegate.reopenMainWindow()
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .font(LKFont.caption)

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .focusable(false)
                .font(LKFont.caption)
                .foregroundColor(.labelSecondary)
        }
        .padding(.horizontal, LKSpacing.sm)
        .padding(.vertical, 6)
    }

    // MARK: - Dashboard Tab

    private var dashboardContent: some View {
        VStack(spacing: LKSpacing.sm) {
            if let goal = vm.activeGoal {
                // Target Countdown Pill
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(countdownLabel(goal))
                            .font(LKFont.headline)
                        if let dl = goal.targetDeadline {
                            Text("Target Date: \(dl.formattedDDMMYYYY)")
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(LKSpacing.sm)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(LKRadius.sm)

                // Nearest Target Task Card
                if let task = vm.nearestTargetTask {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEAREST TARGET TASK")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.labelSecondary)
                            .tracking(0.6)

                        HStack {
                            Image(systemName: task.isMilestone ? "flag.fill" : task.status.icon)
                                .foregroundColor(task.isMilestone ? .yellow : .accentColor)
                            Text(task.title)
                                .font(LKFont.body)
                                .lineLimit(2)
                            Spacer()
                            if let dl = task.deadline {
                                Text(dl.formattedDDMMYYYY)
                                    .font(LKFont.caption)
                                    .foregroundColor(task.isOverdue ? .red : .labelSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(LKSpacing.sm)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(LKRadius.sm)
                }

                // Category Progress List
                VStack(spacing: 4) {
                    ForEach(goal.categories) { cat in
                        HStack {
                            Circle()
                                .fill(Color(hex: cat.colorHex) ?? .accentColor)
                                .frame(width: 8, height: 8)
                            Text(cat.name)
                                .font(LKFont.caption)
                                .lineLimit(1)
                            Spacer()
                            ProgressView(value: cat.progress)
                                .frame(width: 60)
                                .tint(Color(hex: cat.colorHex) ?? .accentColor)
                            Text("\(Int(cat.progress * 100))%")
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                                .frame(width: 32, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(LKSpacing.sm)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(LKRadius.sm)

            } else {
                Text("No active goal")
                    .foregroundColor(.labelSecondary)
                    .font(LKFont.caption)
            }
        }
    }

    // MARK: - Tasks Tab

    private var tasksContent: some View {
        VStack(spacing: LKSpacing.xs) {
            if let goal = vm.activeGoal {
                let incomplete = goal.allTasks.filter { $0.status != .completed }

                if incomplete.isEmpty {
                    Text("All tasks completed! 🎉")
                        .font(LKFont.body)
                        .foregroundColor(.labelSecondary)
                        .padding(LKSpacing.md)
                } else {
                    ForEach(incomplete.prefix(10)) { task in
                        HStack(spacing: LKSpacing.sm) {
                            Button {
                                if let cat = goal.categories.first(where: { c in c.tasks.contains(where: { $0.id == task.id }) }) {
                                    vm.toggleTaskStatus(task.id, in: cat.id, goalId: goal.id)
                                }
                            } label: {
                                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(task.status == .completed ? .green : .labelSecondary)
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .focusable(false)

                            if task.isMilestone {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 10))
                            }

                            Text(task.title)
                                .font(LKFont.caption)
                                .lineLimit(1)

                            Spacer()

                            if let dl = task.deadline {
                                Text(dl.formattedDDMMYYYY)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(task.isOverdue ? .red : .labelSecondary)
                            }

                            PriorityBadge(priority: task.priority)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            } else {
                Text("No tasks available")
                    .foregroundColor(.labelSecondary)
                    .font(LKFont.caption)
            }
        }
    }

    // MARK: - Helpers

    private func countdownLabel(_ goal: Goal) -> String {
        guard let days = goal.daysRemaining else { return "No deadline" }
        if goal.isOverdue { return "Overdue!" }
        if days == 0 { return "Due today!" }
        return "\(days) days remaining"
    }
}
