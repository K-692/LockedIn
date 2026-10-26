// MARK: - AppViewModel.swift
// Central observable state for LockedIn.
// Manages goals, categories, tasks, settings, and menu bar rotation.
// All persistence routes through PersistenceService.

import SwiftUI
import Combine

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Published State

    @Published var goals: [Goal] = []
    @Published var settings: AppSettings = AppSettings()

    // Active goal — looked up by activeGoalId in settings.
    @Published var activeGoal: Goal? = nil

    // UI state
    @Published var selectedTab: Int = 0
    @Published var showOnboarding: Bool = false

    // Menu Bar Alternating Display (toggles every 5 seconds)
    // false = overall goal remaining time; true = nearest target task
    @Published var showNearestTaskInMenuBar: Bool = false

    // MARK: - Private

    private var menuBarTimer: Timer?

    // MARK: - Init

    init() {
        load()
        showOnboarding = !settings.hasCompletedOnboarding
        startMenuBarAlternatingTimer()
    }

    deinit {
        menuBarTimer?.invalidate()
    }

    // MARK: - Persistence

    func load() {
        goals    = PersistenceService.loadGoals()
        settings = PersistenceService.loadSettings()
        refreshActiveGoal()
    }

    func save() {
        PersistenceService.saveGoals(goals)
        PersistenceService.saveSettings(settings)
    }

    // MARK: - Active Goal

    func refreshActiveGoal() {
        if let id = settings.activeGoalId {
            activeGoal = goals.first { $0.id == id }
        } else {
            activeGoal = goals.first
        }
    }

    var activeGoalId: UUID? {
        settings.activeGoalId ?? goals.first?.id
    }

    func setActiveGoal(_ goal: Goal) {
        settings.activeGoalId = goal.id
        activeGoal = goal
        save()
    }

    func setActiveGoalId(_ id: UUID) {
        if let g = goals.first(where: { $0.id == id }) {
            setActiveGoal(g)
        }
    }

    // MARK: - Goal CRUD

    func addGoal(_ goal: Goal) {
        goals.append(goal)
        if goals.count == 1 || activeGoal == nil {
            setActiveGoal(goal)
        }
        save()
    }

    func updateGoal(_ goal: Goal) {
        guard let idx = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[idx] = goal
        if activeGoal?.id == goal.id {
            activeGoal = goal
        }
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

        if task.status == .completed && task.isMilestone && settings.notifyOnMilestoneReached {
            NotificationService.sendMilestoneNotification(
                milestoneName: task.title,
                goalName: goals[gIdx].name
            )
        }

        goals[gIdx].categories[cIdx].tasks[tIdx] = task
        refreshActiveGoal()
        save()
    }

    // MARK: - Menu Bar Alternating Display (Every 5 seconds)

    private func startMenuBarAlternatingTimer() {
        menuBarTimer?.invalidate()
        menuBarTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            _Concurrency.Task { @MainActor in
                self?.showNearestTaskInMenuBar.toggle()
            }
        }
        RunLoop.main.add(menuBarTimer!, forMode: .common)
    }

    // MARK: - Computed Helpers

    func isGoalActive(_ goal: Goal) -> Bool {
        activeGoal?.id == goal.id
    }

    var activeTaskId: UUID? {
        settings.activeTaskId
    }

    func isTaskActive(_ task: Task) -> Bool {
        settings.activeTaskId == task.id
    }

    func toggleActiveTask(_ task: Task) {
        if settings.activeTaskId == task.id {
            settings.activeTaskId = nil
        } else {
            settings.activeTaskId = task.id
        }
        save()
    }

    func setActiveTask(_ task: Task?) {
        settings.activeTaskId = task?.id
        save()
    }

    /// The most imminent incomplete task across the active goal (earliest deadline first).
    var nearestTargetTask: Task? {
        guard let goal = activeGoal else { return nil }
        let incomplete = goal.allLeafTasks.filter { $0.status != .completed }
        // Filter tasks that have an explicit deadline, sort earliest first
        let withDeadline = incomplete
            .filter { $0.deadline != nil }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }

        if let firstWithDeadline = withDeadline.first {
            return firstWithDeadline
        }
        return incomplete.first
    }

    /// Next upcoming task (not completed) across the active goal.
    var nextUpcomingTask: Task? {
        guard let goal = activeGoal else { return nil }
        let incomplete = goal.allLeafTasks.filter { $0.status != .completed }
        if let explicitId = settings.activeTaskId,
           let explicit = incomplete.first(where: { $0.id == explicitId }) {
            return explicit
        }
        return nearestTargetTask
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
}
