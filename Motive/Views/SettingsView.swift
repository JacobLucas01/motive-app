import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var appState: MotiveAppState
    @State private var isShowingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                nameSection
                profileSection
                notificationSection
                subscriptionSection
                accountSection
                versionFooter
            }
            .padding(MotiveTheme.pagePadding)
        }
        .motiveScreen()
        .dismissKeyboardOnTap()
        .alert("Delete your Motive account?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete account", role: .destructive) {
                Task {
                    await appState.deleteAccount()
                }
            }
        } message: {
            Text("This removes your profile, notification settings, saved device tokens, and Firebase account.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                appState.route = .home
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MotiveTheme.secondaryText)
            .background(MotiveTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous))
            .motiveGlass(tint: MotiveTheme.elevatedSurface)

            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold))
                Text("Update your profile and timing.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MotiveTheme.secondaryText)
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Name")
                .font(.system(size: 18, weight: .bold))

            VStack(alignment: .leading, spacing: 10) {
                Text("What should Motive call you?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MotiveTheme.secondaryText)

                TextField(text: $appState.profile.preferredName) {
                    Text("Name")
                        .foregroundStyle(MotiveTheme.secondaryText)
                }
                .textContentType(.givenName)
                .motiveField()
                .onChange(of: appState.profile.preferredName) { _, _ in
                    appState.cacheCurrentSettingsIfPossible()
                }
            }
        }
        .settingsGroup()
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Focus areas")
                .font(.system(size: 18, weight: .bold))

            MotiveFlowLayout(spacing: 10, rowSpacing: 10) {
                ForEach(StressTopic.allCases) { topic in
                    MotiveChip(title: topic.rawValue, isSelected: appState.profile.selectedTopics.contains(topic)) {
                        toggle(topic)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text("Biggest problem")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MotiveTheme.secondaryText)

                TextField(text: $appState.profile.biggestProblem, axis: .vertical) {
                    Text("What feels heaviest right now?")
                        .foregroundStyle(MotiveTheme.secondaryText)
                }
                .lineLimit(2...4)
                .motiveField()
            }

        }
        .settingsGroup()
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Notification timing")
                .font(.system(size: 18, weight: .bold))

            VStack(spacing: 12) {
                ForEach(NotificationTiming.allCases) { timing in
                    Button {
                        selectionFeedback()
                        appState.notificationPreference.timing = timing
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: appState.notificationPreference.timing == timing ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(appState.notificationPreference.timing == timing ? MotiveTheme.accent : MotiveTheme.secondaryText)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(timing.rawValue)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(timing.subtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(MotiveTheme.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(13)
                        .background(appState.notificationPreference.timing == timing ? MotiveTheme.accentMuted : MotiveTheme.elevatedSurface)
                        .clipShape(Capsule(style: .continuous))
                        .motiveCapsuleGlass(tint: appState.notificationPreference.timing == timing ? MotiveTheme.accentMuted : MotiveTheme.elevatedSurface)
                    }
                    .buttonStyle(.plain)
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
                .padding(14)
                .background(MotiveTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous))
                .motiveGlass(tint: MotiveTheme.elevatedSurface)
            }

            MotivePrimaryButton(title: "Save settings", systemImage: "checkmark") {
                Task {
                    await appState.saveSettingsAndReturnHome()
                }
            }
        }
        .settingsGroup()
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Subscription")
                .font(.system(size: 18, weight: .bold))

            VStack(spacing: 12) {
                settingsInfoRow(title: "Plan", value: subscriptionStatusText)
                settingsInfoRow(title: "Member for", value: memberDurationText)
                settingsInfoRow(title: "Cancel", value: "App Store > Account > Subscriptions")
            }
        }
        .settingsGroup()
    }

    private var accountSection: some View {
        VStack(spacing: 18) {
            MotiveSecondaryButton(title: "Sign out", systemImage: "rectangle.portrait.and.arrow.right") {
                Task {
                    await appState.signOut()
                }
            }

            Button(role: .destructive) {
                isShowingDeleteAlert = true
            } label: {
                Label("Delete account", systemImage: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: MotiveTheme.controlHeight)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MotiveTheme.warning)
            .background(MotiveTheme.elevatedSurface)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(MotiveTheme.border, lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
            .motiveCapsuleGlass(tint: MotiveTheme.elevatedSurface)
        }
        .settingsGroup()
    }

    private var versionFooter: some View {
        Text(appVersionText)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(MotiveTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, -14)
            .padding(.bottom, 8)
    }

    private func settingsInfoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MotiveTheme.secondaryText)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MotiveTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MotiveTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous))
        .motiveGlass(tint: MotiveTheme.elevatedSurface, interactive: false)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private var subscriptionStatusText: String {
        switch appState.subscriptionState {
        case .active:
            return "Premium"
        case .trial:
            return "Premium trial"
        case .free:
            return "Free"
        case .unknown:
            return "Checking"
        }
    }

    private var memberDurationText: String {
        guard let createdAt = appState.user?.createdAt else {
            return "Available after sign in"
        }

        let components = Calendar.current.dateComponents([.year, .month, .day], from: createdAt, to: .now)
        if let years = components.year, years > 0 {
            return years == 1 ? "1 year" : "\(years) years"
        }
        if let months = components.month, months > 0 {
            return months == 1 ? "1 month" : "\(months) months"
        }
        let days = max(components.day ?? 0, 0)
        return days == 0 ? "Today" : (days == 1 ? "1 day" : "\(days) days")
    }

    private func toggle(_ topic: StressTopic) {
        selectionFeedback()
        if appState.profile.selectedTopics.contains(topic) {
            appState.profile.selectedTopics.remove(topic)
        } else {
            appState.profile.selectedTopics.insert(topic)
        }
    }

    private func selectionFeedback() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

private extension View {
    func settingsGroup() -> some View {
        let outerRadius = MotiveTheme.radius + 8

        return padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MotiveTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
            .motiveGlass(cornerRadius: outerRadius, tint: MotiveTheme.surface, interactive: false)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(MotiveAppState())
    }
}
