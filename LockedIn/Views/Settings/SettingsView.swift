// MARK: - SettingsView.swift
// Settings & Preferences: goal management, appearance, menu bar, notifications, startup, backup.
// Every control writes straight through to the view model, so changes apply and persist instantly.

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showExportPanel: Bool = false
    @State private var showImportPanel: Bool = false
    @State private var showRestoreConfirm: Bool = false
    @State private var exportDocument: BackupDocument? = nil
    @State private var editingGoal: Goal? = nil
    @State private var showNewGoal: Bool = false

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "v\(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LKSpacing.xl) {
                appHeaderCard

                settingsSection("Active Goal & Target Deadline", icon: "target") {
                    goalSettingsContent
                }

                settingsSection("Appearance", icon: "paintbrush") {
                    appearanceSettingsContent
                }

                settingsSection("Menu Bar", icon: "menubar.rectangle") {
                    menuBarSettingsContent
                }

                settingsSection("Notifications & Alerts", icon: "bell.badge") {
                    notificationSettingsContent
                }

                settingsSection("System & Startup", icon: "gearshape") {
                    systemSettingsContent
                }

                settingsSection("Data Management", icon: "externaldrive") {
                    backupSettingsContent
                }
            }
            .padding(LKSpacing.xl)
            .frame(maxWidth: 680)
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
        .fileExporter(
            isPresented: $showExportPanel,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "LockedIn-backup-\(Date().formattedDDMMYYYY)"
        ) { result in
            if case .failure(let error) = result {
                vm.alertMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showImportPanel,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    vm.restoreBackup(from: try Data(contentsOf: url))
                } catch {
                    vm.alertMessage = "Couldn't read the backup: \(error.localizedDescription)"
                }
            case .failure(let error):
                vm.alertMessage = "Couldn't open the file: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - App Header Card

    private var appHeaderCard: some View {
        HStack(spacing: LKSpacing.md) {
            AppIconView(size: 48)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: LKSpacing.sm) {
                    Text("LockedIn")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.labelPrimary)
                    Text(appVersion)
                        .font(LKFont.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.quaternaryLabelColor))
                        .cornerRadius(LKRadius.sm)
                }
                Text("Focus on what matters. Domain-neutral goal & progress tracking.")
                    .font(LKFont.caption)
                    .foregroundColor(.labelSecondary)
            }
            Spacer()
        }
        .padding(LKSpacing.md)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(LKRadius.md)
    }

    // MARK: - 1. Goal Settings Content

    @ViewBuilder
    private var goalSettingsContent: some View {
        if let goal = vm.activeGoal {
            VStack(alignment: .leading, spacing: LKSpacing.md) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            GlowingActiveBadge(title: "ACTIVE GOAL")
                            Text(goal.name)
                                .font(LKFont.headline)
                                .foregroundColor(.labelPrimary)
                        }

                        if let dl = goal.targetDeadline {
                            HStack(spacing: 6) {
                                Text("Target Deadline:")
                                    .font(LKFont.caption)
                                    .foregroundColor(.labelSecondary)
                                Text(dl.formattedDDMMYYYY)
                                    .font(LKFont.mono)
                                    .foregroundColor(.accentColor)
                            }
                        } else {
                            Text("No target deadline set")
                                .font(LKFont.caption)
                                .foregroundColor(.labelSecondary)
                        }
                    }

                    Spacer()

                    Button {
                        editingGoal = goal
                    } label: {
                        Label("Edit Goal", systemImage: "pencil")
                            .font(LKFont.body)
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remaining Time")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                        if let days = goal.daysRemaining {
                            Text(days < 0 ? "Overdue by \(-days) day\(days == -1 ? "" : "s")" : "\(days) day\(days == 1 ? "" : "s") remaining")
                                .font(LKFont.headline)
                                .foregroundColor(goal.isOverdue ? .red : .labelPrimary)
                        } else {
                            Text("No deadline set")
                                .font(LKFont.body)
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

                if vm.goals.count > 1 {
                    Divider()

                    HStack(alignment: .center) {
                        Text("Switch Active Goal")
                            .font(LKFont.body)
                            .foregroundColor(.labelPrimary)

                        Spacer()

                        Picker("", selection: Binding<UUID>(
                            get: { vm.activeGoalId ?? goal.id },
                            set: { vm.setActiveGoalId($0) }
                        )) {
                            ForEach(vm.goals) { g in
                                Text(g.name).tag(g.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 160, maxWidth: 260)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: LKSpacing.sm) {
                Text("No active goal selected.")
                    .font(LKFont.body)
                    .foregroundColor(.labelSecondary)

                Button {
                    showNewGoal = true
                } label: {
                    Label("Create First Goal", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - 2. Appearance Settings Content

    private var appearanceSettingsContent: some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            Text("Interface Theme")
                .font(LKFont.caption)
                .foregroundColor(.labelSecondary)

            HStack(spacing: LKSpacing.sm) {
                ForEach(AppearancePreference.allCases, id: \.self) { pref in
                    AppearanceCleanButton(
                        preference: pref,
                        isSelected: vm.settings.appearance == pref
                    ) {
                        vm.settingBinding(\.appearance).wrappedValue = pref
                    }
                }
            }
        }
    }

    // MARK: - 3. Menu Bar Settings Content

    @ViewBuilder
    private var menuBarSettingsContent: some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            Toggle("Show remaining days in menu bar", isOn: vm.settingBinding(\.showCountdownInMenuBar))
            Toggle("Show progress percentage in menu bar", isOn: vm.settingBinding(\.showProgressInMenuBar))
            Toggle("Alternate with nearest task deadline every 5 seconds", isOn: vm.settingBinding(\.alternateNearestTaskInMenuBar))

            HStack(alignment: .top, spacing: LKSpacing.sm) {
                Image(systemName: "lock.shield")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
                    .padding(.top, 2)

                Text("LockedIn always stays in the menu bar — closing the window or choosing Quit from the Dock keeps it running there. Task titles are never shown in the menu bar, only dates. To exit completely, use \u{201C}Quit LockedIn\u{201D} in the menu bar panel or press \u{2325}\u{2318}Q.")
                    .font(LKFont.caption)
                    .foregroundColor(.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(LKSpacing.sm)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(LKRadius.sm)
        }
    }

    // MARK: - 4. Notifications Content

    @ViewBuilder
    private var notificationSettingsContent: some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            Toggle("Enable Notifications", isOn: vm.settingBinding(\.notificationsEnabled))

            if vm.settings.notificationsEnabled {
                Divider()

                Picker("Progress digest (9:00 AM)", selection: vm.settingBinding(\.notificationFrequency)) {
                    ForEach(NotificationFrequency.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }

                Toggle("Remind me on the morning a task is due", isOn: vm.settingBinding(\.notifyOnTaskDeadline))
                Toggle("Alert when a milestone is completed", isOn: vm.settingBinding(\.notifyOnMilestoneReached))
                Toggle("Alert when a goal deadline approaches", isOn: vm.settingBinding(\.notifyOnGoalDeadlineApproach))

                if vm.settings.notifyOnGoalDeadlineApproach {
                    Stepper(
                        "Warn \(vm.settings.goalDeadlineWarningDays) day\(vm.settings.goalDeadlineWarningDays == 1 ? "" : "s") before deadline",
                        value: vm.settingBinding(\.goalDeadlineWarningDays),
                        in: 1...90
                    )
                }

                if !NotificationService.isAvailable {
                    Text("Notifications are only available when LockedIn runs as an installed .app.")
                        .font(LKFont.caption)
                        .foregroundColor(.orange)
                } else {
                    Button("Open Notification Settings…") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                    .font(LKFont.caption)
                }
            }
        }
    }

    // MARK: - 5. System Settings Content

    @ViewBuilder
    private var systemSettingsContent: some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            Toggle("Launch LockedIn at Login", isOn: vm.settingBinding(\.launchAtLogin))
            Toggle("Hide Dock icon while the window is closed", isOn: vm.settingBinding(\.hideDockIconWhenClosed))

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Data Storage Location")
                        .font(LKFont.body)
                    Text(PersistenceService.storagePathDescription)
                        .textSelection(.enabled)
                        .font(LKFont.mono)
                        .foregroundColor(.labelSecondary)
                }
                Spacer()
                Button("Open in Finder") {
                    NSWorkspace.shared.open(PersistenceService.documentsDirectory)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - 6. Backup & Restore Content

    @ViewBuilder
    private var backupSettingsContent: some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export All Goals & Tasks")
                        .font(LKFont.body)
                    Text("Export your entire goals hierarchy and settings as a standalone JSON backup file.")
                        .font(LKFont.caption)
                        .foregroundColor(.labelSecondary)
                }
                Spacer()
                Button("Export Backup…") {
                    if let data = vm.exportBackupData() {
                        exportDocument = BackupDocument(data: data)
                        showExportPanel = true
                    } else {
                        vm.alertMessage = "Couldn't create the backup."
                    }
                }
                .buttonStyle(.bordered)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Restore from Backup")
                        .font(LKFont.body)
                    Text("Replace existing local data by loading a JSON backup.")
                        .font(LKFont.caption)
                        .foregroundColor(.labelSecondary)
                }
                Spacer()
                Button("Restore Data…") {
                    showRestoreConfirm = true
                }
                .buttonStyle(.bordered)
            }
            .confirmationDialog(
                "Restore Backup",
                isPresented: $showRestoreConfirm,
                titleVisibility: .visible
            ) {
                Button("Restore and Replace Current Data", role: .destructive) { showImportPanel = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will replace all your current goals, categories, and tasks with the contents of the chosen backup file.")
            }
        }
    }

    // MARK: - Reusable Section Container

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
                    .font(.system(size: 13, weight: .semibold))
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
        }
    }
}

// MARK: - AppearanceCleanButton (Zero Blue Border)

private struct AppearanceCleanButton: View {
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
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .accentColor : .labelSecondary)
                Text(preference.rawValue)
                    .font(LKFont.caption)
                    .foregroundColor(isSelected ? .labelPrimary : .labelSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LKSpacing.sm)
            .padding(.horizontal, LKSpacing.xs)
            .background(isSelected ? Color(NSColor.windowBackgroundColor) : Color.clear)
            .cornerRadius(LKRadius.sm)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

// MARK: - BackupDocument (FileDocument for export)

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
