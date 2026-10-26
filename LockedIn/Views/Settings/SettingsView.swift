// MARK: - SettingsView.swift
// Tab 3: Target date, appearance, notifications, menu bar, timer, launch, backup/restore.

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var localSettings: AppSettings = AppSettings()
    @State private var showExportPanel: Bool = false
    @State private var showImportPanel: Bool = false
    @State private var showRestoreConfirm: Bool = false
    @State private var exportDocument: BackupDocument? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: LKSpacing.lg) {
                // Target Deadline
                settingsSection("Target Deadline", icon: "calendar") {
                    goalDeadlineSettings
                }

                // Appearance
                settingsSection("Appearance", icon: "paintbrush") {
                    appearanceSettings
                }

                // Notifications
                settingsSection("Notifications", icon: "bell") {
                    notificationSettings
                }

                // Menu Bar
                settingsSection("Menu Bar", icon: "menubar.rectangle") {
                    menuBarSettings
                }

                // Focus Timer
                settingsSection("Focus Timer", icon: "timer") {
                    timerSettings
                }

                // Launch at Login
                settingsSection("System", icon: "gear") {
                    systemSettings
                }

                // Backup & Restore
                settingsSection("Backup & Restore", icon: "externaldrive") {
                    backupSettings
                }
            }
            .padding(LKSpacing.lg)
        }
        .frame(maxWidth: 640, alignment: .center)
        .frame(maxWidth: .infinity)
        .onAppear {
            localSettings = vm.settings
        }
        .onChange(of: localSettings.appearance) { _ in
            vm.updateSettings(localSettings)
        }
        .fileExporter(
            isPresented: $showExportPanel,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "LockedIn-backup"
        ) { _ in }
        .fileImporter(
            isPresented: $showImportPanel,
            allowedContentTypes: [.json]
        ) { result in
            if case .success(let url) = result,
               url.startAccessingSecurityScopedResource(),
               let data = try? Data(contentsOf: url) {
                PersistenceService.importBackup(from: data)
                vm.load()
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    // MARK: - Goal Deadline

    @ViewBuilder
    private var goalDeadlineSettings: some View {
        if let goal = vm.activeGoal {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(LKFont.headline)
                    if let dl = goal.targetDeadline {
                        Text("Target: \(dl.formatted(date: .long, time: .omitted))")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                    } else {
                        Text("No target deadline set")
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

            Divider()

            DeadlineEditorRow(goal: goal)
                .environmentObject(vm)

        } else {
            Text("No active goal. Add a goal in the Add Tasks tab.")
                .font(LKFont.body)
                .foregroundColor(.labelSecondary)
        }
    }

    // MARK: - Appearance

    private var appearanceSettings: some View {
        HStack(spacing: LKSpacing.sm) {
            ForEach(AppearancePreference.allCases, id: \.self) { pref in
                AppearanceButton(
                    preference: pref,
                    isSelected: localSettings.appearance == pref
                ) {
                    localSettings.appearance = pref
                    vm.updateSettings(localSettings)
                }
            }
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationSettings: some View {
        Toggle("Enable Notifications", isOn: $localSettings.notificationsEnabled)
            .onChange(of: localSettings.notificationsEnabled) { _ in vm.updateSettings(localSettings) }

        if localSettings.notificationsEnabled {
            Divider()
            Picker("Frequency", selection: $localSettings.notificationFrequency) {
                ForEach(NotificationFrequency.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .onChange(of: localSettings.notificationFrequency) { _ in vm.updateSettings(localSettings) }

            Toggle("Notify on task deadline", isOn: $localSettings.notifyOnTaskDeadline)
                .onChange(of: localSettings.notifyOnTaskDeadline) { _ in vm.updateSettings(localSettings) }

            Toggle("Notify when milestone reached", isOn: $localSettings.notifyOnMilestoneReached)
                .onChange(of: localSettings.notifyOnMilestoneReached) { _ in vm.updateSettings(localSettings) }

            Toggle("Notify when deadline is approaching", isOn: $localSettings.notifyOnGoalDeadlineApproach)
                .onChange(of: localSettings.notifyOnGoalDeadlineApproach) { _ in vm.updateSettings(localSettings) }

            if localSettings.notifyOnGoalDeadlineApproach {
                Stepper(
                    "Warn \(localSettings.goalDeadlineWarningDays) days before",
                    value: $localSettings.goalDeadlineWarningDays,
                    in: 1...90
                )
                .onChange(of: localSettings.goalDeadlineWarningDays) { _ in vm.updateSettings(localSettings) }
            }
        }
    }

    // MARK: - Menu Bar

    @ViewBuilder
    private var menuBarSettings: some View {
        Toggle("Show countdown in menu bar", isOn: $localSettings.showCountdownInMenuBar)
            .onChange(of: localSettings.showCountdownInMenuBar) { _ in vm.updateSettings(localSettings) }
        Toggle("Show overall progress in menu bar", isOn: $localSettings.showProgressInMenuBar)
            .onChange(of: localSettings.showProgressInMenuBar) { _ in vm.updateSettings(localSettings) }
    }

    // MARK: - Timer

    @ViewBuilder
    private var timerSettings: some View {
        Stepper(
            "Focus: \(localSettings.timerSettings.focusDurationMinutes) min",
            value: $localSettings.timerSettings.focusDurationMinutes,
            in: 1...120
        )
        .onChange(of: localSettings.timerSettings.focusDurationMinutes) { _ in vm.updateSettings(localSettings) }

        Stepper(
            "Short break: \(localSettings.timerSettings.shortBreakMinutes) min",
            value: $localSettings.timerSettings.shortBreakMinutes,
            in: 1...30
        )
        .onChange(of: localSettings.timerSettings.shortBreakMinutes) { _ in vm.updateSettings(localSettings) }

        Stepper(
            "Long break: \(localSettings.timerSettings.longBreakMinutes) min",
            value: $localSettings.timerSettings.longBreakMinutes,
            in: 5...60
        )
        .onChange(of: localSettings.timerSettings.longBreakMinutes) { _ in vm.updateSettings(localSettings) }

        Stepper(
            "Sessions until long break: \(localSettings.timerSettings.sessionsUntilLongBreak)",
            value: $localSettings.timerSettings.sessionsUntilLongBreak,
            in: 2...8
        )
        .onChange(of: localSettings.timerSettings.sessionsUntilLongBreak) { _ in vm.updateSettings(localSettings) }

        Divider()

        Toggle("Auto-start break", isOn: $localSettings.timerSettings.autoStartBreak)
            .onChange(of: localSettings.timerSettings.autoStartBreak) { _ in vm.updateSettings(localSettings) }
        Toggle("Notify on session complete", isOn: $localSettings.timerSettings.notifyOnComplete)
            .onChange(of: localSettings.timerSettings.notifyOnComplete) { _ in vm.updateSettings(localSettings) }
    }

    // MARK: - System

    @ViewBuilder
    private var systemSettings: some View {
        Toggle("Launch at Login", isOn: $localSettings.launchAtLogin)
            .onChange(of: localSettings.launchAtLogin) { _ in
                vm.updateSettings(localSettings)
                // Launch-at-login is handled via SMAppService in macOS 13+
                // Hook: ServiceManagement.SMAppService.mainApp
            }
    }

    // MARK: - Backup & Restore

    @ViewBuilder
    private var backupSettings: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Export Backup")
                    .font(LKFont.body)
                Text("Save all goals and settings to a JSON file.")
                    .font(LKFont.caption)
                    .foregroundColor(.labelSecondary)
            }
            Spacer()
            Button("Export…") {
                if let data = PersistenceService.exportBackup() {
                    exportDocument = BackupDocument(data: data)
                    showExportPanel = true
                }
            }
            .buttonStyle(.bordered)
        }

        Divider()

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Restore Backup")
                    .font(LKFont.body)
                Text("Overwrite current data from a backup file.")
                    .font(LKFont.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
            Spacer()
            Button("Restore…") { showRestoreConfirm = true }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
        }
        .confirmationDialog(
            "Restore Backup",
            isPresented: $showRestoreConfirm,
            titleVisibility: .visible
        ) {
            Button("Restore", role: .destructive) { showImportPanel = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace all current data. This cannot be undone.")
        }
    }

    // MARK: - Section Builder

    @ViewBuilder
    private func settingsSection<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            HStack(spacing: LKSpacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(LKFont.headline)
                    .foregroundColor(.labelPrimary)
            }

            VStack(alignment: .leading, spacing: LKSpacing.sm) {
                content()
            }
            .padding(LKSpacing.md)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(LKRadius.md)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
    }
}

// MARK: - AppearanceButton

private struct AppearanceButton: View {
    let preference: AppearancePreference
    let isSelected: Bool
    let action: () -> Void

    var icon: String {
        switch preference {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: LKSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .labelSecondary)
                Text(preference.rawValue)
                    .font(LKFont.caption)
                    .foregroundColor(isSelected ? .accentColor : .labelSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(LKSpacing.sm)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(LKRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: LKRadius.sm)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DeadlineEditorRow

private struct DeadlineEditorRow: View {
    @EnvironmentObject var vm: AppViewModel
    let goal: Goal
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date()

    var body: some View {
        VStack(spacing: LKSpacing.sm) {
            Toggle("Set target deadline", isOn: $hasDeadline)
                .onChange(of: hasDeadline) { _ in save() }

            if hasDeadline {
                DatePicker("Target date",
                           selection: $deadline,
                           in: Date()...,
                           displayedComponents: .date)
                    .onChange(of: deadline) { _ in save() }
            }
        }
        .onAppear {
            hasDeadline = goal.targetDeadline != nil
            deadline    = goal.targetDeadline ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        }
    }

    private func save() {
        var g = goal
        g.targetDeadline = hasDeadline ? deadline : nil
        vm.updateGoal(g)
    }
}

// MARK: - BackupDocument (FileDocument for export)

import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
