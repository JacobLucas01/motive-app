import AuthenticationServices
import Combine
import Foundation
import SwiftUI

@MainActor
final class MotiveAppState: ObservableObject {
    private let services: AppServices

    @Published var route: AppRoute = .signIn
    @Published var user: MotiveUser?
    @Published var profile = UserProfile()
    @Published var notificationPreference = NotificationPreference()
    @Published var subscriptionState: SubscriptionState = .unknown
    @Published var premiumOffer = PremiumSubscriptionOffer.fallback
    @Published var currentQuote = MotivationQuote(text: "Your next quote will appear here after a notification.")
    @Published var isWorking = false
    @Published var errorMessage: String?

    private var currentAppleNonce: String?
    private var notificationObservers: [NSObjectProtocol] = []

    convenience init() {
        self.init(services: .live)
    }

    init(services: AppServices) {
        self.services = services
        observeAPNsRegistration()
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func bootstrap() async {
        async let state = services.subscription.loadSubscriptionState()
        async let offer = services.subscription.loadPremiumOffer()
        subscriptionState = await state
        premiumOffer = await offer

        guard let restoredUser = await services.auth.currentUser() else { return }
        await runTask {
            try await loadSession(for: restoredUser)
        }
    }

    func loadPremiumOffer() async {
        premiumOffer = await services.subscription.loadPremiumOffer()
    }

    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try AppleSignInNonce.random()
            currentAppleNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithApple(result: Result<ASAuthorization, Error>) async {
        if case .failure(let error) = result {
            errorMessage = signInWithAppleMessage(for: error)
            return
        }

        await runTask {
            let signedInUser = try await services.auth.signInWithApple(result: result, rawNonce: currentAppleNonce)
            currentAppleNonce = nil
            try await loadSession(for: signedInUser)
        }
    }

    func usePreviewAccount() async {
        await runTask {
            let previewUser = MotiveUser(id: "preview-user", displayName: "Jacob", email: nil, createdAt: .now)
            user = previewUser
            route = profile.isComplete ? .notifications : .onboarding
        }
    }

    func saveProfileAndContinue() async {
        guard let user else { return }
        await runTask {
            try await services.profile.saveProfile(profile, for: user.id)
            try await uploadLatestAPNsTokenIfPossible()
            route = .notifications
        }
    }

    func saveSettingsAndReturnHome() async {
        guard let user else { return }
        await runTask {
            try await persistSettings(for: user)
            try await uploadLatestAPNsTokenIfPossible()
            route = .home
        }
    }

    func persistCurrentSettingsIfPossible() async {
        guard let user else { return }
        do {
            try await persistSettings(for: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func enableNotificationsAndContinue() async {
        guard let user else { return }
        await runTask {
            let granted = try await services.notifications.requestAuthorization()
            notificationPreference.isEnabled = granted
            try await services.profile.saveNotificationPreference(notificationPreference, for: user.id)
            if granted {
                await services.notifications.registerForRemoteNotifications()
                try await uploadLatestAPNsTokenIfPossible()
            }
            route = subscriptionState.hasPremiumAccess ? .home : .paywall
        }
    }

    func skipNotifications() async {
        guard let user else { return }
        await runTask {
            notificationPreference.isEnabled = false
            try await services.profile.saveNotificationPreference(notificationPreference, for: user.id)
            route = subscriptionState.hasPremiumAccess ? .home : .paywall
        }
    }

    func purchasePremium() async {
        await runTask {
            subscriptionState = try await services.subscription.purchasePremium()
            if subscriptionState.hasPremiumAccess {
                try await loadDeliveredQuote()
                route = .home
            }
        }
    }

    func restorePurchases() async {
        await runTask {
            subscriptionState = try await services.subscription.restorePurchases()
            if subscriptionState.hasPremiumAccess {
                try await loadDeliveredQuote()
                route = .home
            }
        }
    }

    func continueWithoutPremium() async {
        await runTask {
            subscriptionState = .free
            try await loadDeliveredQuote()
            route = .home
        }
    }

    var canSendStagingPush: Bool {
        guard user != nil else { return false }

        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    func loadDeliveredQuote() async throws {
        if let deliveredQuote = try await services.motivation.latestDeliveredQuote() {
            currentQuote = deliveredQuote
        }
    }

    func sendStagingTestPush() async {
        await runTask {
            if APNsDeviceTokenCenter.latestToken == nil {
                await services.notifications.registerForRemoteNotifications()
            }
            try await uploadLatestAPNsTokenIfPossible()
            let pushedQuote = try await services.notifications.sendTestPush()
            currentQuote = pushedQuote
        }
    }

    func uploadLatestAPNsTokenIfPossible() async throws {
        guard user != nil, let token = APNsDeviceTokenCenter.latestToken else { return }
        try await services.notifications.uploadAPNsDeviceToken(token)
    }

    func deleteAccount() async {
        guard let user else { return }
        await runTask {
            try await services.profile.deleteAccountData(for: user.id)
            await services.auth.signOut()
            resetSession()
        }
    }

    func signOut() async {
        await services.auth.signOut()
        resetSession()
    }

    private func resetSession() {
        user = nil
        profile = UserProfile()
        notificationPreference = NotificationPreference()
        subscriptionState = .unknown
        route = .signIn
    }

    private func loadSession(for signedInUser: MotiveUser) async throws {
        user = signedInUser
        if let savedPreference = try await services.profile.loadNotificationPreference(for: signedInUser.id) {
            notificationPreference = savedPreference
        }
        if let savedProfile = try await services.profile.loadProfile(for: signedInUser.id) {
            profile = savedProfile
            try await loadDeliveredQuote()
            try await uploadLatestAPNsTokenIfPossible()
            route = notificationPreference.isEnabled ? .home : .notifications
        } else {
            try await uploadLatestAPNsTokenIfPossible()
            route = .onboarding
        }
    }

    private func persistSettings(for user: MotiveUser) async throws {
        notificationPreference.timezoneIdentifier = TimeZone.current.identifier
        try await services.profile.saveProfile(profile, for: user.id)
        try await services.profile.saveNotificationPreference(notificationPreference, for: user.id)
    }

    private func observeAPNsRegistration() {
        let tokenObserver = NotificationCenter.default.addObserver(
            forName: APNsDeviceTokenCenter.didRegisterToken,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let token = notification.userInfo?["token"] as? String else { return }
            Task { @MainActor in
                guard self.user != nil else { return }
                await self.runTask {
                    try await self.services.notifications.uploadAPNsDeviceToken(token)
                }
            }
        }

        let failureObserver = NotificationCenter.default.addObserver(
            forName: APNsDeviceTokenCenter.didFailToRegister,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let error = notification.userInfo?["error"] as? Error else { return }
            Task { @MainActor in
                self.errorMessage = error.localizedDescription
            }
        }

        notificationObservers = [tokenObserver, failureObserver]
    }

    private func runTask(_ operation: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signInWithAppleMessage(for error: Error) -> String {
        guard let authorizationError = error as? ASAuthorizationError else {
            return error.localizedDescription
        }

        switch authorizationError.code {
        case .canceled:
            return "Sign in was canceled."
        case .unknown:
            return "Apple sign-in is not ready for this app. Check Sign in with Apple capability, bundle ID, Firebase Apple provider, and device Apple ID settings."
        case .failed:
            return "Apple sign-in failed. Check your Apple ID and try again."
        case .invalidResponse:
            return "Apple returned an invalid sign-in response. Try again."
        case .notHandled:
            return "Apple sign-in was not handled by the system. Try again."
        case .notInteractive:
            return "Apple sign-in needs an interactive session. Try again from the app screen."
        case .matchedExcludedCredential:
            return "This Apple credential cannot be used for this sign-in flow."
        case .credentialImport, .credentialExport:
            return "This Apple credential operation is not supported in this sign-in flow."
        default:
            return error.localizedDescription
        }
    }
}
