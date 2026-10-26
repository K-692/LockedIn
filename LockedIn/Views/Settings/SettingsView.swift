// MARK: - SettingsView.swift
// Settings & Preferences: Goal management, appearance, menu bar, notifications, launch, backup.
// Completely domain-neutral, organized layout, no focus timer, zero blue borders, YY-MM-DD dates.

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var localSettings: AppSettings = AppSettings()
    @State private var showExportPanel: Bool = false
    @State private var showImportPanel: Bool = false
    @State private var showRestoreConfirm: Bool = false
    @State private var exportDocument: BackupDocument? = nil
    @State private var editingGoal: Goal? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: LKSpacing.xl) {
                // App Branding Header with Logo
                appHeaderCard

                // 1. Goal Management & Target Deadline (Editable)
                settingsSection("Active Goal & Target Deadline", icon: "target") {
                    goalSettingsContent
                }

                // 2. Appearance
                settingsSection("Appearance", icon: "paintbrush") {
                    appearanceSettingsContent
                }

                // 3. Menu Bar Extra
                settingsSection("Menu Bar Extra", icon: "menubar.rectangle") {
                    menuBarSettingsContent
                }

                // 4. Notifications
                settingsSection("Notifications & Alerts", icon: "bell.badge") {
                    notificationSettingsContent
                }

                // 5. System Integration
                settingsSection("System & Startup", icon: "gearshape") {
                    systemSettingsContent
                }

                // 6. Data Backup & Storage
                settingsSection("Data Management", icon: "externaldrive") {
                    backupSettingsContent
                }
            }
            .padding(LKSpacing.xl)
            .frame(maxWidth: 680)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $editingGoal) { goal in
            GoalFormSheet(editingGoal: goal)
                .environmentObject(vm)
        }
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
                    Text("v1.0.0 (Universal)")
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
                    VStack(alignment: .leading, spacing: 3) {
                        Text(goal.name)
                            .font(LKFont.headline)
                            .foregroundColor(.labelPrimary)

                        if let dl = goal.targetDeadline {
                            HStack(spacing: 6) {
                                Text("Target Deadline:")
                                    .font(LKFont.caption)
                                    .foregroundColor(.labelSecondary)
                                Text(dl.formattedYYMMDD)
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
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remaining Time")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                        if let days = goal.daysRemaining {
                            Text("\(days) days remaining")
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

                    VStack(alignment: .leading, spacing: LKSpacing.xs) {
                        Text("Switch Active Goal")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)

                        Picker("", selection: Binding<UUID>(
                            get: { vm.activeGoalId ?? UUID() },
                            set: { vm.setActiveGoalId($0) }
                        )) {
                            ForEach(vm.goals) { g in
                                Text(g.name).tag(g.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 300)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: LKSpacing.sm) {
                Text("No active goal selected.")
                    .font(LKFont.body)
                    .foregroundColor(.labelSecondary)

                Button {
                    editingGoal = Goal(name: "My Goal")
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
                        isSelected: localSettings.appearance == pref
                    ) {
                        localSettings.appearance = pref
                        vm.updateSettings(localSettings)
                    }
                }
            }
        }
    }

    // MARK: - 3. Menu Bar Settings Content

    @ViewBuilder
    private var menuBarSettingsContent: some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            Toggle("Show remaining days in menu bar", isOn: $localSettings.showCountdownInMenuBar)
                .onChange(of: localSettings.showCountdownInMenuBar) { _ in vm.updateSettings(localSettings) }

            Toggle("Show progress percentage in menu bar", isOn: $localSettings.showProgressInMenuBar)
                .onChange(of: localSettings.showProgressInMenuBar) { _ in vm.updateSettings(localSettings) }

            Divider()

            HStack(alignment: .top, spacing: LKSpacing.sm) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("5-Second Menu Bar Alternation Active")
                        .font(LKFont.body)
                        .foregroundColor(.labelPrimary)
                    Text("The menu bar item smoothly rotates every 5 seconds between your overall goal remaining time and your nearest upcoming target task (formatted as YY-MM-DD).")
                        .font(LKFont.caption)
                        .foregroundColor(.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
            Toggle("Enable Notifications", isOn: $localSettings.notificationsEnabled)
                .onChange(of: localSettings.notificationsEnabled) { _ in vm.updateSettings(localSettings) }

            if localSettings.notificationsEnabled {
                Divider()

                Picker("Digest Frequency", selection: $localSettings.notificationFrequency) {
                    ForEach(NotificationFrequency.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .onChange(of: localSettings.notificationFrequency) { _ in vm.updateSettings(localSettings) }

                Toggle("Alert on task deadline (YY-MM-DD)", isOn: $localSettings.notifyOnTaskDeadline)
                    .onChange(of: localSettings.notifyOnTaskDeadline) { _ in vm.updateSettings(localSettings) }

                Toggle("Alert when category milestone is completed", isOn: $localSettings.notifyOnMilestoneReached)
                    .onChange(of: localSettings.notifyOnMilestoneReached) { _ in vm.updateSettings(localSettings) }

                Toggle("Alert when goal deadline approaches", isOn: $localSettings.notifyOnGoalDeadlineApproach)
                    .onChange(of: localSettings.notifyOnGoalDeadlineApproach) { _ in vm.updateSettings(localSettings) }

                if localSettings.notifyOnGoalDeadlineApproach {
                    Stepper(
                        "Warn \(localSettings.goalDeadlineWarningDays) days before deadline",
                        value: $localSettings.goalDeadlineWarningDays,
                        in: 1...90
                    )
                    .onChange(of: localSettings.goalDeadlineWarningDays) { _ in vm.updateSettings(localSettings) }
                }
            }
        }
    }

    // MARK: - 5. System Settings Content

    @ViewBuilder
    private var systemSettingsContent: some View {
        VStack(alignment: .leading, spacing: LKSpacing.sm) {
            Toggle("Launch LockedIn at Login", isOn: $localSettings.launchAtLogin)
                .onChange(of: localSettings.launchAtLogin) { _ in
                    vm.updateSettings(localSettings)
                }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Data Storage Location")
                        .font(LKFont.body)
                    Text("~/Library/Application Support/LockedIn")
                        .font(LKFont.mono)
                        .foregroundColor(.labelSecondary)
                }
                Spacer()
                Button("Open in Finder") {
                    let url = PersistenceService.documentsDirectory
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
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
