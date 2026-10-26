// MARK: - AppViewModel.swift
// Central observable state for the entire app.
// Owns goals, settings, and focus-timer state.
// All persistence calls route through PersistenceService.

import SwiftUI
import Combine

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Published State

    @Published var goals: [Goal] = []
    @Published var settings: AppSettings = AppSettings()
    @Published var focusSessions: [FocusSession] = []

    // Active goal — looked up by activeGoalId in settings.
    @Published var activeGoal: Goal? = nil

    // Focus timer state
    @Published var timerState: FocusSessionState = .idle
    @Published var timerSecondsRemaining: Int = 0
    @Published var timerSecondsTotal: Int = 0
    @Published var timerIsBreak: Bool = false
    @Published var sessionsCompletedInCycle: Int = 0
    @Published var activeTaskForTimer: Task? = nil

    // UI state
    @Published var selectedTab: Int = 0
    @Published var showOnboarding: Bool = false

    // MARK: - Private

    private var timer: Timer?
    private var currentSession: FocusSession?

    // MARK: - Init

    init() {
        load()
        showOnboarding = !settings.hasCompletedOnboarding
    }

    // MARK: - Persistence

    func load() {
        goals    = PersistenceService.loadGoals()
        settings = PersistenceService.loadSettings()
        focusSessions = PersistenceService.loadSessions()
        refreshActiveGoal()
    }

    func save() {
        PersistenceService.saveGoals(goals)
        PersistenceService.saveSettings(settings)
        PersistenceService.saveSessions(focusSessions)
    }

    // MARK: - Active Goal

    func refreshActiveGoal() {
        if let id = settings.activeGoalId {
            activeGoal = goals.first { $0.id == id }
        } else {
            activeGoal = goals.first
        }
    }

    func setActiveGoal(_ goal: Goal) {
        settings.activeGoalId = goal.id
        activeGoal = goal
        save()
    }

    // MARK: - Goal CRUD

    func addGoal(_ goal: Goal) {
        goals.append(goal)
        if goals.count == 1 { setActiveGoal(goal) }
        save()
    }

    func updateGoal(_ goal: Goal) {
        guard let idx = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[idx] = goal
        if activeGoal?.id == goal.id { activeGoal = goal }
        save()
    }

    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        if settings.activeGoalId == id {
            settings.activeGoalId = goals.first?.id
            activeGoal = goals.first
        }
        save()
    }

    // MARK: - Category CRUD

    func addCategory(_ category: Category, to goalId: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[idx].categories.append(category)
        refreshActiveGoal()
        save()
    }

    func updateCategory(_ category: Category, in goalId: UUID) {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalId }),
              let cIdx = goals[gIdx].categories.firstIndex(where: { $0.id == category.id }) else { return }
        goals[gIdx].categories[cIdx] = category
        refreshActiveGoal()
        save()
    }

    func deleteCategory(id: UUID, from goalId: UUID) {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[gIdx].categories.removeAll { $0.id == id }
        refreshActiveGoal()
        save()
    }

    // MARK: - Task CRUD

    func addTask(_ task: Task, to categoryId: UUID, in goalId: UUID) {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalId }),
              let cIdx = goals[gIdx].categories.firstIndex(where: { $0.id == categoryId }) else { return }
        goals[gIdx].categories[cIdx].tasks.append(task)
        refreshActiveGoal()
        save()
    }

    func updateTask(_ task: Task, in categoryId: UUID, goalId: UUID) {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalId }),
              let cIdx = goals[gIdx].categories.firstIndex(where: { $0.id == categoryId }) else { return }
        if let tIdx = goals[gIdx].categories[cIdx].tasks.firstIndex(where: { $0.id == task.id }) {
            goals[gIdx].categories[cIdx].tasks[tIdx] = task
        }
        refreshActiveGoal()
        save()
    }

    func deleteTask(id: UUID, from categoryId: UUID, goalId: UUID) {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalId }),
              let cIdx = goals[gIdx].categories.firstIndex(where: { $0.id == categoryId }) else { return }
        goals[gIdx].categories[cIdx].tasks.removeAll { $0.id == id }
        refreshActiveGoal()
        save()
    }

    func toggleTaskStatus(_ taskId: UUID, in categoryId: UUID, goalId: UUID) {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalId }),
              let cIdx = goals[gIdx].categories.firstIndex(where: { $0.id == categoryId }),
              let tIdx = goals[gIdx].categories[cIdx].tasks.firstIndex(where: { $0.id == taskId }) else { return }

        var task = goals[gIdx].categories[cIdx].tasks[tIdx]
        task.status = task.status == .completed ? .notStarted : .completed
        task.completedAt = task.status == .completed ? Date() : nil
        goals[gIdx].categories[cIdx].tasks[tIdx] = task
        refreshActiveGoal()
        save()
    }

    // MARK: - Focus Timer

    /// Starts a focus session for the given task.
    func startFocusTimer(for task: Task?) {
        stopTimer()
        let durationSeconds = settings.timerSettings.focusDurationMinutes * 60
        timerIsBreak              = false
        timerSecondsTotal         = durationSeconds
        timerSecondsRemaining     = durationSeconds
        timerState                = .running
        activeTaskForTimer        = task

        currentSession = FocusSession(
            taskId: task?.id,
            taskTitle: task?.title ?? "",
            startedAt: Date(),
            durationSeconds: durationSeconds
        )
        startTicking()
    }

    func pauseTimer() {
        guard timerState == .running else { return }
        timerState = .paused
        timer?.invalidate()
        timer = nil
    }

    func resumeTimer() {
        guard timerState == .paused else { return }
        timerState = .running
        startTicking()
    }

    func stopTimer() {
        timerState = .idle
        timer?.invalidate()
        timer = nil
        currentSession = nil
    }

    private func startTicking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            _Concurrency.Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        guard timerState == .running else { return }
        if timerSecondsRemaining > 0 {
            timerSecondsRemaining -= 1
            currentSession?.secondsElapsed += 1
        } else {
            timerCompleted()
        }
    }

    private func timerCompleted() {
        timer?.invalidate()
        timer = nil

        // Save the completed session
        if var session = currentSession {
            session.endedAt = Date()
            focusSessions.append(session)
            PersistenceService.saveSessions(focusSessions)
        }

        if !timerIsBreak {
            sessionsCompletedInCycle += 1
            if settings.timerSettings.notifyOnComplete {
                NotificationService.sendFocusCompleteNotification(
                    taskTitle: activeTaskForTimer?.title ?? "Task",
                    isBreak: false
                )
            }
            startBreak()
        } else {
            timerState = .idle
            timerIsBreak = false
            if settings.timerSettings.notifyOnComplete {
                NotificationService.sendFocusCompleteNotification(
                    taskTitle: activeTaskForTimer?.title ?? "Task",
                    isBreak: true
                )
            }
        }
    }

    private func startBreak() {
        let isLong = sessionsCompletedInCycle % settings.timerSettings.sessionsUntilLongBreak == 0
        let breakDuration = (isLong
            ? settings.timerSettings.longBreakMinutes
            : settings.timerSettings.shortBreakMinutes) * 60

        timerIsBreak          = true
        timerState            = .breakTime
        timerSecondsTotal     = breakDuration
        timerSecondsRemaining = breakDuration

        currentSession = FocusSession(
            taskId: activeTaskForTimer?.id,
            taskTitle: activeTaskForTimer?.title ?? "",
            startedAt: Date(),
            durationSeconds: breakDuration,
            isBreak: true
        )

        if settings.timerSettings.autoStartBreak { startTicking() }
    }

    // MARK: - Settings

    func updateSettings(_ updated: AppSettings) {
        settings = updated
        save()
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        save()
        showOnboarding = false
    }

    // MARK: - Computed Helpers

    /// Next upcoming task (not completed) across the active goal.
    var nextUpcomingTask: Task? {
        activeGoal?.allTasks.first { $0.status != .completed }
    }

    /// Today's tasks — tasks with deadlines today or overdue.
    var todaysTasks: [Task] {
        guard let goal = activeGoal else { return [] }
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return goal.allTasks.filter { task in
            guard let dl = task.deadline else { return false }
            return dl < tomorrow && task.status != .completed
        }
    }

    /// Total focus time today in seconds.
    var todayFocusSeconds: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return focusSessions
            .filter { !$0.isBreak && Calendar.current.startOfDay(for: $0.startedAt) == today }
            .reduce(0) { $0 + $1.secondsElapsed }
    }

    var timerProgress: Double {
        guard timerSecondsTotal > 0 else { return 0 }
        return 1 - Double(timerSecondsRemaining) / Double(timerSecondsTotal)
    }
}
