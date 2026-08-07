import Foundation
#if canImport(FirebaseAuth) && canImport(FirebaseAuthInternal) && canImport(FirebaseCoreExtension) && canImport(GTMSessionFetcherCore)
import FirebaseAuth
#endif

protocol AuthTokenProviding {
    func idToken() async throws -> String
}

struct MotiveAPIClient {
    private let baseURL: URL
    private let tokenProvider: AuthTokenProviding
    private let urlSession: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        baseURL: URL = URL(string: "https://motive-server-jacoblucas-56c18d655a99.herokuapp.com")!,
        tokenProvider: AuthTokenProviding = FirebaseAuthTokenProvider(),
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.urlSession = urlSession
    }

    func loadCurrentUser() async throws -> BackendCurrentUser {
        try await send(path: "/v1/me", method: "GET", responseType: BackendCurrentUser.self)
    }

    func saveProfile(_ profile: UserProfile) async throws {
        _ = try await send(path: "/v1/profile", method: "POST", body: profile, responseType: EmptyResponse.self)
    }

    func saveNotificationPreference(_ preference: NotificationPreference) async throws {
        _ = try await send(path: "/v1/notification-settings", method: "POST", body: preference, responseType: EmptyResponse.self)
    }

    func saveSubscriptionState(_ state: SubscriptionState) async throws {
        let body = SubscriptionStateRequest(state: state.serverValue, hasPremiumAccess: state.hasPremiumAccess)
        _ = try await send(path: "/v1/subscription-state", method: "POST", body: body, responseType: EmptyResponse.self)
    }

    func uploadAPNsToken(_ token: String) async throws {
        let body = APNsTokenRequest(token: token, environment: apnsEnvironment)
        _ = try await send(path: "/v1/devices/apns-token", method: "POST", body: body, responseType: EmptyResponse.self)
    }

    func generateQuote(for profile: UserProfile, avoiding recentQuotes: [String]) async throws -> MotivationQuote {
        let body = MotivationQuoteRequest(profile: profile, recentQuotes: recentQuotes)
        let response = try await send(path: "/v1/motivation/quote", method: "POST", body: body, responseType: MotivationQuoteResponse.self)
        return MotivationQuote(text: response.quote)
    }

    func sendTestPush() async throws -> MotivationQuote {
        let response = try await send(path: "/v1/notifications/test", method: "POST", responseType: TestPushResponse.self)
        return MotivationQuote(text: response.quote)
    }

    func deleteAccount() async throws {
        _ = try await send(path: "/v1/me", method: "DELETE", responseType: EmptyResponse.self)
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        responseType: Response.Type
    ) async throws -> Response {
        try await perform(path: path, method: method, bodyData: nil, responseType: responseType)
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body,
        responseType: Response.Type
    ) async throws -> Response {
        try await perform(path: path, method: method, bodyData: encoder.encode(body), responseType: responseType)
    }

    private func perform<Response: Decodable>(
        path: String,
        method: String,
        bodyData: Data?,
        responseType: Response.Type
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw MotiveAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await tokenProvider.idToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, urlResponse) = try await urlSession.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw MotiveAPIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let serverError = try? decoder.decode(ServerErrorResponse.self, from: data)
            throw MotiveAPIError.requestFailed(statusCode: httpResponse.statusCode, message: serverError?.error)
        }

        return try decoder.decode(Response.self, from: data)
    }

    private var apnsEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }
}

struct FirebaseAuthTokenProvider: AuthTokenProviding {
    func idToken() async throws -> String {
        #if canImport(FirebaseAuth) && canImport(FirebaseAuthInternal) && canImport(FirebaseCoreExtension) && canImport(GTMSessionFetcherCore)
        guard let currentUser = Auth.auth().currentUser else {
            throw MotiveAPIError.missingFirebaseUser
        }
        return try await currentUser.getIDToken()
        #else
        throw MotiveAPIError.firebaseAuthNotLinked
        #endif
    }
}

struct BackendCurrentUser: Decodable {
    let profile: UserProfile?
    let notificationPreference: NotificationPreference?
    let lastGeneratedQuote: BackendLastGeneratedQuote?
    let lastNotification: BackendLastNotification?

    var latestQuote: MotivationQuote? {
        let quote = lastGeneratedQuote?.quote ?? lastNotification?.quote
        guard let quote, !quote.trimmed.isEmpty else { return nil }
        return MotivationQuote(text: quote)
    }
}

struct BackendLastGeneratedQuote: Decodable {
    let quote: String?
}

struct BackendLastNotification: Decodable {
    let quote: String?
}

struct EmptyResponse: Decodable { }

struct APNsTokenRequest: Encodable {
    let token: String
    let environment: String
}

struct SubscriptionStateRequest: Encodable {
    let state: String
    let hasPremiumAccess: Bool
}

struct MotivationQuoteRequest: Encodable {
    let profile: UserProfile
    let recentQuotes: [String]
}

struct MotivationQuoteResponse: Decodable {
    let quote: String
}

private extension SubscriptionState {
    var serverValue: String {
        switch self {
        case .unknown:
            return "unknown"
        case .free:
            return "free"
        case .trial:
            return "trial"
        case .active:
            return "active"
        }
    }
}

struct TestPushResponse: Decodable {
    let quote: String
}

struct ServerErrorResponse: Decodable {
    let error: String?
}

enum MotiveAPIError: LocalizedError {
    case firebaseAuthNotLinked
    case missingFirebaseUser
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .firebaseAuthNotLinked:
            return "FirebaseAuth is not linked to the app target, so Motive cannot authenticate server requests yet."
        case .missingFirebaseUser:
            return "You need to sign in before Motive can contact the server."
        case .invalidResponse:
            return "The Motive server returned an invalid response."
        case .requestFailed(let statusCode, let message):
            return message ?? "The Motive server request failed with status \(statusCode)."
        }
    }
}
