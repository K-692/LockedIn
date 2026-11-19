// MARK: - MenuBarView.swift
// Persistent menu bar panel: countdown, progress, nearest task, and a quick task checklist.
// Dates are formatted as DD-MM-YYYY throughout.

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var vm: AppViewModel

    private let maxListedTasks = 12

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            Picker("", selection: $vm.menuBarTab) {
                Label("Dashboard", systemImage: "square.grid.2x2.fill").tag(0)
                Label(pendingCount > 0 ? "Tasks (\(pendingCount))" : "Tasks", systemImage: "checklist").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, LKSpacing.sm)
            .padding(.vertical, 6)

            Divider()

            ScrollView {
                Group {
                    if vm.menuBarTab == 1 {
                        tasksContent
                    } else {
                        dashboardContent
                    }
                }
                .padding(LKSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 340)

            Divider()

            footerBar
        }
        .frame(width: 330)
        .animation(.easeInOut(duration: 0.15), value: vm.menuBarTab)
    }

    private var pendingCount: Int {
        vm.pendingTasksByUrgency.count
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: LKSpacing.sm) {
            AppIconView(size: 26, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 2) {
                if vm.goals.count > 1, let active = vm.activeGoal {
                    Menu {
                        ForEach(vm.goals) { g in
                            Button {
                                vm.setActiveGoal(g)
                            } label: {
                                if g.id == active.id {
                                    Label(g.name, systemImage: "checkmark")
                                } else {
                                    Text(g.name)
                                }
                            }
                        }
                    } label: {
                        Text(active.name)
                            .font(LKFont.headline)
                            .lineLimit(1)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Switch active goal")
                } else {
                    Text(vm.activeGoal?.name ?? "LockedIn")
                        .font(LKFont.headline)
                        .lineLimit(1)
                }

                if let goal = vm.activeGoal {
                    HStack(spacing: 6) {
                        ProgressView(value: goal.overallProgress)
                            .frame(width: 90)
                            .tint(.accentColor)
                        Text("\(Int((goal.overallProgress * 100).rounded()))%")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                    }
                }
            }

            Spacer(minLength: 4)

            if let goal = vm.activeGoal, let days = goal.daysRemaining {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(days < 0 ? "\(-days)d over" : "\(days)d")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(days < 0 ? .red : (days < 14 ? .orange : .labelPrimary))
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
            Button {
                vm.selectedTab = vm.menuBarTab == 1 ? 1 : 0
                MainWindow.show()
            } label: {
                Label("Open LockedIn", systemImage: "macwindow")
            }
            .buttonStyle(.lkChip)
            .font(LKFont.caption)
            .keyboardShortcut("o", modifiers: .command)

            Spacer()

            Button {
                AppDelegate.quitCompletely()
            } label: {
                Label("Quit LockedIn", systemImage: "power")
            }
            .buttonStyle(.lkChip)
            .font(LKFont.caption)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit LockedIn and remove it from the menu bar")
        }
        .padding(.horizontal, LKSpacing.sm)
        .padding(.vertical, 6)
    }

    // MARK: - Dashboard Tab

    @ViewBuilder
    private var dashboardContent: some View {
        if let goal = vm.activeGoal {
            VStack(spacing: LKSpacing.sm) {
                // Target countdown pill
                HStack(spacing: LKSpacing.sm) {
                    Image(systemName: goal.isOverdue ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                        .foregroundColor(goal.isOverdue ? .red : .accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(countdownLabel(goal))
                            .font(LKFont.headline)
                            .foregroundColor(goal.isOverdue ? .red : .labelPrimary)
                        if let dl = goal.targetDeadline {
                            Text("Target date: \(dl.formattedDDMMYYYY)")
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(LKSpacing.sm)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(LKRadius.sm)

                // Nearest target task
                if let task = vm.nearestTargetTask {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NEAREST TARGET TASK")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.labelSecondary)
                            .tracking(0.6)

                        HStack(spacing: LKSpacing.sm) {
                            Button {
                                vm.toggleTaskInActiveGoal(task.id)
                            } label: {
                                Image(systemName: "circle")
                                    .foregroundColor(.labelSecondary)
                                    .font(.system(size: 14))
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
                                .lineLimit(2)
                            Spacer()
                            if let dl = task.deadline {
                                Text(dl.formattedDDMMYYYY)
                                    .font(LKFont.caption)
                                    .foregroundColor(task.isOverdue ? .red : .labelSecondary)
                            }
                        }
                    }
                    .padding(LKSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(LKRadius.sm)
                }

                // Category progress
                if !goal.categories.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(goal.categories) { cat in
                            let tint = Color(hex: cat.colorHex) ?? .accentColor
                            HStack {
                                Circle().fill(tint).frame(width: 8, height: 8)
                                Text(cat.name)
                                    .font(LKFont.caption)
                                    .lineLimit(1)
                                Spacer()
                                ProgressView(value: cat.progress)
                                    .frame(width: 70)
                                    .tint(tint)
                                Text("\(Int((cat.progress * 100).rounded()))%")
                                    .font(LKFont.caption)
                                    .foregroundColor(.labelSecondary)
                                    .frame(width: 34, alignment: .trailing)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(LKSpacing.sm)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(LKRadius.sm)
                }
            }
        } else {
            emptyState(
                icon: "target",
                message: "No goal yet. Open LockedIn to create one.",
                action: { vm.selectedTab = 1; MainWindow.show() },
                actionLabel: "Create a Goal"
            )
        }
    }

    // MARK: - Tasks Tab

    @ViewBuilder
    private var tasksContent: some View {
        if vm.activeGoal != nil {
            let pending = vm.pendingTasksByUrgency
            if pending.isEmpty {
                emptyState(
                    icon: "checkmark.seal.fill",
                    message: "All caught up — no pending tasks.",
                    action: { vm.selectedTab = 1; MainWindow.show() },
                    actionLabel: "Add Tasks"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(pending.prefix(maxListedTasks)) { task in
                        menuTaskRow(task)
                        Divider()
                    }
                    if pending.count > maxListedTasks {
                        Button("+ \(pending.count - maxListedTasks) more — open LockedIn") {
                            vm.selectedTab = 1
                            MainWindow.show()
                        }
                        .buttonStyle(.borderless)
                        .font(LKFont.caption)
                        .padding(.top, 6)
                    }
                }
            }
        } else {
            emptyState(icon: "checklist", message: "No tasks available.", action: nil, actionLabel: "")
        }
    }

    private func menuTaskRow(_ task: Task) -> some View {
        HStack(spacing: LKSpacing.sm) {
            Image(systemName: "circle")
                .foregroundColor(.labelSecondary)
                .font(.system(size: 13))

            if task.isMilestone {
                Image(systemName: "flag.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 10))
            }

            Text(task.title)
                .font(LKFont.caption)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let dl = task.deadline {
                Text(dl.formattedDDMMYYYY)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(task.isOverdue ? .red : .labelSecondary)
            }

            PriorityBadge(priority: task.priority)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .hoverHighlight()
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { vm.toggleTaskInActiveGoal(task.id) }
        }
        .help("Click to mark complete")
    }

    private func emptyState(icon: String, message: String, action: (() -> Void)?, actionLabel: String) -> some View {
        VStack(spacing: LKSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(.accentColor)
            Text(message)
                .font(LKFont.caption)
                .foregroundColor(.labelSecondary)
                .multilineTextAlignment(.center)
            if let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(LKSpacing.md)
    }

    // MARK: - Helpers

    private func countdownLabel(_ goal: Goal) -> String {
        guard let days = goal.daysRemaining else { return "No deadline" }
        if days < 0 { return "Overdue by \(-days) day\(days == -1 ? "" : "s")" }
        if days == 0 { return "Due today!" }
        return "\(days) day\(days == 1 ? "" : "s") remaining"
    }
}
