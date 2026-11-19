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
//
// The status item shows only remaining days (and goal progress) — never dates or task
// titles; dates live in the popover. Both alternating phases are drawn into a single
// template image of the SAME fixed width, so the item never resizes and neighbouring
// menu bar icons never shift. Monospaced digits keep the width stable as numbers change.

private struct MenuBarLabel: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        let goalPhase = goalSegment
        let taskPhase = taskSegment
        let current = (vm.showNearestTaskInMenuBar ? taskPhase : nil) ?? goalPhase
        let width = MenuBarLabelRenderer.width(fitting: [goalPhase, taskPhase].compactMap { $0 })

        Image(nsImage: MenuBarLabelRenderer.image(for: current, width: width))
            .accessibilityLabel(current.accessibilityText)
    }

    /// Goal phase: lock + remaining days + progress.
    private var goalSegment: MenuBarLabelRenderer.Segment {
        guard let goal = vm.activeGoal else {
            return .init(symbol: "lock.fill", text: "", accessibilityText: "LockedIn")
        }
        var parts: [String] = []
        if vm.settings.showCountdownInMenuBar, let days = goal.daysRemaining {
            parts.append(Self.daysText(days))
        }
        if vm.settings.showProgressInMenuBar {
            parts.append("\(Int((goal.overallProgress * 100).rounded()))%")
        }
        return .init(symbol: "lock.fill",
                     text: parts.joined(separator: " "),
                     accessibilityText: "LockedIn: \(goal.name), \(parts.joined(separator: ", "))")
    }

    /// Task phase: checklist + days until the nearest task deadline (no title, no date).
    private var taskSegment: MenuBarLabelRenderer.Segment? {
        guard vm.settings.alternateNearestTaskInMenuBar,
              vm.settings.showCountdownInMenuBar,
              let days = vm.nearestTargetTask?.daysRemaining else { return nil }
        return .init(symbol: "checklist",
                     text: Self.daysText(days),
                     accessibilityText: "Next task due in \(days) days")
    }

    private static func daysText(_ days: Int) -> String {
        days < 0 ? "\(-days)d late" : "\(days)d"
    }
}

/// Draws the menu bar label as a template NSImage (adapts to light/dark menu bars).
enum MenuBarLabelRenderer {
    struct Segment: Equatable {
        let symbol: String
        let text: String
        let accessibilityText: String
    }

    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    private static let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
    private static let iconSlot: CGFloat = 16      // fixed slot so both symbols occupy the same space
    private static let iconTextGap: CGFloat = 4
    private static let horizontalInset: CGFloat = 2 // breathing room inside the status item
    private static let height: CGFloat = 18

    private static func textWidth(_ text: String) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private static func contentWidth(_ segment: Segment) -> CGFloat {
        let t = textWidth(segment.text)
        return iconSlot + (t > 0 ? iconTextGap + t : 0)
    }

    /// One shared width for every phase, so alternating never resizes the status item.
    static func width(fitting segments: [Segment]) -> CGFloat {
        (segments.map(contentWidth).max() ?? iconSlot) + horizontalInset * 2
    }

    static func image(for segment: Segment, width: CGFloat) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size, flipped: false) { rect in
            // Centre the content inside the fixed width so the shorter phase has even margins.
            var x = floor((rect.width - contentWidth(segment)) / 2)

            if let symbol = NSImage(systemSymbolName: segment.symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(symbolConfig) {
                let s = symbol.size
                let origin = NSPoint(x: x + (iconSlot - s.width) / 2, y: (rect.height - s.height) / 2)
                symbol.draw(in: NSRect(origin: origin, size: s))
            }
            x += iconSlot

            if !segment.text.isEmpty {
                x += iconTextGap
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
                let textSize = (segment.text as NSString).size(withAttributes: attrs)
                let y = (rect.height - textSize.height) / 2
                (segment.text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            }
            return true
        }
        image.isTemplate = true
        return image
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
