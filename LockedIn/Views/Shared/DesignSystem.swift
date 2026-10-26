// MARK: - DesignSystem.swift
// Centralized design tokens: colors, typography, spacing, and card styles.
// All colors adapt automatically to Light/Dark using SwiftUI semantic colors.

import SwiftUI

// MARK: - Brand Colors

extension Color {
    /// Primary brand accent — electric teal/blue matching the icon.
    static let brand     = Color("BrandAccent")      // defined in Assets.xcassets
    static let brandAlt  = Color("BrandAltAccent")

    // Semantic surfaces that adapt to light/dark
    static let surface        = Color(NSColor.windowBackgroundColor)
    static let surfaceElevated = Color(NSColor.controlBackgroundColor)
    static let labelPrimary   = Color(NSColor.labelColor)
    static let labelSecondary = Color(NSColor.secondaryLabelColor)
    static let separator      = Color(NSColor.separatorColor)
}

// MARK: - Typography

struct LKFont {
    static let largeTitle  = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title       = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title2      = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let headline    = Font.system(size: 15, weight: .semibold, design: .default)
    static let body        = Font.system(size: 14, weight: .regular, design: .default)
    static let caption     = Font.system(size: 12, weight: .regular, design: .default)
    static let mono        = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let monoLarge   = Font.system(size: 42, weight: .bold, design: .monospaced)
}

// MARK: - Spacing

struct LKSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

struct LKRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Card Modifier

struct CardStyle: ViewModifier {
    var padding: CGFloat = LKSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(LKRadius.md)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

extension View {
    func cardStyle(padding: CGFloat = LKSpacing.md) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    var progress: Double          // 0…1
    var lineWidth: CGFloat = 8
    var size: CGFloat = 60
    var color: Color = .accentColor
    var backgroundColor: Color = Color(NSColor.separatorColor).opacity(0.3)
    var showLabel: Bool = true
    var labelFont: Font = LKFont.caption

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            if showLabel {
                Text("\(Int(progress * 100))%")
                    .font(labelFont)
                    .fontWeight(.semibold)
                    .foregroundColor(.labelPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: TaskStatus

    private var color: Color {
        switch status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed:  return .green
        case .onHold:     return .orange
        }
    }

    var body: some View {
        Label(status.rawValue, systemImage: status.icon)
            .font(LKFont.caption)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: TaskPriority

    private var color: Color {
        switch priority {
        case .low:    return .blue
        case .medium: return .orange
        case .high:   return .red
        }
    }

    var body: some View {
        Label(priority.rawValue, systemImage: priority.icon)
            .font(LKFont.caption)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
}

// MARK: - Color Hex Initializer

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: Double
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Date Formatting (YY-MM-DD)

extension Date {
    /// Strictly formats date as YY-MM-DD (e.g. 26-10-31)
    var formattedYYMMDD: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }
}

// MARK: - Countdown Display

struct CountdownDisplay: View {
    let daysRemaining: Int?
    var targetDate: Date? = nil
    var isOverdue: Bool = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if let days = daysRemaining {
                if isOverdue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Overdue")
                            .font(LKFont.headline)
                            .foregroundColor(.red)
                    }
                    if let targetDate {
                        Text(targetDate.formattedYYMMDD)
                            .font(LKFont.mono)
                            .foregroundColor(.red.opacity(0.85))
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(days)")
                            .font(LKFont.monoLarge)
                            .foregroundColor(days < 14 ? .orange : .labelPrimary)
                        Text("days")
                            .font(LKFont.title2)
                            .foregroundColor(.labelSecondary)
                    }
                    if let targetDate {
                        Text("Due: \(targetDate.formattedYYMMDD)")
                            .font(LKFont.mono)
                            .foregroundColor(.labelSecondary)
                    } else {
                        Text("until deadline")
                            .font(LKFont.caption)
                            .foregroundColor(.labelSecondary)
                    }
                }
            } else {
                Text("No deadline set")
                    .font(LKFont.body)
                    .foregroundColor(.labelSecondary)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "Get Started"

    var body: some View {
        VStack(spacing: LKSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(title)
                .font(LKFont.title2)
                .foregroundColor(.labelPrimary)

            Text(message)
                .font(LKFont.body)
                .foregroundColor(.labelSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            if let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(LKFont.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(LKSpacing.xl)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "Add"

    var body: some View {
        HStack {
            Text(title)
                .font(LKFont.headline)
                .foregroundColor(.labelSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Spacer()

            if let action {
                Button(action: action) {
                    Label(actionLabel, systemImage: "plus")
                        .font(LKFont.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
            }
        }
    }
}
