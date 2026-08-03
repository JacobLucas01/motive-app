import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: MotiveAppState
    @State private var isShowingLaunchSplash = true
    @State private var rootRoute: AppRoute = .signIn
    @State private var navigationPath: [AppRoute] = []

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
                routeView(for: rootRoute)
                    .navigationDestination(for: AppRoute.self) { route in
                        routeView(for: route)
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationBarBackButtonHidden(true)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
            }

            if isShowingLaunchSplash {
                LaunchSplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }

            if appState.isWorking {
                LoadingOverlay()
                    .zIndex(8)
            }
        }
        .statusBarHidden(true)
        .alert(
            "Motive could not finish",
            isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { if !$0 { appState.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                appState.errorMessage = nil
            }
        } message: {
            Text(appState.errorMessage ?? "Try again.")
        }
        .onChange(of: appState.route) { _, newRoute in
            syncNavigation(to: newRoute)
        }
        .onChange(of: navigationPath) { _, newPath in
            let visibleRoute = newPath.last ?? rootRoute
            if appState.route != visibleRoute {
                appState.route = visibleRoute
            }
        }
        .task {
            syncNavigation(to: appState.route)
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.28)) {
                isShowingLaunchSplash = false
            }
        }
    }

    private func syncNavigation(to route: AppRoute) {
        switch route {
        case .signIn, .onboarding, .notifications:
            rootRoute = route
            navigationPath = []
        case .paywall:
            if rootRoute == .home {
                navigationPath = [.paywall]
            } else {
                rootRoute = .paywall
                navigationPath = []
            }
        case .home:
            rootRoute = .home
            navigationPath = []
        case .settings:
            if rootRoute != .home {
                rootRoute = .home
            }
            navigationPath = [.settings]
        }
    }

    @ViewBuilder
    private func routeView(for route: AppRoute) -> some View {
        switch route {
        case .signIn:
            SignInView()
        case .onboarding:
            OnboardingView()
        case .notifications:
            NotificationSetupView()
        case .paywall:
            PaywallView()
        case .home:
            HomeView()
        case .settings:
            SettingsView()
        }
    }
}

private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            ProgressView()
                .tint(MotiveTheme.accent)
                .scaleEffect(1.1)
                .padding(22)
                .motiveLoadingGlassBackground()
        }
    }
}

private extension View {
    @ViewBuilder
    func motiveLoadingGlassBackground() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: MotiveTheme.radius + 4))
        } else {
            background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: MotiveTheme.radius + 4, style: .continuous)
                        .stroke(MotiveTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius + 4, style: .continuous))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MotiveAppState())
    }
}
