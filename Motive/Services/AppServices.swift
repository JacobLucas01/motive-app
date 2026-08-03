import AuthenticationServices
import Foundation
#if canImport(StoreKit)
import StoreKit
#endif
import UserNotifications
#if canImport(FirebaseAuth) && canImport(FirebaseAuthInternal) && canImport(FirebaseCoreExtension) && canImport(GTMSessionFetcherCore)
import FirebaseAuth
#endif
#if canImport(UIKit)
import UIKit
#endif

protocol AuthServicing {
    func signInWithApple(result: Result<ASAuthorization, Error>, rawNonce: String?) async throws -> MotiveUser
    func signOut() async
}

protocol ProfileServicing {
    func loadProfile(for userID: String) async throws -> UserProfile?
    func loadNotificationPreference(for userID: String) async throws -> NotificationPreference?
    func saveProfile(_ profile: UserProfile, for userID: String) async throws
    func saveNotificationPreference(_ preference: NotificationPreference, for userID: String) async throws
    func deleteAccountData(for userID: String) async throws
}

protocol NotificationServicing {
    func requestAuthorization() async throws -> Bool
    func registerForRemoteNotifications() async
    func uploadAPNsDeviceToken(_ token: String) async throws
    func sendTestPush() async throws -> MotivationQuote
}

protocol MotivationServicing {
    func latestDeliveredQuote() async throws -> MotivationQuote?
}

protocol SubscriptionServicing {
    func loadSubscriptionState() async -> SubscriptionState
    func loadPremiumOffer() async -> PremiumSubscriptionOffer
    func purchasePremium() async throws -> SubscriptionState
    func restorePurchases() async throws -> SubscriptionState
}

struct AppServices {
    var auth: AuthServicing
    var profile: ProfileServicing
    var notifications: NotificationServicing
    var motivation: MotivationServicing
    var subscription: SubscriptionServicing

    @MainActor
    static let live = AppServices(
        auth: defaultAuthService,
        profile: BackendProfileService(),
        notifications: BackendNotificationService(),
        motivation: BackendMotivationService(),
        subscription: defaultSubscriptionService
    )

    @MainActor
    static let mock = AppServices(
        auth: MockAuthService(),
        profile: InMemoryProfileService(),
        notifications: SystemNotificationService(),
        motivation: MockMotivationService(),
        subscription: MockSubscriptionService()
    )

    @MainActor
    private static var defaultAuthService: AuthServicing {
        #if canImport(FirebaseAuth) && canImport(FirebaseAuthInternal) && canImport(FirebaseCoreExtension) && canImport(GTMSessionFetcherCore)
        return FirebaseAppleAuthService()
        #else
        return MockAuthService()
        #endif
    }

    @MainActor
    private static var defaultSubscriptionService: SubscriptionServicing {
        #if canImport(StoreKit)
        return StoreKitSubscriptionService(productID: PremiumSubscriptionOffer.productID)
        #else
        return MockSubscriptionService()
        #endif
    }
}

#if canImport(FirebaseAuth) && canImport(FirebaseAuthInternal) && canImport(FirebaseCoreExtension) && canImport(GTMSessionFetcherCore)
struct FirebaseAppleAuthService: AuthServicing {
    func signInWithApple(result: Result<ASAuthorization, Error>, rawNonce: String?) async throws -> MotiveUser {
        let authorization = try result.get()
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw FirebaseAppleAuthError.missingAppleCredential
        }

        guard let rawNonce else {
            throw FirebaseAppleAuthError.missingNonce
        }

        guard let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw FirebaseAppleAuthError.missingIdentityToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: appleIDCredential.fullName
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        let firebaseUser = authResult.user
        let fallbackName = appleIDCredential.fullName?.givenName ?? "Motive User"
        return MotiveUser(
            id: firebaseUser.uid,
            displayName: firebaseUser.displayName ?? fallbackName,
            email: firebaseUser.email ?? appleIDCredential.email,
            createdAt: firebaseUser.metadata.creationDate
        )
    }

    func signOut() async {
        try? Auth.auth().signOut()
    }
}

enum FirebaseAppleAuthError: LocalizedError {
    case missingAppleCredential
    case missingNonce
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .missingAppleCredential:
            return "Apple did not return a usable credential."
        case .missingNonce:
            return "Apple sign-in nonce was missing. Start sign-in again."
        case .missingIdentityToken:
            return "Apple did not return an identity token."
        }
    }
}
#endif

