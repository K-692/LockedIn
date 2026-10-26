// MARK: - OnboardingView.swift
// First-launch experience: explain LockedIn, let user set a goal name and optional deadline.
// No domain-specific content. Examples use neutral project/learning language.

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var vm: AppViewModel

    @State private var step: Int = 0
    @State private var goalName: String = ""
    @State private var hasDeadline: Bool = false
    @State private var targetDeadline: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var animateIn: Bool = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.18),
                    Color(red: 0.08, green: 0.13, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                switch step {
                case 0: welcomeStep
                case 1: goalStep
                case 2: successStep
                default: EmptyView()
                }

                Spacer()

                // Dot navigation
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i == step ? Color.accentColor : Color.white.opacity(0.3))
                            .frame(width: i == step ? 10 : 6, height: i == step ? 10 : 6)
                            .animation(.spring(), value: step)
                    }
                }
                .padding(.bottom, LKSpacing.xxl)
            }
        }
        .frame(width: 580, height: 480)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateIn = true
            }
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: LKSpacing.xl) {
            Image("AppIcon")
                .resizable()
                .frame(width: 80, height: 80)
                .cornerRadius(18)
                .shadow(color: .accentColor.opacity(0.5), radius: 20)
                .scaleEffect(animateIn ? 1 : 0.6)
                .animation(.spring(response: 0.5), value: animateIn)

            VStack(spacing: LKSpacing.sm) {
                Text("Welcome to LockedIn")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Focus on what matters.")
                    .font(LKFont.title2)
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack(spacing: LKSpacing.md) {
                featureRow(icon: "target",      text: "Define a goal and target deadline")
                featureRow(icon: "checklist",   text: "Break it into categories and tasks")
                featureRow(icon: "timer",       text: "Focus with a built-in Pomodoro timer")
                featureRow(icon: "chart.line.uptrend.xyaxis", text: "Track overall progress every day")
            }

            Button {
                withAnimation { step = 1 }
            } label: {
                Text("Get Started")
                    .font(LKFont.headline)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(LKRadius.lg)
            }
            .buttonStyle(.plain)

            Button("Skip for now") { vm.completeOnboarding() }
                .font(LKFont.caption)
                .foregroundColor(.white.opacity(0.5))
                .buttonStyle(.plain)
        }
        .padding(LKSpacing.xl)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: LKSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.system(size: 16))
                .frame(width: 24)

            Text(text)
                .font(LKFont.body)
                .foregroundColor(.white.opacity(0.85))

            Spacer()
        }
        .padding(.horizontal, LKSpacing.lg)
    }

    // MARK: - Step 1: Configure goal

    private var goalStep: some View {
        VStack(spacing: LKSpacing.xl) {
            VStack(spacing: LKSpacing.sm) {
                Image(systemName: "flag.2.crossed.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text("What's your goal?")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Give your goal a name. You can always change this later.")
                    .font(LKFont.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: LKSpacing.md) {
                VStack(alignment: .leading, spacing: LKSpacing.xs) {
                    Text("GOAL NAME")
                        .font(LKFont.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(0.8)

                    TextField("e.g. Complete my project", text: $goalName)
                        .textFieldStyle(.plain)
                        .font(LKFont.title2)
                        .foregroundColor(.white)
                        .padding(LKSpacing.sm)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(LKRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: LKRadius.sm)
                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )
                }

                Toggle(isOn: $hasDeadline) {
                    Text("Set a target deadline")
                        .foregroundColor(.white.opacity(0.8))
                }
                .toggleStyle(.switch)
                .tint(.accentColor)

                if hasDeadline {
                    DatePicker("Target date",
                               selection: $targetDeadline,
                               in: Date()...,
                               displayedComponents: .date)
                        .colorScheme(.dark)
                }
            }
            .padding(LKSpacing.lg)

            HStack(spacing: LKSpacing.md) {
                Button("Back") { withAnimation { step = 0 } }
                    .foregroundColor(.white.opacity(0.6))
                    .buttonStyle(.plain)

                Button {
                    createGoalAndProceed()
                } label: {
                    Text(goalName.isEmpty ? "Skip" : "Create Goal")
                        .font(LKFont.headline)
                        .foregroundColor(.white)
                        .frame(width: 160)
                        .padding(.vertical, 14)
                        .background(goalName.isEmpty ? Color.white.opacity(0.2) : Color.accentColor)
                        .cornerRadius(LKRadius.lg)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(LKSpacing.xl)
    }

    // MARK: - Step 2: Success

    private var successStep: some View {
        VStack(spacing: LKSpacing.xl) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .shadow(color: .accentColor.opacity(0.5), radius: 20)

            VStack(spacing: LKSpacing.sm) {
                Text("You're ready!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if !goalName.isEmpty {
                    Text("\"\(goalName)\" has been created.")
                        .font(LKFont.body)
                        .foregroundColor(.white.opacity(0.7))
                }

                Text("Add categories and tasks in the Add Tasks tab.")
                    .font(LKFont.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button {
                vm.completeOnboarding()
            } label: {
                Text("Start Focusing")
                    .font(LKFont.headline)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(LKRadius.lg)
            }
            .buttonStyle(.plain)
        }
        .padding(LKSpacing.xl)
    }

    // MARK: - Helpers

    private func createGoalAndProceed() {
        let trimmed = goalName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            var g = Goal(name: trimmed)
            g.targetDeadline = hasDeadline ? targetDeadline : nil
            vm.addGoal(g)
        }
        withAnimation { step = 2 }
    }
}
