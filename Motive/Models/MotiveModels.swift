import Foundation

enum AppRoute: Hashable {
    case signIn
    case onboarding
    case notifications
    case paywall
    case home
    case settings
    case savedQuotes
}

struct MotiveUser: Identifiable, Equatable, Codable {
    let id: String
    var displayName: String
    var email: String?
    var createdAt: Date?
}

enum StressTopic: String, CaseIterable, Identifiable, Codable {
    case work = "Work"
    case school = "School"
    case focus = "Focus"
    case decisions = "Decisions"
    case relationships = "Relationships"
    case money = "Money"
    case health = "Health"
    case confidence = "Confidence"
    case discipline = "Discipline"
    case energy = "Energy"

    case anxiety = "Anxiety"
    case stress = "Stress"
    case fear = "Fear"
    case loneliness = "Loneliness"
    case burnout = "Burnout"
    case pressure = "Pressure"
    case rejection = "Rejection"
    case uncertainty = "Uncertainty"
    case comparison = "Comparison"
    case overthinking = "Overthinking"

    case motivation = "Motivation"
    case consistency = "Consistency"
    case procrastination = "Procrastination"
    case ambition = "Ambition"
    case growth = "Growth"
    case success = "Success"
    case resilience = "Resilience"
    case balance = "Balance"

    case career = "Career"
    case family = "Family"
    case dating = "Dating"
    case fitness = "Fitness"
    case sleep = "Sleep"
    case purpose = "Purpose"
    case happiness = "Happiness"
    case direction = "Direction"

    var id: String { rawValue }
}

struct StressTopicGroup: Identifiable {
    let title: String
    let topics: [StressTopic]

    var id: String { title }
}

extension StressTopic {
    static let groupedFocusAreas: [StressTopicGroup] = [
        StressTopicGroup(
            title: "Daily life",
            topics: [.work, .school, .career, .money, .decisions, .direction]
        ),
        StressTopicGroup(
            title: "Mindset",
            topics: [.focus, .confidence, .discipline, .energy, .motivation, .consistency]
        ),
        StressTopicGroup(
            title: "Stress and emotions",
            topics: [.anxiety, .stress, .fear, .pressure, .overthinking, .burnout]
        ),
        StressTopicGroup(
            title: "Growth",
            topics: [.procrastination, .ambition, .growth, .success, .resilience, .purpose]
        ),
        StressTopicGroup(
            title: "Personal",
            topics: [.relationships, .family, .dating, .health, .fitness, .sleep]
        ),
        StressTopicGroup(
            title: "Self-worth",
            topics: [.happiness, .balance, .loneliness, .rejection, .comparison, .uncertainty]
        )
    ]
}

struct UserProfile: Equatable, Codable {
    var preferredName: String = ""
    var selectedTopics: Set<StressTopic> = []
    var biggestProblem: String = ""
    var customContext: String = ""

    var isComplete: Bool {
        !selectedTopics.isEmpty || !biggestProblem.trimmed.isEmpty || !customContext.trimmed.isEmpty
    }

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredName = try container.decodeIfPresent(String.self, forKey: .preferredName) ?? ""
        selectedTopics = try container.decodeIfPresent(Set<StressTopic>.self, forKey: .selectedTopics) ?? []
        biggestProblem = try container.decodeIfPresent(String.self, forKey: .biggestProblem) ?? ""
        customContext = try container.decodeIfPresent(String.self, forKey: .customContext) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preferredName, forKey: .preferredName)
        try container.encode(selectedTopics, forKey: .selectedTopics)
        try container.encode(biggestProblem, forKey: .biggestProblem)
        try container.encode(customContext, forKey: .customContext)
    }

    private enum CodingKeys: String, CodingKey {
        case preferredName
        case selectedTopics
        case biggestProblem
        case customContext
    }
}

enum NotificationTiming: String, CaseIterable, Identifiable, Codable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case random = "Random"
    case custom = "Custom"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .morning:
            return "Start the day focused"
        case .afternoon:
            return "Reset midway through"
        case .evening:
            return "End the day steady"
        case .random:
            return "A useful nudge anytime"
        case .custom:
            return "Pick your own time"
        }
    }
}

struct NotificationPreference: Equatable, Codable {
    var isEnabled = false
    var timing: NotificationTiming = .morning
    var customHour = 8
    var customMinute = 0
    var timezoneIdentifier = TimeZone.current.identifier
}

enum SubscriptionState: Equatable {
    case unknown
    case free
    case trial
    case active

    var hasPremiumAccess: Bool {
        switch self {
        case .trial, .active:
            return true
        case .unknown, .free:
            return false
        }
    }
}

struct PremiumSubscriptionOffer: Equatable {
    static let productID = "motive_premium_weekly"

    var productID: String = Self.productID
    var displayName: String = "Motive Premium Weekly"
    var displayPrice: String = "$0.99"
    var periodText: String = "/ week"
    var description: String = "Personalized motivational notifications each week."

    static let fallback = PremiumSubscriptionOffer()
}

struct MotivationQuote: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var createdAt: Date = .now
}

struct SavedQuote: Identifiable, Equatable, Codable {
    var id = UUID()
    var text: String
    var savedAt: Date = .now
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
