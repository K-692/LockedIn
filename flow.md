# LockedIn: System Architecture, State Machine & Execution Flow

> **Tagline**: Focus on what matters.  
> **Status**: Production Architecture & Native macOS Implementation (v1.0.0 Universal)  
> **Target Platform**: macOS 13.0+ (Ventura, Sonoma, Sequoia)  
> **Core Framework**: Swift 5.9+ / SwiftUI / AppKit / Combine / UserNotifications  
> **Architecture**: Universal Mach-O (arm64 + x86_64)

---

## 1. Executive Summary & Domain-Neutral Ontology

**LockedIn** is a native, distraction-resistant goal governance, hierarchical task management, and target deadline countdown environment. Built with pure SwiftUI and AppKit primitives, **LockedIn** enforces a strictly domain-neutral data model and user interface ontology, allowing it to adapt to arbitrary personal, academic, engineering, fitness, and professional pursuits without code alteration.

### 1.1 Generalized Entity Mapping

The system strictly avoids hardcoded academic or domain jargon across all layers:

| Canonical Entity | Formal Definition | Operational Role |
| :--- | :--- | :--- |
| **Goal** | Overarching high-order outcome to be achieved | Root entity encapsulating categories, target deadline, and cumulative progress. Every goal is fully editable and displays a **glowing green effect** when active. |
| **Target Deadline** | The temporal upper bound ($T_{\text{target}}$) for goal completion | Drives discrete temporal delta countdown ($\Delta t = T_{\text{target}} - T_{\text{now}}$). Formatted as `DD-MM-YYYY`. |
| **Category** | User-defined taxonomy partition | Arbitrary grouping mechanism with chromatic identity and completion ring. Direct edit and delete actions (no 3-dots menus). |
| **Milestone** | Non-fungible checkpoint indicating substantive state transition | High-visibility priority anchor alerting user upon state completion. |
| **Task & Subtask** | Actionable atomic and composite work units | State-bearing units with quick inline creation, target toggles, deadlines (`DD-MM-YYYY`), and direct delete buttons. |
| **Overall Progress** | Weighted progress metric across all eligible leaf tasks | Formal completion ratio: $P = \frac{\sum w_i \cdot \mathbb{I}(\text{status}_i = \text{completed})}{\sum w_i}$. |
| **Menu Bar Ticker** | Dual-phase 5-second alternating state extra | Always on even if main window is closed. Periodically alternates between overall goal deadline and nearest task deadline (with task name kept strictly private). |

---

## 2. Architectural Blueprint

LockedIn follows an Unidirectional Data Flow (UDF) MVVM architecture with local-first, privacy-respecting atomic JSON persistence and AppKit-bridged menu bar status items.

```
                           +---------------------------------------+
                           |           User Interactions           |
                           +-------------------+-------------------+
                                               |
                     +-------------------------+-------------------------+
                     |                                                   |
                     v                                                   v
        +-------------------------+                         +-------------------------+
        |   Main Window (SwiftUI) |                         |  Menu Bar Extra Popover |
        |   - DashboardView       |                         |  - Mini Dashboard       |
        |   - AddTasksView        |                         |  - Upcoming Tasks List  |
        |   - SettingsView        |                         |  - Alternating Ticker   |
        +------------+------------+                         +------------+------------+
                     |                                                   |
                     +-------------------------+-------------------------+
                                               |
                                               v
                                  +--------------------------+
                                  |       AppViewModel       |
                                  |    (@MainActor / Combine)|
                                  +-------------+------------+
                                                |
               +--------------------------------+--------------------------------+
               |                                |                                |
               v                                v                                v
  +-------------------------+      +-------------------------+      +-------------------------+
  |   Domain Models         |      |   PersistenceService    |      |   NotificationService   |
  |   - Goal (Glowing Active|      |   - Atomic File I/O     |      |   - Deadline Warnings   |
  |   - Category            |      |   - JSON Serialization  |      |   - Milestone Triggers  |
  |   - Task & Subtask      |      |   - Backup & Restore    |      +-------------------------+
  |   - AppSettings         |      +-------------------------+
  +-------------------------+
```

---

## 3. Strict Three-Tab Navigation Paradigm

LockedIn enforces exactly three primary navigation tabs:

```
+-----------------------------------------------------------------------------------+
| [Icon] LockedIn: Focus on what matters.    [Dashboard]   [Add Tasks]   [Settings] |
+-----------------------------------------------------------------------------------+
```

### 3.1 Tab 1: Dashboard (`DashboardView`)
- **Glowing Active Goal Badge**: Displays an eye-catching pulsating/soft glowing green badge (`[● ACTIVE GOAL]`), visually highlighting the primary objective.
- **Zero Blue Squares / Focus Rings**: Keyboard focus rings and accidental blue strokes removed on window start.
- **Target Deadline Countdown**: Displays target date formatted strictly as `DD-MM-YYYY` with delta days remaining.
- **Goal Editor Access**: Single-click "Edit" button enabling title and target deadline adjustments.
- **Active Task Card**: Highlights the currently active work unit with a glowing `[● ACTIVE]` indicator and quick completion button.
- **Upcoming Tasks Feed**: Chronologically ordered work queue with `DD-MM-YYYY` formatting and 1-click active task assignment.

