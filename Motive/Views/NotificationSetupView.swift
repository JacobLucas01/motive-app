import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct NotificationSetupView: View {
    @EnvironmentObject private var appState: MotiveAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Set your Pro notification time")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(MotiveTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Motive Pro sends personalized motivation as push notifications. Choose when you want those quotes to arrive.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MotiveTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(NotificationTiming.allCases) { timing in
                    NotificationTimingRow(
                        timing: timing,
                        isSelected: appState.notificationPreference.timing == timing
                    ) {
                        selectionFeedback()
                        appState.notificationPreference.timing = timing
                    }
                }
            }

            if appState.notificationPreference.timing == .custom {
                VStack(spacing: 12) {
                    Stepper(value: $appState.notificationPreference.customHour, in: 0...23) {
                        Text("Hour: \(appState.notificationPreference.customHour.formatted(.number.precision(.integerLength(2))))")
                    }

                    Stepper(value: $appState.notificationPreference.customMinute, in: 0...55, step: 5) {
                        Text("Minute: \(appState.notificationPreference.customMinute.formatted(.number.precision(.integerLength(2))))")
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MotiveTheme.primaryText)
                .padding(14)
                .background(MotiveTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous))
                .motiveGlass(tint: MotiveTheme.elevatedSurface)
            }

            Spacer()

            VStack(spacing: 12) {
                MotivePrimaryButton(title: "Turn on notifications", systemImage: "bell.badge") {
                    Task {
                        await appState.enableNotificationsAndContinue()
                    }
                }

                MotiveSecondaryButton(title: "Not now", systemImage: "arrow.right") {
                    Task {
                        await appState.skipNotifications()
                    }
                }
            }
        }
        .padding(MotiveTheme.pagePadding)
        .motiveScreen()
    }

    private func selectionFeedback() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

private struct NotificationTimingRow: View {
    let timing: NotificationTiming
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 28)
                    .foregroundStyle(isSelected ? MotiveTheme.accent : MotiveTheme.secondaryText)

                VStack(alignment: .leading, spacing: 4) {
                    Text(timing.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                    Text(timing.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MotiveTheme.secondaryText)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? MotiveTheme.accent : MotiveTheme.secondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isSelected ? MotiveTheme.accentMuted : MotiveTheme.elevatedSurface)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? MotiveTheme.accent.opacity(0.6) : MotiveTheme.border, lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
            .motiveCapsuleGlass(tint: isSelected ? MotiveTheme.accentMuted : MotiveTheme.elevatedSurface)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MotiveTheme.primaryText)
    }

    private var iconName: String {
        switch timing {
        case .morning:
            return "sunrise.fill"
        case .afternoon:
            return "sun.max.fill"
        case .evening:
            return "moon.stars.fill"
        case .random:
            return "shuffle"
        case .custom:
            return "clock.fill"
        }
    }
}

struct NotificationSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSetupView()
            .environmentObject(MotiveAppState())
    }
}
