<p align="center">
  <img src="icon/icon.png" width="128" height="128" alt="LockedIn Logo" style="border-radius: 28px; box-shadow: 0 10px 30px rgba(0, 198, 255, 0.3);" />
</p>

<h1 align="center">LockedIn</h1>

<p align="center">
  <strong>Focus on what matters.</strong>
</p>

<p align="center">
  A native, distraction-resistant goal governance, hierarchical task management, and target deadline countdown application built with pure SwiftUI for macOS.
</p>

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9%2B-FA7343?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.9+" /></a>
  <a href="https://www.apple.com/macos"><img src="https://img.shields.io/badge/Platform-macOS%2013.0%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 13.0+" /></a>
  <a href="https://developer.apple.com/xcode/swiftui/"><img src="https://img.shields.io/badge/UI-SwiftUI%20%2F%20AppKit-007AFF?style=flat-square&logo=apple&logoColor=white" alt="SwiftUI" /></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License MIT" /></a>
  <a href="#privacy"><img src="https://img.shields.io/badge/Privacy-100%25%20Offline%20First-blue?style=flat-square" alt="100% Offline First" /></a>
  <a href="https://github.com/K-692/LockedIn/releases/latest"><img src="https://img.shields.io/github/v/release/K-692/LockedIn?style=flat-square&color=00C6FF&label=Release" alt="Latest Release" /></a>
  <a href="https://github.com/K-692/LockedIn/releases/download/v1.0.0/LockedIn-Universal.dmg"><img src="https://img.shields.io/badge/Download-Universal%20DMG%20(6.5MB)-success?style=for-the-badge&logo=apple&logoColor=white" alt="Download Universal DMG" /></a>
</p>

<p align="center">
  <a href="https://github.com/K-692/LockedIn/releases/download/v1.0.0/LockedIn-Universal.dmg">
    <img src="https://img.shields.io/badge/%E2%AC%87%EF%B8%8F_Download_LockedIn_for_macOS_(Universal_DMG)-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="Download LockedIn for macOS" />
  </a>
</p>

<p align="center">
  <sub>Compatible with Apple Silicon (M1/M2/M3/M4) & Intel Macs running macOS 13.0+</sub>
</p>

---

## 🌟 Overview

**LockedIn** is engineered to eliminate distraction and preserve relentless forward momentum on high-stakes outcomes that define your career, education, craft, and personal life.

Whether steering a doctoral dissertation, authoring a book, managing an engineering roadmap, passing licensing exams, or executing athletic training blocks, **LockedIn** enforces a strictly **domain-neutral architecture**. You will never find hardcoded academic assumptions or rigid taxonomy. The terminology adapts seamlessly to whatever outcome you choose to conquer.

```
Goal ──▶ Categories ──▶ Tasks & Subtasks ──▶ Live YY-MM-DD Countdown & Menu Bar Ticker
```

---

## ✨ Core Highlights

### 🎯 Domain-Neutral Data Architecture
- **Goal**: Any high-order outcome (research, product launch, marathon, licensing). **Every goal is fully editable** at any time.
- **Target Deadline**: The definitive target date formatted strictly as `YY-MM-DD` (e.g. `26-12-31`), driving live countdowns.
- **Category**: Flexible, user-colored grouping of tasks with visual completion rings.
- **Milestone**: Non-fungible checkpoints that visually anchor substantive progress.
- **Task & Subtask**: Granular work items with quick inline creation, optional deadlines, and priorities.
- **Overall Progress**: Mathematically computed, weighted completion across all leaf tasks.

### 🧭 Strict Three-Tab Navigation Paradigm
LockedIn maintains a clean, distraction-free environment organized into strictly three primary views:
1. **Dashboard**: Live target countdown (`YY-MM-DD`), overall progress ring, next upcoming target task card, upcoming tasks ledger, and milestone tracker.
2. **Add Tasks**: Hierarchical goal sidebar, category accordions with progress rings, **instant inline task quick-add**, detailed modal task sheets with subtasks, and contextual action menus.
3. **Settings**: Restructured, clean grouped preferences — active goal & deadline editing, System/Light/Dark appearance switcher (without intrusive blue borders), 5-second menu bar ticker configuration, custom notifications, launch-at-login, and JSON data backup/restore.

### 🔄 5-Second Alternating Menu Bar Ticker
The menu bar companion works continuously even when the main window is closed:
- **Phase A (5 seconds)**: Displays overall goal target deadline (`YY-MM-DD`), remaining days (`(142d)`), and progress percentage.
- **Phase B (5 seconds)**: Displays the **most near target task** with its title and deadline (`YY-MM-DD`).
- Quick popover access to a mini-dashboard and upcoming tasks.

### 📅 Uniform `YY-MM-DD` Date Formatting Everywhere
Dates across all screens, countdown badges, task rows, form sheets, and menu bar extras are strictly formatted in the clean, unambiguous `YY-MM-DD` standard.

