import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum MotiveWidgetQuoteStore {
    static let widgetKind = "MotiveQuoteWidget"
    static let appGroupID = "group.com.jacoblucas.Motive"

    private static let quoteKey = "motive.widget.latestQuote"
    private static let updatedAtKey = "motive.widget.latestQuoteUpdatedAt"
    private static let fallbackQuote = "Take one clean step today."

    static var latestQuoteText: String {
        latestSavedQuoteText ?? fallbackQuote
    }

    static var latestSavedQuoteText: String? {
        readQuote(from: sharedDefaults) ?? readQuote(from: .standard)
    }

    static func save(_ quote: MotivationQuote) {
        save(quote.text)
    }

    static func save(_ quoteText: String) {
        let cleanQuote = quoteText.trimmed.isEmpty ? fallbackQuote : quoteText.trimmed
        write(cleanQuote, to: .standard)

        if let sharedDefaults {
            write(cleanQuote, to: sharedDefaults)
            sharedDefaults.synchronize()
        }

        UserDefaults.standard.synchronize()
        reloadWidgets()
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static func readQuote(from defaults: UserDefaults?) -> String? {
        guard let quote = defaults?.string(forKey: quoteKey)?.trimmed, !quote.isEmpty else {
            return nil
        }
        return quote
    }

    private static func write(_ quote: String, to defaults: UserDefaults) {
        defaults.set(quote, forKey: quoteKey)
        defaults.set(Date(), forKey: updatedAtKey)
    }
}
