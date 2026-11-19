<p align="center">
  <img src="icon/icon.png" width="128" height="128" alt="LockedIn app icon" />
</p>

<h1 align="center">LockedIn</h1>

<p align="center">
  <strong>A native macOS goal tracker that keeps your deadline in sight — right in the menu bar.</strong>
</p>

<p align="center">
  <a href="https://github.com/K-692/LockedIn/releases/latest"><img src="https://img.shields.io/github/v/release/K-692/LockedIn?style=flat-square&label=release" alt="Latest release" /></a>
  <img src="https://img.shields.io/badge/macOS-13.0%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 13.0+" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-FA7343?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.9+" />
  <img src="https://img.shields.io/badge/SwiftUI-AppKit-007AFF?style=flat-square" alt="SwiftUI + AppKit" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License" /></a>
</p>

<p align="center">
  <a href="https://github.com/K-692/LockedIn/releases/latest/download/LockedIn-Universal.dmg"><strong>Download for macOS</strong></a>
  &nbsp;·&nbsp;
  <a href="#building-from-source">Build from source</a>
  &nbsp;·&nbsp;
  <a href="flow.md">Architecture notes</a>
</p>

---

## Overview

LockedIn helps you commit to one meaningful outcome — a thesis, a product launch, a certification, a training block — and keep it front of mind until it is done. You define a **goal** with a target date, break it into **categories**, **tasks**, **subtasks** and **milestones**, and LockedIn turns that structure into a live countdown and progress view.

The model is deliberately domain-neutral: nothing assumes you are a student, an engineer or an athlete. Everything is stored locally, nothing leaves your Mac.

```
Goal ─▶ Categories ─▶ Tasks ─▶ Subtasks
  │                     │
  └── target date       └── deadline · priority · status · milestone
```

## Features

### Always-on menu bar
- The menu bar item stays active for as long as LockedIn runs. Closing the window, choosing **Quit** from the Dock, or pressing **⌘Q** closes the window only — the countdown remains in the menu bar.
- When the window is closed, the Dock icon is hidden automatically (configurable), so LockedIn behaves like a lightweight menu bar utility.
- To exit completely, use **Quit LockedIn** in the menu bar panel or **⌥⌘Q**. Logout, restart and shutdown are never blocked.
- The label alternates every five seconds between the goal countdown and the nearest task deadline. **Task titles are never shown in the menu bar** — only dates.
- The panel offers a mini dashboard, a goal switcher, and a one-click checklist of pending tasks sorted by urgency.

### Planning and tracking
- **Dashboard** — active goal, day countdown, overall progress ring, task statistics, the most urgent task (complete it with **⌘↩**), upcoming work and milestones.
- **Add Tasks** — goal sidebar, colour-coded categories with progress rings, inline quick-add (type and press Return), detailed task sheets with notes, priority, status, deadline, milestone flag and subtasks.
- Subtasks can be completed or removed directly from the task list; editing a task preserves each subtask's completion state.
- Right-click context menus on goals and tasks for status, priority, edit and delete.
- Destructive actions on goals, categories and tasks with subtasks ask for confirmation and state exactly what will be removed.
- Consistent `DD-MM-YYYY` dates everywhere; overdue items are highlighted with the number of days elapsed.

### Notifications
- Daily or weekly progress digest (9:00 AM).
- Morning reminder on the day a task is due.
- Advance warning before a goal deadline (1–90 days, configurable).
- Instant notification when a milestone is completed.
- All reminders are rebuilt from current data after every change, so they never go stale after edits or deletions.

### Settings
- System / Light / Dark appearance.
- Launch at login (via `SMAppService`, stays in sync with System Settings › Login Items).
- Menu bar content: remaining days, progress percentage, task-date alternation.
- JSON backup export and validated restore.

### Keyboard shortcuts

| Shortcut | Action |
| :-- | :-- |
| ⌘1 / ⌘2 / ⌘3 | Dashboard / Add Tasks / Settings |
| ⌘↩ | Mark the active task complete (Dashboard) |
| ⇧⌘N | New goal (Add Tasks) |
| ⌥⌘N | New category (Add Tasks) |
| Return / Esc | Confirm / cancel in any form sheet |
| ⌘Q | Close the window — LockedIn keeps running in the menu bar |
| ⌥⌘Q | Quit LockedIn completely |

