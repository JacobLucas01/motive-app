import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var appState: MotiveAppState

    private var legalURL: URL {
        URL(string: "https://example.com/legal") ?? URL(fileURLWithPath: "/")
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 36)

                VStack(spacing: 14) {
                    Circle()
                        .fill(MotiveTheme.accent)
                        .frame(width: 64, height: 64)

                    Text("Motive")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(MotiveTheme.primaryText)

                    Text("Short, personal motivation when your day needs a reset.")
                        .font(.system(size: 16, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(MotiveTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 320)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 44)

                VStack(spacing: 14) {
                    SignInWithAppleButton(.continue) { request in
                        appState.configureAppleSignInRequest(request)
                    } onCompletion: { result in
                        Task {
                            await appState.signInWithApple(result: result)
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: MotiveTheme.controlHeight)
                    .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous))
                    .motiveGlass(tint: .white)

                    Link("By creating an account, you agree to our Privacy Policy and Terms.", destination: legalURL)
                        .font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(MotiveTheme.secondaryText)
                        .tint(MotiveTheme.secondaryText)
                        .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(MotiveTheme.pagePadding)
            .frame(minHeight: proxy.size.height, alignment: .bottom)
        }
        .motiveScreen()
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .environmentObject(MotiveAppState())
    }
}
