import CoreMotion
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: MotiveAppState
    @State private var quoteOffset: CGSize = .zero
    @State private var motion = QuoteMotionModel()

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    Spacer(minLength: 54)

                    quoteCard
                        .offset(quoteOffset)
                        .animation(.smooth(duration: 0.18), value: quoteOffset)

                    Spacer(minLength: 54)

                    actionButtons
                }
                .padding(MotiveTheme.pagePadding)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .motiveScreen()
        }
        .onAppear {
            motion.start { offset in
                quoteOffset = offset
            }
        }
        .onDisappear {
            motion.stop()
            quoteOffset = .zero
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Today")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MotiveTheme.accent)
                Text("Hi, \(greetingName)")
                    .font(.system(size: 30, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 12)

            Button {
                appState.route = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MotiveTheme.secondaryText)
            .background(MotiveTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous))
            .motiveGlass(tint: MotiveTheme.elevatedSurface)
        }
    }

    private var quoteCard: some View {
        VStack(alignment: .center, spacing: 18) {
            Image(systemName: "quote.opening")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(MotiveTheme.accent)

            Text(appState.currentQuote.text)
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(MotiveTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Latest notification quote")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MotiveTheme.secondaryText)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(MotiveTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius + 6, style: .continuous))
        .motiveGlass(cornerRadius: MotiveTheme.radius + 6, tint: MotiveTheme.surface, interactive: false)
    }


    private var actionButtons: some View {
        VStack(spacing: 12) {
            if appState.canSendStagingPush {
                MotivePrimaryButton(
                    title: appState.isWorking ? "Sending..." : "New quote",
                    systemImage: "bell.badge",
                    isDisabled: appState.isWorking
                ) {
                    Task {
                        await appState.sendStagingTestPush()
                    }
                }
            }

            if appState.subscriptionState == .free {
                MotiveSecondaryButton(title: "View premium", systemImage: "crown") {
                    appState.route = .paywall
                }
            }

        }
        .frame(maxWidth: .infinity)
    }

    private var greetingName: String {
        let preferredName = appState.profile.preferredName.trimmed
        if !preferredName.isEmpty {
            return firstName(from: preferredName)
        }

        guard let displayName = appState.user?.displayName.trimmed,
              !displayName.isEmpty,
              displayName != "Motive User" else {
            return "there"
        }

        return firstName(from: displayName)
    }

    private func firstName(from name: String) -> String {
        name.components(separatedBy: .whitespacesAndNewlines).first ?? name
    }
}

private final class QuoteMotionModel {
    private let manager = CMMotionManager()
    private let maxOffset: CGFloat = 10

    func start(onChange: @escaping (CGSize) -> Void) {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let roll = CGFloat(motion.attitude.roll)
            let pitch = CGFloat(motion.attitude.pitch)
            onChange(
                CGSize(
                    width: self.clamped(roll * self.maxOffset),
                    height: self.clamped(-pitch * self.maxOffset * 0.55)
                )
            )
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, -maxOffset), maxOffset)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(MotiveAppState())
    }
}
