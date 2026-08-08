import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

enum APNsDeviceTokenCenter {
    static let didRegisterToken = Notification.Name("Motive.APNsDeviceTokenCenter.didRegisterToken")
    static let didFailToRegister = Notification.Name("Motive.APNsDeviceTokenCenter.didFailToRegister")
    static let didReceiveMotivationQuote = Notification.Name("Motive.APNsDeviceTokenCenter.didReceiveMotivationQuote")
    static var latestToken: String?
}

#if canImport(UIKit)
final class MotiveAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        APNsDeviceTokenCenter.latestToken = token
        NotificationCenter.default.post(
            name: APNsDeviceTokenCenter.didRegisterToken,
            object: nil,
            userInfo: ["token": token]
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationCenter.default.post(
            name: APNsDeviceTokenCenter.didFailToRegister,
            object: nil,
            userInfo: ["error": error]
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        saveWidgetQuoteIfPossible(from: notification)
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        saveWidgetQuoteIfPossible(from: response.notification)
    }

    private func saveWidgetQuoteIfPossible(from notification: UNNotification) {
        let content = notification.request.content
        guard content.userInfo["type"] as? String == "motivation" else { return }
        let quote = content.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quote.isEmpty else { return }

        MotiveWidgetQuoteStore.save(quote)
        NotificationCenter.default.post(
            name: APNsDeviceTokenCenter.didReceiveMotivationQuote,
            object: nil,
            userInfo: ["quote": quote]
        )
    }
}
#endif
