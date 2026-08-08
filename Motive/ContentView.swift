import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: MotiveAppState
    @State private var rootRoute: AppRoute = .signIn
    @State private var navigationPath: [AppRoute] = []

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
                routeView(for: currentRootRoute)
                    .navigationDestination(for: AppRoute.self) { route in
                        routeView(for: route)
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationBarBackButtonHidden(true)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
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
        .alert(
            "Motive",
            isPresented: Binding(
                get: { appState.noticeMessage != nil },
                set: { if !$0 { appState.noticeMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                appState.noticeMessage = nil
            }
        } message: {
            Text(appState.noticeMessage ?? "")
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
        }
    }

    private var currentRootRoute: AppRoute {
        guard navigationPath.isEmpty else { return rootRoute }

        switch appState.route {
        case .home, .settings, .savedQuotes:
            return .home
        default:
            return rootRoute
        }
    }

    private func syncNavigation(to route: AppRoute) {
        switch route {
        case .signIn:
            rootRoute = .signIn
            navigationPath = []
        case .onboarding:
            rootRoute = .signIn
            navigationPath = [.onboarding]
        case .paywall:
            if isInNewUserFlow {
                navigationPath = newUserPath(endingAt: .paywall)
            } else if rootRoute == .home {
                navigationPath = [.paywall]
            } else {
                rootRoute = .paywall
                navigationPath = []
            }
        case .notifications:
            if isInNewUserFlow {
                navigationPath = newUserPath(endingAt: .notifications)
            } else if rootRoute == .home, navigationPath.contains(.paywall) {
                navigationPath = [.paywall, .notifications]
            } else {
                rootRoute = .notifications
                navigationPath = []
            }
        case .home:
            rootRoute = .home
            navigationPath = []
        case .settings, .savedQuotes:
            rootRoute = .home
            navigationPath = [route]
        }
    }

    private var isInNewUserFlow: Bool {
        rootRoute == .signIn || navigationPath.contains(.onboarding)
    }

    private func newUserPath(endingAt route: AppRoute) -> [AppRoute] {
        var path: [AppRoute] = [.onboarding]
        if navigationPath.contains(.paywall) || route == .paywall {
            path.append(.paywall)
        }
        if route == .notifications {
            path.append(.notifications)
        }
        return path
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
        case .savedQuotes:
            SavedQuotesView()
        }
    }
}


private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            ProgressView()
                .tint(.white)
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
            glassEffect(.clear, in: .rect(cornerRadius: MotiveTheme.radius + 4))
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
