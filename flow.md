# LockedIn: System Architecture, State Machine & Execution Flow

> **Tagline**: Focus on what matters.  
> **Status**: Production Architecture & Native macOS Implementation (v1.0.0)  
> **Target Platform**: macOS 13.0+ (Ventura, Sonoma, Sequoia)  
> **Core Framework**: Swift 5.9+ / SwiftUI / AppKit / Combine / UserNotifications  

---

## 1. Executive Summary & Domain-Neutral Ontology

**LockedIn** is a native, distraction-resistant goal governance, hierarchical task management, target deadline countdown, and focus tracking environment. While historically motivated by high-stakes multi-year efforts (such as doctoral dissertations, licensing examinations, and large-scale engineering deliverables), **LockedIn** enforces a strictly domain-neutral data model and user interface ontology.

### 1.1 Generalized Entity Mapping

The system strictly avoids hardcoded academic or domain jargon across all layers:

| Canonical Entity | Formal Definition | Operational Role |
| :--- | :--- | :--- |
| **Goal** | The overarching high-order outcome to be achieved | Root entity encapsulating categories, target deadline, and cumulative progress |
| **Target Deadline** | The temporal upper bound ($T_{\text{target}}$) for goal completion | Drives discrete temporal delta countdown ($\Delta t = T_{\text{target}} - T_{\text{now}}$) |
| **Category** | A user-defined taxonomy partition | Arbitrary grouping mechanism with dedicated chromatic identity |
| **Milestone** | A non-fungible checkpoint indicating substantive state transition | High-visibility priority anchor alerting user upon state completion |
| **Task & Subtask** | Actionable atomic and composite work units | State-bearing units of execution with optional deadlines and status vectors |
| **Overall Progress** | Weighted progress metric across all eligible leaf tasks | Formal completion ratio: $P = \frac{\sum w_i \cdot \mathbb{I}(\text{status}_i = \text{completed})}{\sum w_i}$ |
| **Focus Timer** | Pomodoro-style interval governor | Task-anchored focus cycles with automated break scheduling and persistence |

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
        |   - AddTasksView        |                         |  - Mini Focus Timer     |
        |   - SettingsView        |                         |  - Mini Task List       |
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
  |   - Goal                |      |   - Atomic File I/O     |      |   - Deadline Warnings   |
  |   - Category            |      |   - JSON Serialization  |      |   - Session Completion  |
  |   - Task & Subtask      |      |   - Backup & Restore    |      |   - Milestone Triggers  |
  |   - FocusSession        |      +-------------------------+      +-------------------------+
  |   - AppSettings         |
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

1. **Dashboard (`DashboardView`)**:
   - Prominent Target Deadline Countdown badge with dynamic urgency chromatic cues ($<30$ days $\to$ warning amber; overdue $\to$ alert crimson).
   - Overall Progress Ring and task completion quadrant (Completed, In Progress, Not Started, Daily Focus).
   - Active Task focal card with 1-click focus session ignition.
   - Interactive Pomodoro Focus Timer with circular sweep animation and session cadence indicators.
   - Upcoming actionable task feed and milestone checkpoint ledger.

2. **Add Tasks (`AddTasksView`)**:
   - Master-Detail Goal navigation drawer.
   - Hierarchical category accordions featuring category-specific progress rings and custom color badges.
   - Task row controls: status cycle toggle, milestone pin, subtask progress tally, priority indicators, and contextual action menus.
   - Modal management sheets (`GoalFormSheet`, `CategoryFormSheet`, `TaskFormSheet`) with granular subtask builder and date picker bindings.

3. **Settings (`SettingsView`)**:
   - Target Deadline configuration and recalibration per goal.
   - Appearance override switcher: **System**, **Light**, and **Dark** with instantaneous SwiftUI color scheme propagation.
   - Notification dispatch schedules and threshold warnings.
   - Menu Bar display toggles (countdown pill, progress percentage).
   - Pomodoro interval tuners (Focus, Short Break, Long Break, Cycle count).
   - System auto-launch integration.
   - One-click JSON backup export and safety-confirmed restore workflow.

