// MARK: - ContentView.swift
// Main application container hosting exactly three primary navigation tabs:
// 1. Dashboard
// 2. Add Tasks
// 3. Settings

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Top Navigation Header with exactly 3 Primary Tabs
            topNavigationBar

            Divider()

            // MARK: Active Tab View Content
            ZStack {
                switch vm.selectedTab {
                case 0:
                    DashboardView()
                        .transition(.opacity)
                case 1:
                    AddTasksView()
                        .transition(.opacity)
                case 2:
                    SettingsView()
                        .transition(.opacity)
                default:
                    DashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: vm.selectedTab)
    }

    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack(spacing: LKSpacing.md) {
            // App Branding & Real App Logo Icon
            HStack(spacing: LKSpacing.sm) {
                AppIconView(size: 30, cornerRadius: 7)

                VStack(alignment: .leading, spacing: 1) {
                    Text("LockedIn")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.labelPrimary)
                    Text("Focus on what matters.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.labelSecondary)
                }
            }
            .padding(.leading, LKSpacing.sm)

            Spacer()

            // Exactly Three Primary Navigation Tabs (No blue borders / no glow outlines)
            HStack(spacing: 4) {
                tabButton(title: "Dashboard", icon: "square.grid.2x2.fill", tabIndex: 0)
                tabButton(title: "Add Tasks", icon: "plus.circle.fill", tabIndex: 1)
                tabButton(title: "Settings", icon: "gearshape.fill", tabIndex: 2)
            }
            .padding(3)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: LKRadius.md, style: .continuous))

            Spacer()

            // Active Goal & Countdown pill with YY-MM-DD formatting
            if let goal = vm.activeGoal {
                HStack(spacing: LKSpacing.sm) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(goal.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(.labelPrimary)

                        HStack(spacing: 4) {
                            if let dl = goal.targetDeadline {
                                Text(dl.formattedDDMMYYYY)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.labelSecondary)
                            }
                            if let days = goal.daysRemaining {
                                Text("(\(days)d)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(days < 14 ? .orange : .labelSecondary)
                            }
                        }
                    }

                    ProgressRing(
                        progress: goal.overallProgress,
                        lineWidth: 3,
                        size: 22,
                        color: .accentColor,
                        showLabel: false
                    )
                }
                .padding(.horizontal, LKSpacing.sm)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(LKRadius.sm)
            }
        }
        .padding(.horizontal, LKSpacing.md)
        .padding(.vertical, LKSpacing.sm)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Navigation Tab Button (Clean segmented design without blue border)
    private func tabButton(title: String, icon: String, tabIndex: Int) -> some View {
        let isSelected = vm.selectedTab == tabIndex

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                vm.selectedTab = tabIndex
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .foregroundColor(isSelected ? .labelPrimary : .labelSecondary)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: LKRadius.sm, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                    } else {
                        Color.clear
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}
