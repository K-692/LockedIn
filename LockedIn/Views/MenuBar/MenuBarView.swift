// MARK: - MenuBarView.swift
// Persistent menu bar extra showing countdown, progress, active task, and timer controls.

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider()

            // Tab switcher
            HStack(spacing: 0) {
                tabButton("Dashboard", tag: 0, icon: "house")
                tabButton("Timer", tag: 1, icon: "timer")
                tabButton("Tasks", tag: 2, icon: "checklist")
            }
            .padding(.horizontal, LKSpacing.sm)
            .padding(.vertical, LKSpacing.xs)

            Divider()

            // Tab content
            ScrollView {
                Group {
                    switch selectedTab {
                    case 0: dashboardContent
                    case 1: timerContent
                    case 2: tasksContent
                    default: EmptyView()
                    }
                }
                .padding(LKSpacing.sm)
            }

            Divider()

            // Footer
            footerBar
        }
        .frame(width: 320)
        .frame(maxHeight: 500)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: LKSpacing.sm) {
            Image("MenuBarIcon")
                .resizable()
                .frame(width: 22, height: 22)
                .cornerRadius(4)

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

            if let days = vm.activeGoal?.daysRemaining {
                VStack(spacing: 0) {
                    Text("\(days)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(days < 30 ? .orange : .labelPrimary)
                    Text("days")
                        .font(.system(size: 9))
                        .foregroundColor(.labelSecondary)
                }
            }
        }
        .padding(LKSpacing.sm)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button("Open App") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first { window.makeKeyAndOrderFront(nil) }
            }
            .buttonStyle(.borderless)
            .font(LKFont.caption)

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
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
                // Countdown
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.accentColor)
                    Text(countdownLabel(goal))
                        .font(LKFont.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(LKSpacing.sm)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(LKRadius.sm)

                // Active task
                if let task = vm.nextUpcomingTask {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEXT UP")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                            .tracking(0.6)
                        HStack {
                            Image(systemName: task.status.icon)
                                .foregroundColor(.accentColor)
                            Text(task.title)
                                .font(LKFont.body)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(LKSpacing.sm)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(LKRadius.sm)
                }

                // Category progress
                ForEach(goal.categories.prefix(3)) { cat in
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
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            } else {
                Text("No active goal")
                    .foregroundColor(.labelSecondary)
                    .font(LKFont.caption)
            }
        }
    }

    // MARK: - Timer Tab

    private var timerContent: some View {
        VStack(spacing: LKSpacing.md) {
            // Timer display
            ZStack {
                Circle()
                    .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 8)
                    .frame(width: 110, height: 110)

                Circle()
                    .trim(from: 0, to: vm.timerProgress)
                    .stroke(
                        vm.timerIsBreak ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.timerProgress)
                    .frame(width: 110, height: 110)

                VStack(spacing: 2) {
                    Text(timeString(vm.timerSecondsRemaining))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                    Text(vm.timerIsBreak ? "break" : "focus")
                        .font(LKFont.caption)
                        .foregroundColor(.labelSecondary)
                }
            }

            // Task name
            if let task = vm.activeTaskForTimer {
                Text(task.title)
                    .font(LKFont.caption)
                    .foregroundColor(.labelSecondary)
                    .lineLimit(1)
            }

            // Controls
            HStack(spacing: LKSpacing.md) {
                switch vm.timerState {
                case .idle:
                    Button { vm.startFocusTimer(for: vm.activeTaskForTimer) } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                case .running:
                    Button { vm.pauseTimer() } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    Button { vm.stopTimer() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)

                case .paused:
                    Button { vm.resumeTimer() } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button { vm.stopTimer() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)

                case .breakTime:
                    Button { vm.stopTimer() } label: {
                        Label("Skip", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)

                case .completed:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Tasks Tab

    private var tasksContent: some View {
        VStack(spacing: LKSpacing.xs) {
            if let goal = vm.activeGoal {
                ForEach(goal.allTasks.filter { $0.status != .completed }.prefix(8)) { task in
                    HStack(spacing: LKSpacing.sm) {
                        Image(systemName: task.isMilestone ? "flag.fill" : task.status.icon)
                            .foregroundColor(task.isMilestone ? .yellow : .labelSecondary)
                            .font(.system(size: 12))
                        Text(task.title)
                            .font(LKFont.caption)
                            .lineLimit(1)
                        Spacer()
                        PriorityBadge(priority: task.priority)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            } else {
                Text("No tasks")
                    .foregroundColor(.labelSecondary)
                    .font(LKFont.caption)
            }
        }
    }

    // MARK: - Helpers

    private func tabButton(_ title: String, tag: Int, icon: String) -> some View {
        Button {
            selectedTab = tag
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: selectedTab == tag ? .semibold : .regular))
                .foregroundColor(selectedTab == tag ? .accentColor : .labelSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(selectedTab == tag ? Color.accentColor.opacity(0.08) : Color.clear)
                .cornerRadius(LKRadius.sm)
        }
        .buttonStyle(.plain)
    }

    private func countdownLabel(_ goal: Goal) -> String {
        guard let days = goal.daysRemaining else { return "No deadline" }
        if goal.isOverdue { return "Overdue!" }
        if days == 0 { return "Due today!" }
        return "\(days) days remaining"
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
