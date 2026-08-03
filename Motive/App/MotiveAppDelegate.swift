import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

enum APNsDeviceTokenCenter {
    static let didRegisterToken = Notification.Name("Motive.APNsDeviceTokenCenter.didRegisterToken")
    static let didFailToRegister = Notification.Name("Motive.APNsDeviceTokenCenter.didFailToRegister")
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
        [.banner, .list, .sound]
    }
}
#endif
