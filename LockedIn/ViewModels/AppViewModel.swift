// MARK: - AppViewModel.swift
// Central observable state for LockedIn.
// Manages goals, categories, tasks, settings, and menu bar rotation.
// All persistence routes through PersistenceService; saves are debounced and written off the main thread.

import SwiftUI
import Combine
import ServiceManagement

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var goals: [Goal] = []
    @Published private(set) var settings: AppSettings = AppSettings()

    // UI state
    @Published var selectedTab: Int = 0
    @Published var showOnboarding: Bool = false

    /// Menu bar alternating display: false = goal countdown, true = nearest task date.
    @Published private(set) var showNearestTaskInMenuBar: Bool = false

    /// Menu bar popover active tab (0 = Dashboard, 1 = Tasks).
    @Published var menuBarTab: Int = 0

    /// User-facing error/info message surfaced as an alert.
    @Published var alertMessage: String? = nil

    // MARK: - Private

    private var menuBarTimer: Timer?
    private var saveWorkItem: DispatchWorkItem?
    private var dayChangeObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        load()
        showOnboarding = !settings.hasCompletedOnboarding
        startMenuBarAlternatingTimer()
        syncLaunchAtLoginState()

        // Refresh countdowns when the calendar day rolls over.
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            _Concurrency.Task { @MainActor in self?.objectWillChange.send() }
        }
    }

    deinit {
        menuBarTimer?.invalidate()
        if let dayChangeObserver { NotificationCenter.default.removeObserver(dayChangeObserver) }
    }

    // MARK: - Persistence

    func load() {
        goals    = PersistenceService.loadGoals()
        settings = PersistenceService.loadSettings()
        normalizeActiveGoal()
    }

    /// Coalesces bursts of edits into a single disk write.
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            _Concurrency.Task { @MainActor in self?.saveNow() }
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    /// Writes immediately (used on quit) and refreshes scheduled notifications.
    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        PersistenceService.saveGoals(goals)
        PersistenceService.saveSettings(settings)
        NotificationService.reschedule(goals: goals, settings: settings)
    }

    /// Flushes pending state synchronously — call from applicationWillTerminate.
    func flushForTermination() {
        saveNow()
        PersistenceService.flush()
    }

    // MARK: - Active Goal

    /// The active goal, derived from settings so it can never go stale.
    var activeGoal: Goal? {
        if let id = settings.activeGoalId, let g = goals.first(where: { $0.id == id }) {
            return g
        }
        return goals.first
    }

    var activeGoalId: UUID? { activeGoal?.id }

    /// Ensures `activeGoalId` points at an existing goal.
    private func normalizeActiveGoal() {
        if let id = settings.activeGoalId, goals.contains(where: { $0.id == id }) { return }
        settings.activeGoalId = goals.first?.id
    }

    func setActiveGoal(_ goal: Goal) {
        setActiveGoalId(goal.id)
    }

    func setActiveGoalId(_ id: UUID) {
        guard goals.contains(where: { $0.id == id }), settings.activeGoalId != id else { return }
        settings.activeGoalId = id
        scheduleSave()
    }

    func isGoalActive(_ goal: Goal) -> Bool {
        activeGoalId == goal.id
    }

    // MARK: - Goal CRUD

    func addGoal(_ goal: Goal) {
        goals.append(goal)
        if goals.count == 1 || settings.activeGoalId == nil {
            settings.activeGoalId = goal.id
        }
        scheduleSave()
    }

    func updateGoal(_ goal: Goal) {
        guard let idx = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[idx] = goal
        scheduleSave()
    }

    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        normalizeActiveGoal()
        scheduleSave()
    }

    // MARK: - Category CRUD

    func addCategory(_ category: Category, to goalId: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[idx].categories.append(category)
        scheduleSave()
    }

    func updateCategory(_ category: Category, in goalId: UUID) {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalId }),
              let cIdx = goals[gIdx].categories.firstIndex(where: { $0.id == category.id }) else { return }
        goals[gIdx].categories[cIdx] = category
        scheduleSave()
    }

    func deleteCategory(id: UUID, from goalId: UUID) {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[gIdx].categories.removeAll { $0.id == id }
        scheduleSave()
    }

    // MARK: - Task CRUD (works for top-level tasks and nested subtasks)

    private func indices(goalId: UUID, categoryId: UUID) -> (Int, Int)? {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalId }),
              let cIdx = goals[gIdx].categories.firstIndex(where: { $0.id == categoryId }) else { return nil }
        return (gIdx, cIdx)
    }

    func addTask(_ task: Task, to categoryId: UUID, in goalId: UUID) {
        guard let (g, c) = indices(goalId: goalId, categoryId: categoryId) else { return }
        goals[g].categories[c].tasks.append(task)
        scheduleSave()
    }

    func updateTask(_ task: Task, in categoryId: UUID, goalId: UUID) {
        guard let (g, c) = indices(goalId: goalId, categoryId: categoryId) else { return }
        for t in goals[g].categories[c].tasks.indices
        where goals[g].categories[c].tasks[t].mutateTask(id: task.id, { $0 = task }) {
            break
        }
        scheduleSave()
    }

    func deleteTask(id: UUID, from categoryId: UUID, goalId: UUID) {
        guard let (g, c) = indices(goalId: goalId, categoryId: categoryId) else { return }
        if let idx = goals[g].categories[c].tasks.firstIndex(where: { $0.id == id }) {
            goals[g].categories[c].tasks.remove(at: idx)
        } else {
            for t in goals[g].categories[c].tasks.indices
            where goals[g].categories[c].tasks[t].removeSubtask(id: id) {
                break
            }
        }
        scheduleSave()
    }

    /// Toggles completion for a task or subtask anywhere in the goal.
    func toggleTaskStatus(_ taskId: UUID, in categoryId: UUID, goalId: UUID) {
        guard let (g, c) = indices(goalId: goalId, categoryId: categoryId) else { return }
        var completedMilestone: String?

        for t in goals[g].categories[c].tasks.indices {
            let found = goals[g].categories[c].tasks[t].mutateTask(id: taskId) { task in
                task.setStatus(task.status == .completed ? .notStarted : .completed)
                if task.status == .completed && task.isMilestone { completedMilestone = task.title }
            }
            if found { break }
        }

        if let name = completedMilestone, settings.notificationsEnabled, settings.notifyOnMilestoneReached {
            NotificationService.sendMilestoneNotification(milestoneName: name, goalName: goals[g].name)
        }
        scheduleSave()
    }

    /// Convenience: toggles a task in the active goal without knowing its category.
    func toggleTaskInActiveGoal(_ taskId: UUID) {
        guard let goal = activeGoal, let catId = goal.categoryId(containing: taskId) else { return }
        toggleTaskStatus(taskId, in: catId, goalId: goal.id)
    }

    // MARK: - Menu Bar Alternating Display (every 5 seconds)

    private func startMenuBarAlternatingTimer() {
        menuBarTimer?.invalidate()
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            _Concurrency.Task { @MainActor in self?.tickMenuBar() }
        }
        timer.tolerance = 0.5 // lets macOS coalesce wake-ups (energy efficiency)
        RunLoop.main.add(timer, forMode: .common)
        menuBarTimer = timer
    }

    private func tickMenuBar() {
        // Only publish a change when there is something to alternate to — avoids needless redraws.
        let canAlternate = settings.alternateNearestTaskInMenuBar
            && settings.showCountdownInMenuBar
            && nearestTargetTask?.deadline != nil
        let next = canAlternate ? !showNearestTaskInMenuBar : false
        if next != showNearestTaskInMenuBar { showNearestTaskInMenuBar = next }
    }

    // MARK: - Computed Helpers

    /// Incomplete tasks (including subtasks) of the active goal, most urgent first.
    var pendingTasksByUrgency: [Task] {
        guard let goal = activeGoal else { return [] }
        return goal.allLeafTasks.filter { $0.status != .completed }.sortedByUrgency()
    }

    /// The most imminent incomplete task across the active goal (earliest deadline first).
    var nearestTargetTask: Task? {
        pendingTasksByUrgency.first
    }

    /// Next upcoming task (not completed) across the active goal.
    var nextUpcomingTask: Task? {
        nearestTargetTask
    }

    // MARK: - Settings

    func updateSettings(_ updated: AppSettings) {
        guard updated != settings else { return }
        let loginChanged = updated.launchAtLogin != settings.launchAtLogin
        settings = updated
        if loginChanged { applyLaunchAtLogin(updated.launchAtLogin) }
        if !settings.alternateNearestTaskInMenuBar { showNearestTaskInMenuBar = false }
        scheduleSave()
    }

    /// Binding helper for settings toggles/pickers that writes through `updateSettings`.
    func settingBinding<V>(_ keyPath: WritableKeyPath<AppSettings, V>) -> Binding<V> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in
                var s = self.settings
                s[keyPath: keyPath] = newValue
                self.updateSettings(s)
            }
        )
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        showOnboarding = false
        saveNow()
        _Concurrency.Task { await NotificationService.requestAuthorization() }
    }

    // MARK: - Launch at Login (SMAppService, macOS 13+)

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            settings.launchAtLogin = SMAppService.mainApp.status == .enabled
            alertMessage = "Couldn't update Launch at Login: \(error.localizedDescription)\n\nMove LockedIn to the Applications folder and try again."
        }
    }

    /// Reflects changes the user made in System Settings › Login Items.
    private func syncLaunchAtLoginState() {
        let enabled = SMAppService.mainApp.status == .enabled
        if settings.launchAtLogin != enabled {
            settings.launchAtLogin = enabled
        }
    }

    // MARK: - Backup

    func exportBackupData() -> Data? {
        PersistenceService.exportBackup(goals: goals, settings: settings)
    }

    func restoreBackup(from data: Data) {
        do {
            let contents = try PersistenceService.parseBackup(data)
            goals = contents.goals
            if var restored = contents.settings {
                // Machine-specific state is kept from the current install.
                restored.launchAtLogin = settings.launchAtLogin
                restored.hasCompletedOnboarding = true
                settings = restored
            }
            normalizeActiveGoal()
            saveNow()
            alertMessage = "Backup restored: \(goals.count) goal\(goals.count == 1 ? "" : "s") loaded."
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
