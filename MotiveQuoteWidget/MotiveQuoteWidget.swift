import SwiftUI
import WidgetKit

private enum MotiveWidgetQuoteStore {
    static let widgetKind = "MotiveQuoteWidget"
    static let appGroupID = "group.com.jacoblucas.Motive"

    private static let quoteKey = "motive.widget.latestQuote"
    private static let fallbackQuote = "Take one clean step today."

    static var latestQuoteText: String {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let quote = defaults.string(forKey: quoteKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !quote.isEmpty else {
            return fallbackQuote
        }
        return quote
    }
}

struct MotiveQuoteEntry: TimelineEntry {
    let date: Date
    let quote: String
}

struct MotiveQuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> MotiveQuoteEntry {
        MotiveQuoteEntry(date: .now, quote: "Take one clean step today.")
    }

    func getSnapshot(in context: Context, completion: @escaping (MotiveQuoteEntry) -> Void) {
        completion(MotiveQuoteEntry(date: .now, quote: MotiveWidgetQuoteStore.latestQuoteText))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MotiveQuoteEntry>) -> Void) {
        let entry = MotiveQuoteEntry(date: .now, quote: MotiveWidgetQuoteStore.latestQuoteText)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct MotiveQuoteWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: MotiveQuoteEntry

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(entry.quote)
                .font(font)
                .foregroundStyle(.white)
                .multilineTextAlignment(textAlignment)
                .lineLimit(lineLimit)
                .minimumScaleFactor(minimumScaleFactor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)

            if showsCornerLogo {
                Image("MotiveLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .padding(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.clear, for: .widget)
    }

    private var showsCornerLogo: Bool {
        switch widgetFamily {
        case .systemSmall, .systemMedium:
            return true
        default:
            return false
        }
    }

    private var font: Font {
        switch widgetFamily {
        case .accessoryInline:
            return .system(size: 13, weight: .semibold)
        case .accessoryRectangular:
            return .system(size: 15, weight: .bold)
        default:
            return .system(size: 22, weight: .bold)
        }
    }

    private var textAlignment: TextAlignment {
        switch widgetFamily {
        case .accessoryInline, .accessoryRectangular:
            return .leading
        default:
            return .center
        }
    }

    private var alignment: Alignment {
        switch widgetFamily {
        case .accessoryInline, .accessoryRectangular:
            return .leading
        default:
            return .center
        }
    }

    private var lineLimit: Int {
        switch widgetFamily {
        case .accessoryInline:
            return 1
        case .accessoryRectangular:
            return 3
        default:
            return 5
        }
    }

    private var minimumScaleFactor: CGFloat {
        switch widgetFamily {
        case .accessoryInline:
            return 0.75
        case .accessoryRectangular:
            return 0.7
        default:
            return 0.58
        }
    }
}

struct MotiveQuoteWidget: Widget {
    let kind = MotiveWidgetQuoteStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MotiveQuoteProvider()) { entry in
            MotiveQuoteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Motive Quote")
        .description("Shows your latest Motive quote.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    MotiveQuoteWidget()
} timeline: {
    MotiveQuoteEntry(date: .now, quote: "Take one clean step today.")
}
