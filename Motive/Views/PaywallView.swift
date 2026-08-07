import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var appState: MotiveAppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("More with Premium")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(MotiveTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("Unlock notifications tailored to your profile and schedule.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(MotiveTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(spacing: 12) {
                        PaywallBenefit(icon: "quote.opening", title: "Real quotes", detail: "Motivational quotes, selected for what you are dealing with.")
                        PaywallBenefit(icon: "bell.badge", title: "Scheduled pushes", detail: "Morning, afternoon, evening, random, or custom timing.")
                        PaywallBenefit(icon: "heart.text.square", title: "Based on how you feel", detail: "Your focus areas and current problem shape what gets sent.")
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(appState.premiumOffer.displayPrice)
                        .font(.system(size: 32, weight: .bold))
                    Text(appState.premiumOffer.periodText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MotiveTheme.secondaryText)
                }
                
                Text("About $0.14 per day. Cancel anytime.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MotiveTheme.secondaryText)
            }
            
            VStack(spacing: 12) {
                MotivePrimaryButton(title: "Get Premium", systemImage: "sparkle") {
                    Task {
                        await appState.purchasePremium()
                    }
                }
                
                MotiveSecondaryButton(title: "Restore purchase", systemImage: "arrow.clockwise") {
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
