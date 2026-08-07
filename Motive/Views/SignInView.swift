import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var appState: MotiveAppState

    private var legalURL: URL {
        URL(string: "https://jacoblucas01.github.io/motive-app/") ?? URL(fileURLWithPath: "/")
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 36)

                VStack(spacing: 18) {
                    Image("MotiveLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)

                    Text("Motivating words sent when you\nneed a push.")
                        .font(.system(size: 18, weight: .medium))
                        .lineSpacing(6)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(MotiveTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 44)

                VStack(spacing: 16) {
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
                        .lineSpacing(6)
                        .padding(.horizontal)
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
