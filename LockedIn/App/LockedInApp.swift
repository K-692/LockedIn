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
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))

            if vm.settings.showCountdownInMenuBar,
               let days = vm.activeGoal?.daysRemaining {
                Text("\(days)d")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }

            if vm.settings.showProgressInMenuBar,
               let goal = vm.activeGoal {
                Text("\(Int(goal.overallProgress * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }

            // Timer indicator when running
            if vm.timerState == .running || vm.timerState == .paused {
                Circle()
                    .fill(vm.timerState == .running ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
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
