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
| **Goal** | The overarching high-order outcome to be achieved | Root entity encapsulating categories, target deadline, and cumulative progress. Every goal is fully editable. |
| **Target Deadline** | The temporal upper bound ($T_{\text{target}}$) for goal completion | Drives discrete temporal delta countdown ($\Delta t = T_{\text{target}} - T_{\text{now}}$). Formatted as `YY-MM-DD`. |
| **Category** | A user-defined taxonomy partition | Arbitrary grouping mechanism with dedicated chromatic identity and completion ring. |
| **Milestone** | A non-fungible checkpoint indicating substantive state transition | High-visibility priority anchor alerting user upon state completion. |
| **Task & Subtask** | Actionable atomic and composite work units | State-bearing units of execution with quick inline creation, optional deadlines (`YY-MM-DD`), and status vectors. |
| **Overall Progress** | Weighted progress metric across all eligible leaf tasks | Formal completion ratio: $P = \frac{\sum w_i \cdot \mathbb{I}(\text{status}_i = \text{completed})}{\sum w_i}$. |
| **Menu Bar Ticker** | Dual-phase 5-second alternating state extra | Periodically alternates between overall goal deadline and nearest upcoming target task. |

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
  |   - Goal (Editable)     |      |   - Atomic File I/O     |      |   - Deadline Warnings   |
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
- **Target Deadline Countdown**: Prominent countdown pill displaying target date formatted as `YY-MM-DD` and delta days remaining. Urgency cues highlight milestones within 14 days or overdue.
- **Goal Editor Access**: Direct "Edit Goal" button enabling instantaneous title and target deadline adjustments.
- **Overall Progress Ring**: Visual completion ring reflecting aggregated progress across all categories and tasks.
- **Next Upcoming Target Task**: Dedicated focus card showing the nearest incomplete task with deadline, priority badge, and quick completion toggle.
- **Upcoming Tasks Feed & Milestones**: Chronologically ordered work queue with strict `YY-MM-DD` date formatting.

### 3.2 Tab 2: Add Tasks (`AddTasksView`)
- **Master-Detail Goal Drawer**: Sidebar listing all user goals with quick selection and editing modals.
- **Inline Task Quick-Add**: Direct text input bar within every category card; pressing Return immediately persists the task into the category without opening modals.
- **Detailed Modal Sheets**: Single-coordinator sheet system (`AddTasksSheet`) preventing SwiftUI modal collisions.
- **Category Accordions**: Category progress rings, customizable color tags, task count badges, and bulk actions.
- **Task Row Controls**: Status toggle (`Not Started` $\to$ `In Progress` $\to$ `Completed`), milestone pin toggle, subtask counter, priority flag, and inline notes.

### 3.3 Tab 3: Settings (`SettingsView`)
- **Clean Grouped Architecture**: Redesigned layout organized into distinct, elevated configuration cards.
- **Active Goal & Deadline Management**: Direct editing of active goal name, target date (`YY-MM-DD`), and multi-goal switcher.
- **Appearance Selector**: Native **System**, **Light**, and **Dark** selector without harsh blue borders.
- **Menu Bar Ticker Controls**: Toggles for countdown display, progress percentage, and dual-phase alternation.
- **Notifications & Thresholds**: Granular control over task deadline alerts and goal milestone warnings.
- **Data Management**: Full offline JSON export and safe transactional restore.

---

## 4. State Machines & Discrete Transition Logic

### 4.1 Menu Bar 5-Second Alternating Ticker (DFA)

The menu bar item operates on a discrete 5-second clock pulse to maximize information density in a compact space:

```
         +------------------------------------------------------------+
         |                                                            |
         v                                                            |
+--------------------------------+   Clock Tick (5s)   +--------------------------------+
|       STATE A: GOAL MODE       | ------------------> |       STATE B: TASK MODE       |
|                                |                     |                                |
| Displays:                      |                     | Displays:                      |
| [lock.fill] YY-MM-DD (Xd) X%   | <------------------ | [checklist] TaskTitle YY-MM-DD |
+--------------------------------+   Clock Tick (5s)   +--------------------------------+
         |                                                            ^
         |                    No Tasks with Deadlines                 |
         +------------------------------------------------------------+
```

1. **State A (Goal Countdown)**:
   - Evaluated when `showNearestTaskInMenuBar == false` or when no incomplete tasks have an explicit deadline.
   - Shows: `[lock.fill]` + Goal target deadline (`YY-MM-DD`) + remaining days (`(142d)`) + overall completion percentage.
2. **State B (Nearest Target Task)**:
   - Evaluated when `showNearestTaskInMenuBar == true` AND `nearestTargetTask != nil`.
   - Resolves: $\min_{t \in T_{\text{incomplete}}} \{ t.\text{deadline} \}$.
   - Shows: `[checklist]` + truncated task title + task deadline (`YY-MM-DD`) + days remaining.

### 4.2 Task Lifecycle State Machine

```
         +----------------------+
         |     Not Started      |
         +----------+-----------+
                    |
     Start Work     |     Mark Done
         v          |         v
+-----------------+ | +-----------------+
|   In Progress   | | |    Completed    |
+--------+--------+ | +--------+--------+
         |          |          |
         +----+-----+          |
              |                |
              v                |
        +------------+         |
        |  On Hold   | --------+
        +------------+
```

### 4.3 Task Creation Dual-Path

```
                                  +---------------------+
                                  |  Add Task Trigger   |
                                  +----------+----------+
                                             |
                      +----------------------+----------------------+
                      |                                             |
                      v                                             v
        +----------------------------+                +----------------------------+
        | Inline Quick-Add Path      |                | Modal Form Sheet Path      |
        | - Enter title in TextField |                | - Set title & notes        |
        | - Press Return / Save      |                | - Assign priority          |
        | - Default: Today / Medium  |                | - Set deadline (YY-MM-DD)  |
        | - Instant local sync       |                | - Add granular subtasks    |
        +----------------------------+                +----------------------------+
```

---

## 5. Universal macOS Compilation & Deployment Pipeline

LockedIn produces a unified Universal 2 binary packaging arm64 (Apple Silicon) and x86_64 (Intel) architectures into a DMG:

```
1. swift build -c release --triple arm64-apple-macosx13.0
2. swift build -c release --triple x86_64-apple-macosx13.0
3. lipo -create .build/.../arm64/LockedIn .build/.../x86_64/LockedIn -output LockedIn.app/Contents/MacOS/LockedIn
4. Generate AppIcon.icns via iconutil from multi-resolution iconset
5. Apply ad-hoc signature: codesign --force --deep --sign - LockedIn.app
6. Stage volume & generate UDZO compressed image: LockedIn-Universal.dmg
```

---

## 6. Implementation Journey & Refactoring History

| Phase | Objectives | Outcome |
| :--- | :--- | :--- |
| **Phase 1** | Foundation & Domain-Neutral Schema | Established `Goal`, `Category`, `Task`, `AppSettings`, and atomic JSON persistence. |
| **Phase 2** | UI Components & 3-Tab Structure | Built `DashboardView`, `AddTasksView`, `SettingsView`, and `MenuBarView`. |
| **Phase 3** | Universal Packaging & Distribution | Authored `build_dmg.sh`, generated universal binary (arm64 + x86_64), and released DMG. |
| **Phase 4** | Refinement & Polish | Embedded LockedIn app icon, removed focus timer, removed tab blue borders, enabled inline task creation, enforced `YY-MM-DD` formatting, built 5-second alternating menu bar ticker, and made all goals editable. |

---

*This document serves as the formal state machine and technical reference for academic, engineering, and architectural analysis of LockedIn.*
