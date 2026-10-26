// MARK: - LockedInApp.swift
// App entry point. Manages the main window, menu bar extra, and theme application.

import SwiftUI
import AppKit

@main
struct LockedInApp: App {

    @StateObject private var vm = AppViewModel()

    // Menu bar extra state
    @State private var menuBarPopoverShown: Bool = false
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {

        // MARK: Main Window
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .preferredColorScheme(vm.settings.appearance.colorScheme)
                .sheet(isPresented: $vm.showOnboarding) {
                    OnboardingView()
                        .environmentObject(vm)
                }
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            // Remove default New Window command for cleaner menu bar
            CommandGroup(replacing: .newItem) {}
        }

        // MARK: Menu Bar Extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(vm)
                .preferredColorScheme(vm.settings.appearance.colorScheme)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Menu Bar Label

    @ViewBuilder
    private var menuBarLabel: some View {
        HStack(spacing: 5) {
            if vm.showNearestTaskInMenuBar, let task = vm.nearestTargetTask, let dl = task.targetDeadline {
                // Alternating View A (every 5 seconds): Most Near Target Task
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .semibold))
                Text(task.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: 130, alignment: .leading)
                Text(dl.formattedYYMMDD)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                if let days = task.daysRemaining {
                    Text("(\(days)d)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
            } else {
                // Alternating View B (every 5 seconds): Overall Goal Remaining Time
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))

                if let goal = vm.activeGoal {
                    if let dl = goal.targetDeadline {
                        Text(dl.formattedYYMMDD)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }

                    if vm.settings.showCountdownInMenuBar,
                       let days = goal.daysRemaining {
                        Text("(\(days)d)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }

                    if vm.settings.showProgressInMenuBar {
                        Text("\(Int(goal.overallProgress * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                } else {
                    Text("LockedIn")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission on first launch
        _Concurrency.Task {
            await NotificationService.requestAuthorization()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running as a menu bar app even when main window is closed
        return false
    }
}