## Reliability and privacy

- **Local-first.** No accounts, analytics or network access. Data lives in `~/Library/Application Support/LockedIn/` as plain JSON.
- **Safe writes.** Saves are debounced, written atomically on a background queue and flushed on quit, so the interface never blocks on disk I/O.
- **No silent data loss.** If a data file cannot be read, it is moved aside (for example `goals.corrupt-<timestamp>.json`) rather than overwritten.
- **Forward and backward compatible.** Models decode tolerantly — missing or unknown fields fall back to sensible defaults, so upgrading never resets your goals or preferences.
- **Validated restore.** A backup is fully parsed and checked before any existing data is replaced.

## Installation

1. Download **[LockedIn-Universal.dmg](https://github.com/K-692/LockedIn/releases/latest/download/LockedIn-Universal.dmg)** — a universal binary for Apple Silicon and Intel.
2. Open the disk image and drag **LockedIn** into **Applications**.
3. Launch LockedIn from Applications or Spotlight.

> LockedIn is ad-hoc signed, not notarised. On first launch macOS may block it; right-click the app and choose **Open**, or allow it under **System Settings › Privacy & Security**.

Install into `/Applications` before enabling **Launch at Login** — macOS only registers login items for apps in a stable location.

## Building from source

**Requirements:** macOS 13 or later and Swift 5.9+ (Xcode 15+ or the Command Line Tools).

```bash
git clone https://github.com/K-692/LockedIn.git
cd LockedIn
```

Build a universal `.app` and `LockedIn-Universal.dmg`:

```bash
./scripts/build_dmg.sh
```

Build and run a development binary:

```bash
swift build
.build/debug/LockedIn
```

Or open the Xcode project and press **⌘R**:

```bash
open LockedIn.xcodeproj
```

> Running the bare binary (outside an `.app` bundle) works for development, but notifications and Launch at Login require a bundled app — use `build_dmg.sh` to test those.

## Project structure

```
LockedIn/
├── App/LockedInApp.swift            Entry point: main window, menu bar extra, lifecycle (AppDelegate)
├── Models/                          Goal, Category, Task, AppSettings — tolerant Codable models
├── ViewModels/AppViewModel.swift    Single source of truth: CRUD, debounced saves, menu bar ticker
├── Services/
│   ├── PersistenceService.swift     Atomic JSON storage, quarantine, backup/restore
│   └── NotificationService.swift    Reminder scheduling derived from current state
├── Views/
│   ├── ContentView.swift            Three-tab container, onboarding, alerts
│   ├── Dashboard/                   Countdown, progress and upcoming work
│   ├── AddTasks/                    Goal sidebar, categories, task rows, form sheets
│   ├── Settings/                    Preferences, backup and restore
│   ├── MenuBar/                     Menu bar panel
│   ├── Onboarding/                  First-launch flow
│   └── Shared/                      Design tokens, reusable components, app icon
├── Assets.xcassets/
└── Info.plist
scripts/build_dmg.sh                 Universal (arm64 + x86_64) app bundle and DMG
```

See [`flow.md`](flow.md) for a deeper walkthrough of state flow and data model.

## Technical specifications

| | |
| :-- | :-- |
| Minimum macOS | 13.0 Ventura |
| Architectures | Universal — arm64 and x86_64 |
| UI | SwiftUI with AppKit integration |
| Frameworks | SwiftUI, AppKit, Combine, UserNotifications, ServiceManagement, UniformTypeIdentifiers |
| Storage | Local JSON, atomic writes, corrupt-file quarantine |
| Network access | None |

## Contributing

Contributions are welcome.

1. Fork the repository and create a branch: `git checkout -b feature/my-change`.
2. Make your change and confirm `swift build` completes without warnings.
3. Commit using [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:` …).
4. Open a pull request describing the change and how you tested it.

Please open an issue first for larger changes so the approach can be discussed.

## License

Released under the [MIT License](LICENSE).