### 3.2 Tab 2: Add Tasks (`AddTasksView`)
- **Active Goal Selector**: Sidebar goals each feature an active state check; inactive goals offer a 1-click "Make Active" button; active goal radiates a glowing green effect.
- **Direct Actions (No 3-Dots, No Dropdown Arrows)**: Every goal, category, and task row features direct, dedicated **Edit** and **Delete** buttons, completely eliminating multi-step dropdown menus.
- **Inline Task Quick-Add**: Text input bar within every category card persists immediately on Return key.
- **Detailed Modal Sheets**: Single-coordinator sheet system (`AddTasksSheet`) avoiding modal suppression bugs.
- **Task Row Controls**: Status toggle, milestone flag, active task toggle, deadline (`DD-MM-YYYY`), and direct delete trash button.

### 3.3 Tab 3: Settings (`SettingsView`)
- **Active Goal Management**: Displays the glowing green active goal badge with direct deadline editing and goal switching.
- **Appearance Selector**: Native **System**, **Light**, and **Dark** selector with zero high-contrast blue borders.
- **Menu Bar Ticker Controls**: Dual-phase alternating configuration (overall goal deadline vs nearest task date).
- **System & Lifecycle**: Launch at Login, automatic termination prevention, and offline JSON export/restore.

---

## 4. State Machines & Execution Logic

### 4.1 Menu Bar 5-Second Alternating Ticker (DFA)

The menu bar item operates on a discrete 5-second clock pulse to maximize information density while keeping task details completely private:

```
         +------------------------------------------------------------+
         |                                                            |
         v                                                            |
+--------------------------------+   Clock Tick (5s)   +--------------------------------+
|       STATE A: GOAL MODE       | ------------------> |       STATE B: TASK MODE       |
|                                |                     |                                |
| Displays:                      |                     | Displays:                      |
| [lock.fill] DD-MM-YYYY (Xd) X% | <------------------ | [checklist] DD-MM-YYYY (Xd)    |
+--------------------------------+   Clock Tick (5s)   +--------------------------------+
         |                                                            ^
         |                    No Tasks with Deadlines                 |
         +------------------------------------------------------------+
```

1. **State A (Goal Countdown)**:
   - Evaluated when `showNearestTaskInMenuBar == false` or when no incomplete tasks have an explicit deadline.
   - Shows: `[lock.fill]` + Goal target deadline (`DD-MM-YYYY`) + remaining days (`(142d)`) + overall completion percentage.
2. **State B (Nearest Target Task - Private Date Only)**:
   - Evaluated when `showNearestTaskInMenuBar == true` AND `nearestTargetTask != nil`.
   - Resolves: $\min_{t \in T_{\text{incomplete}}} \{ t.\text{deadline} \}$.
   - Shows: `[checklist]` + task deadline (`DD-MM-YYYY`) + days remaining. **Never exposes task title in the menu bar.**

### 4.2 Always-On Menu Bar Lifecycle (Window Interception)

To guarantee the menu bar extra remains visible and interactive even after the user closes the main window:
1. `NSSupportsAutomaticTermination` set to `false` in `Info.plist`.
2. `ProcessInfo.processInfo.disableAutomaticTermination(...)` called on app launch.
3. `NSWindowDelegate.windowShouldClose(_:)` intercepts the red close button and executes `window.orderOut(nil)` instead of destroying the window.
4. `applicationShouldTerminateAfterLastWindowClosed` returns `false`.
5. Menu bar popover "Open LockedIn" button and Dock reopen triggers invoke `AppDelegate.reopenMainWindow()`, restoring the window instantly without process restart.

---

## 5. Temporal Standardization (`DD-MM-YYYY`)

All date instances are formatted strictly as Day-Month-Year (`DD-MM-YYYY`, e.g. `26-10-2026`) via POSIX standard formatter:

$$\text{Format String} = \texttt{"dd-MM-yyyy"}$$

Enforced across:
- Dashboard target countdown and upcoming tasks.
- Add Tasks category deadline badges and task rows.
- Modal creation/editing date pickers.
- Menu Bar popover and alternating extra label.
- Settings target date previews and notification thresholds.

---

## 6. Implementation Journey & Refactoring History

| Phase | Objectives | Outcome |
| :--- | :--- | :--- |
| **Phase 1** | Foundation & Domain-Neutral Schema | Established `Goal`, `Category`, `Task`, `AppSettings`, and atomic JSON persistence. |
| **Phase 2** | UI Components & 3-Tab Structure | Built `DashboardView`, `AddTasksView`, `SettingsView`, and `MenuBarView`. |
| **Phase 3** | Universal Packaging & Distribution | Authored `build_dmg.sh`, generated universal binary (arm64 + x86_64), and released DMG. |
| **Phase 4** | Refinement & Polish | Embedded LockedIn app icon, removed focus timer, removed tab blue borders, enabled inline task creation. |
| **Phase 5** | Strict Enhancements | Standardized `DD-MM-YYYY` everywhere, removed all 3-dots/arrow menus with direct delete buttons, added glowing green effect for active goals, enabled task activation, ensured always-on menu bar lifecycle, and restricted menu bar task ticker to date-only. |

---

*This document serves as the formal state machine and technical reference for academic, engineering, and architectural analysis of LockedIn.*
