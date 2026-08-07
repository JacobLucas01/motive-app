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
    case stuck = "Stuck"
    case focus = "Focus"
    case decisions = "Decisions"
    case relationships = "Relationships"
    case money = "Money"
    case health = "Health"
    case confidence = "Confidence"
    case discipline = "Discipline"
    case energy = "Energy"
    case habits = "Habits"
    case courage = "Courage"
    case purpose = "Purpose"

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "Work", "Work stress":
            self = .work
        case "School", "School pressure":
            self = .school
        case "Stuck", "Feeling stuck":
            self = .stuck
        case "Focus", "Low motivation":
            self = .focus
        case "Decisions", "Big decision":
            self = .decisions
        case "Relationships", "Relationship stress":
            self = .relationships
        case "Money", "Money worries":
            self = .money
        case "Health", "Health habits":
            self = .health
        case "Confidence":
            self = .confidence
        case "Discipline":
            self = .discipline
        case "Energy":
            self = .energy
        case "Habits":
            self = .habits
        case "Courage":
            self = .courage
        case "Purpose":
            self = .purpose
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown profile signal: \(value)"))
        }
    }
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
