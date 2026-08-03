import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var appState: MotiveAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Keep it personal")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(MotiveTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Unlock generated motivation notifications tailored to your profile and schedule.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MotiveTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                PaywallBenefit(icon: "quote.opening", title: "Real quotes", detail: "Motivation from real people, selected for what you are dealing with.")
                PaywallBenefit(icon: "bell.badge", title: "Scheduled pushes", detail: "Morning, afternoon, evening, random, or custom timing.")
                PaywallBenefit(icon: "heart.text.square", title: "Based on how you feel", detail: "Your focus areas and current problem shape what gets sent.")
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(appState.premiumOffer.displayPrice)
                        .font(.system(size: 32, weight: .bold))
                    Text(appState.premiumOffer.periodText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MotiveTheme.secondaryText)
                }

                Text("Cancel anytime. About $0.14 per day.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MotiveTheme.secondaryText)
            }

            VStack(spacing: 12) {
                MotivePrimaryButton(title: "Start free trial", systemImage: "sparkle") {
                    Task {
                        await appState.purchasePremium()
                    }
                }

                MotiveSecondaryButton(title: "Restore purchases", systemImage: "arrow.clockwise") {
                    Task {
                        await appState.restorePurchases()
                    }
                }

                Button("Continue without premium") {
                    Task {
                        await appState.continueWithoutPremium()
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MotiveTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 36)
            }
        }
        .padding(MotiveTheme.pagePadding)
        .motiveScreen()
        .task {
            await appState.loadPremiumOffer()
        }
    }
}

private struct PaywallBenefit: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MotiveTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MotiveTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MotiveTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous))
        .motiveGlass(tint: MotiveTheme.elevatedSurface, interactive: false)
    }
}

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
            .environmentObject(MotiveAppState())
    }
}