### 🎨 Clean, Native macOS Aesthetics
- Native macOS vibrancy and subtle styling without awkward blue borders on tab buttons or appearance pickers.
- Embedded high-resolution LockedIn icon branding throughout the interface.
- Three appearance preferences: **System** (follows macOS dynamically), **Light**, and **Dark**.

### 🔒 100% Offline-First & Private
- Zero cloud accounts, zero telemetry, zero background network calls.
- Atomic JSON persistence stored locally in `~/Library/Application Support/LockedIn/`.
- Full backup export and restore in human-readable JSON.

---

## 🏗️ Architecture

```
LockedIn/
├── Package.swift                    # Swift Package Manager manifest
├── LockedIn.xcodeproj/              # Native Xcode Project (macOS 13.0+)
├── icon/
│   └── icon.png                     # Master 1024x1024 icon
├── scripts/
│   └── build_dmg.sh                 # Universal DMG build script (arm64 + x86_64)
├── LockedIn/
│   ├── App/
│   │   └── LockedInApp.swift        # @main entry point, Scene & 5s MenuBarExtra ticker
│   ├── Models/
│   │   ├── Goal.swift               # Root outcome model & progress logic
│   │   ├── Category.swift           # User-defined grouping model
│   │   ├── Task.swift               # Tasks, subtasks, milestones, statuses, deadlines
│   │   └── AppSettings.swift        # Appearance, notifications, preferences
│   ├── ViewModels/
│   │   └── AppViewModel.swift       # Central state store & 5s menu bar timer
│   ├── Views/
│   │   ├── ContentView.swift        # Master container with 3 primary tabs & logo
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift  # Countdown, progress ring, next target task
│   │   ├── AddTasks/
│   │   │   ├── AddTasksView.swift   # Category accordions, inline task add, editing
│   │   │   └── FormSheets.swift     # Modal builders for goals/categories/tasks
│   │   ├── Settings/
│   │   │   └── SettingsView.swift   # Grouped settings, goal editor, backup
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift    # Lightweight menu bar popover
│   │   ├── Onboarding/
│   │   │   └── OnboardingView.swift # First-launch guided configuration
│   │   └── Shared/
│   │       ├── DesignSystem.swift   # Tokens, YY-MM-DD format, ProgressRing, CountdownDisplay
│   │       └── AppIconAsset.swift   # Embedded high-res app icon view & provider
│   ├── Services/
│   │   ├── PersistenceService.swift # Atomic JSON read/write & backup engine
│   │   └── NotificationService.swift# UserNotifications dispatcher
│   ├── Assets.xcassets/             # AppIcon, AppLogo, MenuBarIcon, AccentColor
│   └── Info.plist                   # App configuration & bundle metadata
├── flow.md                          # Technical architecture & state machine
└── README.md                        # Documentation & contribution guide
```

---

## ⚡ Quick Start & Installation

### Option 1: Direct Download (Recommended for all Mac users)
1. Download **[LockedIn-Universal.dmg](https://github.com/K-692/LockedIn/releases/download/v1.0.0/LockedIn-Universal.dmg)** (Universal binary for both Apple Silicon and Intel Macs).
2. Open the downloaded `.dmg` file.
3. Drag **LockedIn.app** into your **Applications** folder.
4. Launch **LockedIn** from Applications or Spotlight!

*(If macOS displays an unverified developer prompt on first open, right-click `LockedIn.app` and choose **Open**, or allow it in System Settings > Privacy & Security).*

---

### Option 2: Build the Universal DMG from Source
```bash
git clone https://github.com/K-692/LockedIn.git
cd LockedIn

# Compile universal binary (arm64 + x86_64) and create DMG
./scripts/build_dmg.sh
```

---

### Option 3: Build & Run from Command Line
```bash
# Clone the repository
git clone https://github.com/K-692/LockedIn.git
cd LockedIn

# Build the release executable
swift build -c release

# Launch LockedIn
.build/release/LockedIn
```

---

### Option 4: Open in Xcode
```bash
open LockedIn.xcodeproj
```
Press `Cmd + R` in Xcode to build and run.

---

## 📊 Technical Specifications

| Parameter | Specification |
| :--- | :--- |
| **Minimum Deployment** | macOS 13.0 (Ventura) |
| **Tested On** | macOS Sonoma (14.x) & macOS Sequoia (15.x) |
| **Architecture** | Apple Silicon (arm64) & Intel (x86_64) Universal |
| **Frameworks** | SwiftUI, AppKit, Combine, UserNotifications, UniformTypeIdentifiers |
| **Storage Engine** | Atomic serialized JSON with crash recovery |
| **Date Format Standard** | `YY-MM-DD` across all views |
| **Menu Bar Mode** | Alternating 5-second ticker (Overall Goal Countdown vs Nearest Task) |
| **UI Paradigms** | 3-tab segmented navigation, Glassmorphism, Semantic Colors |

---

## 🤝 Contributing

Contributions make the open-source community an inspiring place to learn, create, and build. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'feat: Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<p align="center">
  Built with ❤️ for focused creators, researchers, engineers, and achievers everywhere.
</p>
