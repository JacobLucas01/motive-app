import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @EnvironmentObject private var appState: MotiveAppState
    @State private var isShowingCopied = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    Spacer(minLength: 54)

                    quoteCard

                    Spacer(minLength: 54)

                    actionButtons
                }
                .padding(MotiveTheme.pagePadding)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .motiveScreen()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("\(timeOfDayGreeting),\n\(greetingName)")
                .font(.system(size: 25, weight: .bold))
                .minimumScaleFactor(0.82)

            Spacer(minLength: 12)

            Button {
                performSelectionHaptic()
                appState.route = .savedQuotes
            } label: {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MotiveTheme.primaryText)

            Button {
                performSelectionHaptic()
                appState.route = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MotiveTheme.primaryText)
        }
    }

    private var quoteCard: some View {
        VStack(alignment: .center, spacing: 22) {
            Image(systemName: "quote.opening")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(MotiveTheme.primaryText)

            Text(appState.currentQuote.text)
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(MotiveTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                Button {
                    copyCurrentQuote()
                } label: {
                    Image(systemName: isShowingCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(MotiveTheme.accent)

                ShareLink(item: appState.currentQuote.text) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(MotiveTheme.primaryText)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .center)
    }


    private var actionButtons: some View {
        VStack(spacing: 12) {
            if appState.subscriptionState.hasPremiumAccess {
                MotivePrimaryButton(
                    title: appState.isWorking ? "Loading..." : "New quote",
                    systemImage: "sparkles",
                    isDisabled: appState.isWorking
                ) {
                    Task {
                        await appState.generatePremiumQuote()
                    }
                }
            }

            MotiveSecondaryButton(
                title: appState.isCurrentQuoteSaved ? "Unsave quote" : "Save quote",
                systemImage: appState.isCurrentQuoteSaved ? "bookmark.fill" : "bookmark"
            ) {
                toggleSavedQuote()
            }

            if appState.subscriptionState == .free {
                MotiveSecondaryButton(
                    title: "View premium",
                    systemImage: "crown",
                    iconColor: Color(red: 1.0, green: 0.76, blue: 0.22)
                ) {
                    appState.route = .paywall
                }
            }

        }
        .frame(maxWidth: .infinity)
    }

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
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

    private func toggleSavedQuote() {
        performSelectionHaptic()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            appState.toggleCurrentQuoteSaved()
        }
    }

    private func copyCurrentQuote() {
        performSelectionHaptic()
        #if canImport(UIKit)
        UIPasteboard.general.string = appState.currentQuote.text
        #endif
        isShowingCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            isShowingCopied = false
        }
    }

    private func performSelectionHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(MotiveAppState())
    }
}
