import FirebaseCore
import SwiftUI

@main
struct MotiveApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(MotiveAppDelegate.self) private var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = MotiveAppState()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .background else { return }
                    Task {
                        await appState.persistCurrentSettingsIfPossible()
                    }
                }
        }
    }
}
