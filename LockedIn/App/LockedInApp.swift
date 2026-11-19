// MARK: - LockedInApp.swift
// App entry point. Manages the main window, the always-on menu bar extra, and theme application.
//
// Lifecycle model
// ───────────────
// LockedIn is a menu bar–first app. Closing the window, choosing "Quit" from the Dock,
// or pressing ⌘Q only closes the window (and optionally hides the Dock icon) — the menu bar
// item keeps running. The app fully exits only via "Quit LockedIn" in the menu bar panel,
// "Quit LockedIn Completely" (⌥⌘Q), or when macOS logs out / restarts / shuts down.

import SwiftUI
import AppKit

@main
struct LockedInApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var vm = AppViewModel()

    var body: some Scene {

        // MARK: Main Window (single instance)
        Window("LockedIn", id: MainWindow.id) {
            ContentView()
                .environmentObject(vm)
                .preferredColorScheme(vm.settings.appearance.colorScheme)
                .frame(minWidth: 900, minHeight: 600)
                .captureOpenWindowAction()
                .onAppear { appDelegate.viewModel = vm }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appTermination) {
                Button("Quit LockedIn Completely") { AppDelegate.quitCompletely() }
                    .keyboardShortcut("q", modifiers: [.command, .option])
            }
            CommandMenu("Navigate") {
                Button("Dashboard") { vm.selectedTab = 0 }.keyboardShortcut("1", modifiers: .command)
                Button("Add Tasks") { vm.selectedTab = 1 }.keyboardShortcut("2", modifiers: .command)
                Button("Settings")  { vm.selectedTab = 2 }.keyboardShortcut("3", modifiers: .command)
            }
        }

        // MARK: Menu Bar Extra (always visible while the process runs)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(vm)
                .preferredColorScheme(vm.settings.appearance.colorScheme)
                .captureOpenWindowAction()
                .onAppear { appDelegate.viewModel = vm }
        } label: {
            MenuBarLabel(vm: vm)
                .onAppear { appDelegate.viewModel = vm }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label

private struct MenuBarLabel: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        // NOTE: The status-item label only renders Image/Text, so keep it flat.
        if vm.showNearestTaskInMenuBar, let task = vm.nearestTargetTask, let dl = task.targetDeadline {
            // View A: nearest task deadline (task name is intentionally never shown — privacy).
            Image(systemName: "checklist")
            Text(labelText(date: dl, days: vm.settings.showCountdownInMenuBar ? task.daysRemaining : nil, progress: nil))
        } else if let goal = vm.activeGoal {
            // View B: overall goal countdown & progress.
            Image(systemName: "lock.fill")
            Text(labelText(
                date: goal.targetDeadline,
                days: vm.settings.showCountdownInMenuBar ? goal.daysRemaining : nil,
                progress: vm.settings.showProgressInMenuBar ? goal.overallProgress : nil
            ))
        } else {
            Image(systemName: "lock.fill")
            Text("LockedIn")
        }
    }

    private func labelText(date: Date?, days: Int?, progress: Double?) -> String {
        var parts: [String] = []
        if let date { parts.append(date.formattedDDMMYYYY) }
        if let days { parts.append(days < 0 ? "(\(-days)d over)" : "(\(days)d)") }
        if let progress { parts.append("\(Int((progress * 100).rounded()))%") }
        return parts.isEmpty ? "LockedIn" : parts.joined(separator: " ")
    }
}

// MARK: - Main window helpers

enum MainWindow {
    static let id = "main"

    /// Captured from the SwiftUI environment so AppKit code can (re)open the window.
    @MainActor static var openAction: OpenWindowAction?

    /// Main (non-panel, non-sheet) windows.
    @MainActor static var windows: [NSWindow] {
        NSApp.windows.filter(isMainWindow)
    }

    @MainActor static func isMainWindow(_ window: NSWindow) -> Bool {
        guard !(window is NSPanel), !window.isSheet, window.canBecomeMain else { return false }
        let cls = String(describing: type(of: window))
        return !cls.contains("MenuBarExtra") && !cls.contains("StatusBar")
    }

    /// Shows the main window, creating it if needed, and brings the app forward.
    @MainActor static func show() {
        NSApp.setActivationPolicy(.regular)
        if let existing = windows.first {
            existing.makeKeyAndOrderFront(nil)
        } else {
            openAction?(id: id)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct OpenWindowCapture: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear { MainWindow.openAction = openWindow }
    }
}

extension View {
    func captureOpenWindowAction() -> some View { modifier(OpenWindowCapture()) }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    weak var viewModel: AppViewModel?

    /// Set when the user explicitly asks to exit (or the system is shutting down).
    private static var allowTermination = false

    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Never let macOS silently terminate us — the menu bar item must stay alive.
        ProcessInfo.processInfo.disableAutomaticTermination("LockedIn keeps its menu bar item active")
        ProcessInfo.processInfo.disableSuddenTermination()

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated { AppDelegate.mainWindowWillClose(window) }
        })
        observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                if MainWindow.isMainWindow(window), NSApp.activationPolicy() != .regular {
                    NSApp.setActivationPolicy(.regular)
                }
            }
        })
        // Logout / restart / shutdown must always be allowed to terminate us.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { AppDelegate.allowTermination = true }
        })
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { MainWindow.show() }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppDelegate.allowTermination || AppDelegate.isSystemSessionEnding() {
            return .terminateNow
        }
        // Dock "Quit" or ⌘Q: close to the menu bar instead of exiting.
        closeToMenuBar()
        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.flushForTermination()
        PersistenceService.flush()
    }

    // MARK: Behaviour

    /// Closes all main windows; the menu bar item keeps running.
    private func closeToMenuBar() {
        MainWindow.windows.forEach { $0.close() }
        hideDockIconIfNeeded()
    }

    private static func mainWindowWillClose(_ window: NSWindow) {
        guard MainWindow.isMainWindow(window) else { return }
        // Defer until the window is actually gone, then decide on the Dock icon.
        DispatchQueue.main.async {
            let stillOpen = MainWindow.windows.contains { $0 !== window && $0.isVisible }
            if !stillOpen {
                (NSApp.delegate as? AppDelegate)?.hideDockIconIfNeeded()
            }
        }
    }

    fileprivate func hideDockIconIfNeeded() {
        let hide = viewModel?.settings.hideDockIconWhenClosed ?? true
        if hide, NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// Fully exits the app (menu bar item included).
    static func quitCompletely() {
        allowTermination = true
        NSApp.terminate(nil)
    }

    /// Backwards-compatible entry point used by views.
    static func reopenMainWindow() {
        MainWindow.show()
    }

    /// True when the quit Apple Event was sent because the user is logging out, restarting or shutting down.
    private static func isSystemSessionEnding() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == kCoreEventClass,
              event.eventID == kAEQuitApplication,
              let reason = event.attributeDescriptor(forKeyword: kAEQuitReason)?.enumCodeValue else {
            return false
        }
        let systemReasons: [OSType] = [
            OSType(kAELogOut), OSType(kAEReallyLogOut),
            OSType(kAERestart), OSType(kAEShowRestartDialog),
            OSType(kAEShutDown), OSType(kAEShowShutdownDialog)
        ]
        return systemReasons.contains(reason)
    }
}