struct MockAuthService: AuthServicing {
    func signInWithApple(result: Result<ASAuthorization, Error>, rawNonce: String?) async throws -> MotiveUser {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let nameParts = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }
                let displayName = nameParts.isEmpty ? "Jacob" : nameParts.joined(separator: " ")
                return MotiveUser(id: credential.user, displayName: displayName, email: credential.email, createdAt: .now)
            }
            return MotiveUser(id: UUID().uuidString, displayName: "Motive User", email: nil, createdAt: .now)
        case .failure(let error):
            throw error
        }
    }

    func signOut() async { }
}

actor InMemoryProfileService: ProfileServicing {
    private var profiles: [String: UserProfile] = [:]
    private var notificationPreferences: [String: NotificationPreference] = [:]

    func loadProfile(for userID: String) async throws -> UserProfile? {
        profiles[userID]
    }

    func loadNotificationPreference(for userID: String) async throws -> NotificationPreference? {
        notificationPreferences[userID]
    }

    func saveProfile(_ profile: UserProfile, for userID: String) async throws {
        profiles[userID] = profile
    }

    func saveNotificationPreference(_ preference: NotificationPreference, for userID: String) async throws {
        notificationPreferences[userID] = preference
    }

    func deleteAccountData(for userID: String) async throws {
        profiles[userID] = nil
        notificationPreferences[userID] = nil
    }
}

struct SystemNotificationService: NotificationServicing {
    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await notificationSettings(for: center)

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            throw NotificationPermissionError.denied
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        @unknown default:
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    @MainActor
    func registerForRemoteNotifications() async {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    func uploadAPNsDeviceToken(_ token: String) async throws { }

    func sendTestPush() async throws -> MotivationQuote {
        MotivationQuote(text: "Take one clean step today.")
    }

    private func notificationSettings(for center: UNUserNotificationCenter) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
}

enum NotificationPermissionError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Notifications are turned off for Motive. Open Settings, enable notifications, then try again."
    }
}

struct MockMotivationService: MotivationServicing {
    func latestDeliveredQuote() async throws -> MotivationQuote? {
        MotivationQuote(text: "Take one clean step today.")
    }
}

#if canImport(StoreKit)
struct StoreKitSubscriptionService: SubscriptionServicing {
    let productID: String

    func loadSubscriptionState() async -> SubscriptionState {
        await currentEntitlementState()
    }

    func loadPremiumOffer() async -> PremiumSubscriptionOffer {
        do {
            let product = try await loadProduct()
            return PremiumSubscriptionOffer(
                productID: product.id,
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                periodText: "/ week",
                description: product.description
            )
        } catch {
            return .fallback
        }
    }

    func purchasePremium() async throws -> SubscriptionState {
        let product = try await loadProduct()
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            await transaction.finish()
            return await currentEntitlementState()
        case .userCancelled:
            return await currentEntitlementState()
        case .pending:
            return .free
        @unknown default:
            return await currentEntitlementState()
        }
    }

    func restorePurchases() async throws -> SubscriptionState {
        try await AppStore.sync()
        return await currentEntitlementState()
    }

    private func loadProduct() async throws -> Product {
        guard let product = try await Product.products(for: [productID]).first else {
            throw StoreKitSubscriptionError.productUnavailable
        }
        return product
    }

    private func currentEntitlementState() async -> SubscriptionState {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == productID,
                  transaction.revocationDate == nil else {
                continue
            }

            if let expirationDate = transaction.expirationDate, expirationDate < .now {
                continue
            }

            return .active
        }

        return .free
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw StoreKitSubscriptionError.unverifiedTransaction
        }
    }
}

#endif

struct MockSubscriptionService: SubscriptionServicing {
    func loadSubscriptionState() async -> SubscriptionState {
        .free
    }

    func loadPremiumOffer() async -> PremiumSubscriptionOffer {
        .fallback
    }

    func purchasePremium() async throws -> SubscriptionState {
        .trial
    }

    func restorePurchases() async throws -> SubscriptionState {
        .trial
    }
}

enum StoreKitSubscriptionError: LocalizedError {
    case productUnavailable
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "Motive Premium is not available yet. Check the subscription product ID in App Store Connect."
        case .unverifiedTransaction:
            return "The purchase could not be verified by the App Store."
        }
    }
}
