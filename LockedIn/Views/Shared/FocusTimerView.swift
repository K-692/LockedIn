// MARK: - FocusTimerView.swift
// Pomodoro-style focus timer panel — works for any task type.

import SwiftUI

struct FocusTimerView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showTaskPicker: Bool = false

    var body: some View {
        VStack(spacing: LKSpacing.lg) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.timerIsBreak ? "Break Time" : "Focus Timer")
                        .font(LKFont.title2)
                        .foregroundColor(.labelPrimary)
                    if let task = vm.activeTaskForTimer {
                        Text(task.title)
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                            .lineLimit(1)
                    } else {
                        Text("No task selected")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                    }
                }
                Spacer()
                sessionCountDots
            }

            // Timer ring
            ZStack {
                Circle()
                    .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 12)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: vm.timerProgress)
                    .stroke(
                        LinearGradient(
                            colors: vm.timerIsBreak
                                ? [.green, .teal]
                                : [.accentColor, Color.accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.timerProgress)
                    .frame(width: 180, height: 180)

                VStack(spacing: 2) {
                    Text(timeString(vm.timerSecondsRemaining))
                        .font(LKFont.monoLarge)
                        .foregroundColor(.labelPrimary)
                    Text(vm.timerIsBreak ? "break" : "focus")
                        .font(LKFont.caption)
                        .foregroundColor(.labelSecondary)
                }
            }

            // Controls
            HStack(spacing: LKSpacing.lg) {
                // Task picker
                if vm.timerState == .idle {
                    Button {
                        showTaskPicker = true
                    } label: {
                        Label("Select Task", systemImage: "checklist")
                    }
                    .buttonStyle(.bordered)
                }

                switch vm.timerState {
                case .idle:
                    Button {
                        vm.startFocusTimer(for: vm.activeTaskForTimer)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                case .running:
                    Button { vm.pauseTimer() } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

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
                    .controlSize(.large)

                    Button { vm.stopTimer() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)

                case .breakTime:
                    Button { vm.stopTimer() } label: {
                        Label("Skip Break", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)

                case .completed:
                    Button { vm.startFocusTimer(for: vm.activeTaskForTimer) } label: {
                        Label("Start Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // Today's focus time
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Today: \(formattedFocusTime(vm.todayFocusSeconds))")
                    .font(LKFont.caption)
                    .foregroundColor(.labelSecondary)
            }
        }
        .padding(LKSpacing.lg)
        .cardStyle(padding: 0)
        .sheet(isPresented: $showTaskPicker) {
            TaskPickerSheet(selectedTask: $vm.activeTaskForTimer)
                .environmentObject(vm)
        }
    }

    // MARK: - Helpers

    private var sessionCountDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<vm.settings.timerSettings.sessionsUntilLongBreak, id: \.self) { i in
                Circle()
                    .fill(i < vm.sessionsCompletedInCycle % vm.settings.timerSettings.sessionsUntilLongBreak
                          ? Color.accentColor : Color(NSColor.separatorColor))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func formattedFocusTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - TaskPickerSheet

private struct TaskPickerSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var selectedTask: Task?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select a Task")
                    .font(LKFont.title2)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(LKSpacing.md)

            Divider()

            if let goal = vm.activeGoal, !goal.categories.isEmpty {
                List {
                    ForEach(goal.categories) { cat in
                        Section(cat.name) {
                            ForEach(cat.tasks.filter { $0.status != .completed }) { task in
                                Button {
                                    selectedTask = task
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: task.status.icon)
                                            .foregroundColor(.accentColor)
                                        Text(task.title)
                                            .foregroundColor(.labelPrimary)
                                        Spacer()
                                        if selectedTask?.id == task.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            } else {
                Text("No tasks available")
                    .foregroundColor(.labelSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 380, height: 400)
    }
}