---

## 4. Mathematical Formulations & State Machine

### 4.1 Temporal Countdown Calculation

Given a target deadline timestamp $T_{\text{target}} \in \mathbb{R}^+$ and current system clock $T_{\text{now}}$:

$$\Delta t_{\text{seconds}} = T_{\text{target}} - T_{\text{now}}$$

$$\text{Days Remaining} = \left\lfloor \frac{\Delta t_{\text{seconds}}}{86400} \right\rfloor$$

$$\text{Status} = \begin{cases} 
\text{Overdue}, & \text{if } \Delta t_{\text{seconds}} < 0 \\
\text{Imminent}, & \text{if } 0 \le \text{Days Remaining} \le 14 \\
\text{Normal}, & \text{otherwise}
\end{cases}$$

### 4.2 Weighted Hierarchical Progress

For any goal $G$ containing categories $C_1, \dots, C_m$, let $\mathcal{L}(G)$ denote the flattened multiset of all leaf work items:

$$\mathcal{L}(G) = \bigcup_{k} \text{leafTasks}(T_k)$$

The cumulative progress $P(G) \in [0.0, 1.0]$ is defined as:

$$P(G) = \frac{|\{t \in \mathcal{L}(G) \mid \text{status}(t) = \text{completed}\}|}{|\mathcal{L}(G)|}$$

If $|\mathcal{L}(G)| = 0$, $P(G) \equiv 0$.

### 4.3 Focus Timer State Transitions

The focus governor operates as a deterministic finite automaton (DFA):

```
     +--------------------------+
     |           IDLE           |<------------------------------+
     +------------+-------------+                               |
                  |                                             |
             startTimer()                                       |
                  v                                             |
     +--------------------------+        pauseTimer()           |
     |         RUNNING          |-------------------+           |
     +------------+-------------+                   |           |
                  |                                 v           |
             tick == 0                     +-----------------+  |
                  |                        |     PAUSED      |  |
                  v                        +--------+--------+  |
     +--------------------------+                   |           |
     |        COMPLETED         |             resumeTimer()     |
     +------------+-------------+                   |           |
                  |                                 +----------->
                  v                                 |
       (Check Cycle Cadence)                        | stopTimer()
      /                     \                       |
     v                       v                      |
[Short Break]          [Long Break]                 |
     |                       |                      |
     +----------->-----------+----------------------+
```

---

## 5. Local-First Persistence & Storage Architecture

- **Path**: `~/Library/Application Support/LockedIn/`
- **Files**:
  - `goals.json`: Hierarchical structure of goals, categories, tasks, subtasks, deadlines.
  - `settings.json`: User appearance choices, notification preferences, timer settings, onboarding flags.
  - `sessions.json`: Historical log of completed focus intervals with timestamps and duration.
- **Transactions**: Atomic write guarantees (`Data.WritingOptions.atomic`) ensuring crash-safe updates without corrupting existing trees.
- **Portability**: Complete JSON backup export and import allowing zero-dependency manual migration across devices.

---

## 6. Implementation Milestones & Verification Matrix

| Component | Status | Verification Mechanism |
| :--- | :--- | :--- |
| **Domain-Neutral Models** | Verified | Swift Concurrency / Codable serialization validation |
| **AppViewModel State Store** | Verified | Reactive state publishing & atomic persistence |
| **Three Primary Tabs** | Verified | Single top-level segmented container navigation |
| **Dynamic Appearance** | Verified | Semantic NSColor and ColorScheme overrides (Light/Dark/System) |
| **Persistent Menu Bar Extra** | Verified | Continuous countdown, progress pill, and mini-utility |
| **Onboarding Flow** | Verified | Multi-stage neutral setup with bypass option |
| **CLI & SPM Compilation** | Verified | `swift build` passes with zero warnings / errors |
| **Xcode Project Configuration** | Verified | Valid PBXProject v14.0 configuration |
