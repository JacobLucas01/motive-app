import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct BackendProfileService: ProfileServicing {
    private let apiClient: MotiveAPIClient

    init(apiClient: MotiveAPIClient = MotiveAPIClient()) {
        self.apiClient = apiClient
    }

    func loadProfile(for userID: String) async throws -> UserProfile? {
        try await apiClient.loadCurrentUser().profile
    }

    func loadNotificationPreference(for userID: String) async throws -> NotificationPreference? {
        try await apiClient.loadCurrentUser().notificationPreference
    }

    func saveProfile(_ profile: UserProfile, for userID: String) async throws {
        try await apiClient.saveProfile(profile)
    }

    func saveNotificationPreference(_ preference: NotificationPreference, for userID: String) async throws {
        try await apiClient.saveNotificationPreference(preference)
    }

    func deleteAccountData(for userID: String) async throws {
        try await apiClient.deleteAccount()
    }
}

struct BackendNotificationService: NotificationServicing {
    private let apiClient: MotiveAPIClient

    init(apiClient: MotiveAPIClient = MotiveAPIClient()) {
        self.apiClient = apiClient
    }

    func requestAuthorization() async throws -> Bool {
        try await SystemNotificationService().requestAuthorization()
    }

    @MainActor
    func registerForRemoteNotifications() async {
        await SystemNotificationService().registerForRemoteNotifications()
    }

    func uploadAPNsDeviceToken(_ token: String) async throws {
        try await apiClient.uploadAPNsToken(token)
    }

    func sendTestPush() async throws -> MotivationQuote {
        try await apiClient.sendTestPush()
    }
}

struct BackendMotivationService: MotivationServicing {
    private let apiClient: MotiveAPIClient

    init(apiClient: MotiveAPIClient = MotiveAPIClient()) {
        self.apiClient = apiClient
    }

    func latestDeliveredQuote() async throws -> MotivationQuote? {
        try await apiClient.loadCurrentUser().lastNotificationQuote
    }
}
