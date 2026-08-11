import Foundation
import UserNotifications
import WidgetKit

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var originalContent: UNNotificationContent?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        originalContent = request.content
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        if let quote = MotivationNotificationQuote.extract(from: request.content) {
            MotivationNotificationQuote.saveForWidget(quote)
        }

        contentHandler(bestAttemptContent ?? request.content)
    }

    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler, let content = bestAttemptContent ?? originalContent else { return }
        contentHandler(content)
    }
}

private enum MotivationNotificationQuote {
    private static let appGroupID = "group.com.jacoblucas.Motive"
    private static let quoteKey = "motive.widget.latestQuote"
    private static let updatedAtKey = "motive.widget.latestQuoteUpdatedAt"
    private static let widgetKind = "MotiveQuoteWidget"

    static func extract(from content: UNNotificationContent) -> String? {
        let userInfo = content.userInfo
        let notificationType = userInfo["type"] as? String
        let customQuote = stringValue(for: "quote", in: userInfo)
            ?? stringValue(for: "latestQuote", in: userInfo)
            ?? stringValue(for: "body", in: userInfo)
        let alertQuote = content.body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard notificationType == "motivation" || customQuote != nil else { return nil }

        let quote = (customQuote ?? alertQuote).trimmingCharacters(in: .whitespacesAndNewlines)
        return quote.isEmpty ? nil : quote
    }

    static func saveForWidget(_ quote: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        defaults.set(quote, forKey: quoteKey)
        defaults.set(Date(), forKey: updatedAtKey)
        defaults.synchronize()

        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    private static func stringValue(for key: String, in userInfo: [AnyHashable: Any]) -> String? {
        guard let value = userInfo[key] as? String else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
