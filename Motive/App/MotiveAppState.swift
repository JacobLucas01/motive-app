import AuthenticationServices
import Combine
import Foundation
import SwiftUI
import UserNotifications
import Firebase
import FirebaseFirestore

@MainActor
final class MotiveAppState: ObservableObject {
    private static let defaultQuoteText = "Your first quote is being prepared."

    private let services: AppServices
    private let profileCache = UserDefaultsProfileCache()

    @Published var route: AppRoute = .signIn
    @Published var user: MotiveUser?
    @Published var profile = UserProfile()
    @Published var notificationPreference = NotificationPreference()
    @Published var subscriptionState: SubscriptionState = .unknown
    @Published var premiumOffer = PremiumSubscriptionOffer.fallback
    @Published var savedQuotes: [SavedQuote] = []
    @Published var currentQuote = MotivationQuote(text: MotiveAppState.defaultQuoteText) {
        didSet {
            MotiveWidgetQuoteStore.save(currentQuote)
        }
    }
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    private var currentAppleNonce: String?
    private var notificationObservers: [NSObjectProtocol] = []
    private let dailyNewQuoteLimit = 5
    private let recentQuoteMemoryLimit = 6
    private let recentQuoteCharacterLimit = 90
    private let savedQuoteNotificationPrefix = "motive.savedQuoteRepeat"
    
    private var latestQuoteListener: ListenerRegistration?

    convenience init() {
        self.init(services: .live)
    }

    init(services: AppServices) {
        self.services = services
        restoreCachedSessionIfPossible()
        if let savedQuote = MotiveWidgetQuoteStore.latestSavedQuoteText {
            currentQuote = MotivationQuote(text: savedQuote)
        }
        repeatSavedQuoteInMainQuoteIfAvailable(chanceDivisor: 5)
        MotiveWidgetQuoteStore.reloadWidgets()
        observeAPNsRegistration()
    }

    deinit {
        latestQuoteListener?.remove()

        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func startListeningForLatestQuote(for user: MotiveUser) {
        latestQuoteListener?.remove()

        latestQuoteListener = Firestore.firestore()
            .collection("users")
            .document(user.id)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("❌ Latest quote listener error:", error)
                    return
                }

                guard
                    let data = snapshot?.data(),
                    let latestQuote = data["latestQuote"] as? [String: Any],
                    let quoteText = latestQuote["quote"] as? String,
                    !quoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    return
                }

                Task { @MainActor in
                    print("🔥 FIREBASE NEW QUOTE:", quoteText)
                    self.applyDeliveredQuoteText(quoteText)
                }
            }
    }

    func bootstrap() async {
        restoreCachedSessionIfPossible()

        await refreshSubscriptionState()

        guard let restoredUser = await services.auth.currentUser() else { return }
        do {
            try await loadSession(for: restoredUser)
        } catch {
            // Launch refresh is best-effort. Keep the cached session visible if the network is unavailable.
        }
    }

    func loadPremiumOffer() async {
        premiumOffer = await services.subscription.loadPremiumOffer()
    }

    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try AppleSignInNonce.random()
            currentAppleNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithApple(result: Result<ASAuthorization, Error>) async {
        if case .failure(let error) = result {
            errorMessage = signInWithAppleMessage(for: error)
            return
        }

        await runTask {
            let signedInUser = try await services.auth.signInWithApple(result: result, rawNonce: currentAppleNonce)
            currentAppleNonce = nil
            try await loadSession(for: signedInUser)
        }
    }

    func usePreviewAccount() async {
        await runTask {
            let previewUser = MotiveUser(id: "preview-user", displayName: "Jacob", email: nil, createdAt: .now)
            user = previewUser
            await refreshSubscriptionState()
            route = profile.isComplete ? .notifications : .onboarding
        }
    }

    func saveProfileAndContinue() async {
        guard let user else { return }
        await runTask {
            profileCache.saveLastUser(user)
            profileCache.save(profile: profile, notificationPreference: notificationPreference, for: user.id)
            try await services.profile.saveProfile(profile, for: user.id)
            try await generateInitialQuoteIfNeeded(for: user)
            try await uploadLatestAPNsTokenIfPossible()
            route = subscriptionState.hasPremiumAccess ? .notifications : .paywall
        }
    }

    func saveSettingsAndReturnHome() async {
        guard let user else { return }

        await runTask {
            let center = UNUserNotificationCenter.current()
            let settings = await notificationSettings(for: center)

            if settings.authorizationStatus == .notDetermined {
                let granted = try await services.notifications.requestAuthorization()

                guard granted else {
                    notificationPreference.isEnabled = false
                    try await persistSettings(for: user)
                    return
                }
            }

            let updatedSettings = await notificationSettings(for: center)

            let notificationsAllowed =
                updatedSettings.authorizationStatus == .authorized ||
                updatedSettings.authorizationStatus == .provisional ||
                updatedSettings.authorizationStatus == .ephemeral

            // Saving a notification time means notifications should be ON.
            notificationPreference.isEnabled = notificationsAllowed
            notificationPreference.timezoneIdentifier = TimeZone.current.identifier

            if notificationPreference.isEnabled {
                await services.notifications.registerForRemoteNotifications()
            }

            try await persistSettings(for: user)
            try await uploadLatestAPNsTokenIfPossible()
            try await syncSavedQuoteNotifications()

            print("🔔 SETTINGS SAVED")
            print("enabled:", notificationPreference.isEnabled)
            print("timing:", notificationPreference.timing)
            print("hour:", notificationPreference.customHour)
            print("minute:", notificationPreference.customMinute)
            print("timezone:", notificationPreference.timezoneIdentifier)

            route = .home
        }
    }

    func cacheCurrentSettingsIfPossible() {
        guard let user else { return }
        profileCache.saveLastUser(user)
        profileCache.save(profile: profile, notificationPreference: notificationPreference, for: user.id)
    }

    func persistCurrentSettingsIfPossible() async {
        guard let user else { return }
        do {
            try await persistSettings(for: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func enableNotificationsAndContinue() async {
        guard let user else { return }
        guard subscriptionState.hasPremiumAccess else {
            notificationPreference.isEnabled = false
            await runTask {
                try await services.profile.saveNotificationPreference(notificationPreference, for: user.id)
                route = .paywall
            }
            return
        }

        await runTask {
            let granted = try await services.notifications.requestAuthorization()
            notificationPreference.isEnabled = granted
            try await services.profile.saveNotificationPreference(notificationPreference, for: user.id)
            if granted {
                await services.notifications.registerForRemoteNotifications()
                try await uploadLatestAPNsTokenIfPossible()
            }
            try await syncSavedQuoteNotifications()
            route = subscriptionState.hasPremiumAccess ? .home : .paywall
        }
    }

    func skipNotifications() async {
        guard let user else { return }
        await runTask {
            notificationPreference.isEnabled = false
            try await services.profile.saveNotificationPreference(notificationPreference, for: user.id)
            try await syncSavedQuoteNotifications()
            route = subscriptionState.hasPremiumAccess ? .home : .paywall
        }
    }

    func purchasePremium() async {
        await runTask {
            subscriptionState = try await services.subscription.purchasePremium()
            if let user {
                try await services.profile.saveSubscriptionState(subscriptionState, for: user.id)
            }
            if subscriptionState.hasPremiumAccess {
                try await loadDeliveredQuote()
                route = notificationPreference.isEnabled ? .home : .notifications
            }
        }
    }

    func restorePurchases() async {
        await runTask {
            subscriptionState = try await services.subscription.restorePurchases()
            if let user {
                try await services.profile.saveSubscriptionState(subscriptionState, for: user.id)
                try await enforcePremiumNotificationAccess(for: user)
            }
            if subscriptionState.hasPremiumAccess {
                try await loadDeliveredQuote()
                route = notificationPreference.isEnabled ? .home : .notifications
            }
        }
    }

    func continueWithoutPremium() async {
        await runTask {
            subscriptionState = .free
            notificationPreference.isEnabled = false
            if let user {
                try await services.profile.saveSubscriptionState(subscriptionState, for: user.id)
                try await services.profile.saveNotificationPreference(notificationPreference, for: user.id)
                try await syncSavedQuoteNotifications()
                try await generateInitialQuoteIfNeeded(for: user)
            }
            try await loadDeliveredQuote()
            if let user {
                try await generateInitialQuoteIfNeeded(for: user)
            }
            route = .home
        }
    }

    var canSendStagingPush: Bool {
        guard user != nil else { return false }

        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    func loadDeliveredQuote() async throws {
        if let deliveredQuote = try await services.motivation.latestDeliveredQuote() {
            currentQuote = deliveredQuote
        }
    }

    func sendStagingTestPush() async {
        await runTask {
            if APNsDeviceTokenCenter.latestToken == nil {
                await services.notifications.registerForRemoteNotifications()
            }
            try await uploadLatestAPNsTokenIfPossible()
            let pushedQuote = try await services.notifications.sendTestPush()
            currentQuote = pushedQuote
        }
    }

    func generatePremiumQuote() async {
        guard subscriptionState.hasPremiumAccess else {
            route = .paywall
            return
        }

        guard let user else { return }

        let usedCount = profileCache.loadDailyNewQuoteCount(for: user.id)
        guard usedCount < dailyNewQuoteLimit else {
            noticeMessage = "You have reached today's 5 new quote limit."
            return
        }

        await runTask {
            if repeatSavedQuoteInMainQuoteIfAvailable(chanceDivisor: 4) {
                return
            }

            let recentQuotes = boundedRecentQuotes(for: user.id)
            let quote = try await services.motivation.generateQuote(for: profile, avoiding: recentQuotes)
            currentQuote = quote
            profileCache.incrementDailyNewQuoteCount(for: user.id)
            rememberRecentQuote(quote.text, for: user.id)
        }
    }

    var isCurrentQuoteSaved: Bool {
        savedQuotes.contains { $0.text == currentQuote.text }
    }

    func saveCurrentQuote() {
        saveQuoteText(currentQuote.text)
    }

    func saveScannedQuote(_ quoteText: String) {
        let didSaveQuote = saveQuoteText(quoteText)
        noticeMessage = didSaveQuote ? "Scanned quote saved." : "That quote is already saved."
    }

    @discardableResult
    private func saveQuoteText(_ quoteText: String) -> Bool {
        guard let user else { return false }
        let cleanQuote = quoteText.trimmed
        guard !cleanQuote.isEmpty else { return false }

        if let existingIndex = savedQuotes.firstIndex(where: { $0.text == cleanQuote }) {
            let existingQuote = savedQuotes.remove(at: existingIndex)
            savedQuotes.insert(existingQuote, at: 0)
            profileCache.save(savedQuotes: savedQuotes, for: user.id)
            rescheduleSavedQuoteNotificationsSoon()
            return false
        }

        savedQuotes.insert(SavedQuote(text: cleanQuote), at: 0)
        profileCache.save(savedQuotes: savedQuotes, for: user.id)
        rescheduleSavedQuoteNotificationsSoon()
        return true
    }

    func toggleCurrentQuoteSaved() {
        guard let user else { return }
        let quoteText = currentQuote.text.trimmed
        guard !quoteText.isEmpty else { return }

        if isCurrentQuoteSaved {
            savedQuotes.removeAll { $0.text == quoteText }
        } else {
            savedQuotes.insert(SavedQuote(text: quoteText), at: 0)
        }

        profileCache.save(savedQuotes: savedQuotes, for: user.id)
        rescheduleSavedQuoteNotificationsSoon()
    }

    func removeSavedQuote(_ quote: SavedQuote) {
        guard let user else { return }
        savedQuotes.removeAll { $0.id == quote.id }
        profileCache.save(savedQuotes: savedQuotes, for: user.id)
        rescheduleSavedQuoteNotificationsSoon()
    }

    func uploadLatestAPNsTokenIfPossible() async throws {
        guard user != nil, let token = APNsDeviceTokenCenter.latestToken else { return }
        try await services.notifications.uploadAPNsDeviceToken(token)
    }

    func deleteAccount() async {
        guard let user else { return }
        await runTask {
            profileCache.clearLastUser()
            profileCache.clear(for: user.id)
            try await services.profile.deleteAccountData(for: user.id)
            await services.auth.signOut()
            resetSession()
        }
    }

    func signOut() async {
        profileCache.clearLastUser()
        if let user {
            profileCache.clear(for: user.id)
        }
        await services.auth.signOut()
        resetSession()
    }

    private func resetSession() {
        user = nil
        profile = UserProfile()
        notificationPreference = NotificationPreference()
        savedQuotes = []
        subscriptionState = .unknown
        route = .signIn
        latestQuoteListener?.remove()
        latestQuoteListener = nil
    }

    private func restoreCachedSessionIfPossible() {
        guard user == nil, let cachedUser = profileCache.loadLastUser() else { return }
        user = cachedUser
        startListeningForLatestQuote(for: cachedUser)

        if let cached = profileCache.load(for: cachedUser.id) {
            profile = cached.profile
            notificationPreference = cached.notificationPreference
        }
        savedQuotes = profileCache.loadSavedQuotes(for: cachedUser.id)
        rescheduleSavedQuoteNotificationsSoon()
        repeatSavedQuoteInMainQuoteIfAvailable(chanceDivisor: 5)

        route = profile.isComplete ? .home : .onboarding
    }

    private func loadSession(for signedInUser: MotiveUser) async throws {
        user = signedInUser
        await refreshSubscriptionState()
        startListeningForLatestQuote(for: signedInUser)
        profileCache.saveLastUser(signedInUser)
        let cached = profileCache.load(for: signedInUser.id)
        if let cached {
            profile = cached.profile
            notificationPreference = cached.notificationPreference
        }
        savedQuotes = profileCache.loadSavedQuotes(for: signedInUser.id)
        if let savedPreference = try await services.profile.loadNotificationPreference(for: signedInUser.id) {
            notificationPreference = savedPreference
        }
        try await enforcePremiumNotificationAccess(for: signedInUser)
        try await syncSavedQuoteNotifications()
        repeatSavedQuoteInMainQuoteIfAvailable(chanceDivisor: 5)
        if let savedProfile = try await services.profile.loadProfile(for: signedInUser.id) {
            profile = mergedProfile(serverProfile: savedProfile, cachedProfile: cached?.profile)
            profileCache.save(profile: profile, notificationPreference: notificationPreference, for: signedInUser.id)
            try await loadDeliveredQuote()
            try await generateInitialQuoteIfNeeded(for: signedInUser)
            try await uploadLatestAPNsTokenIfPossible()
            route = .home
        } else {
            try await uploadLatestAPNsTokenIfPossible()
            route = .onboarding
        }
    }

    private func refreshSubscriptionState() async {
        async let state = services.subscription.loadSubscriptionState()
        async let offer = services.subscription.loadPremiumOffer()
        subscriptionState = await state
        premiumOffer = await offer
        try? await syncSubscriptionAccessIfPossible()
    }

    private func persistSettings(for user: MotiveUser) async throws {
        notificationPreference.timezoneIdentifier = TimeZone.current.identifier
        if !subscriptionState.hasPremiumAccess {
            notificationPreference.isEnabled = false
        }
        profileCache.saveLastUser(user)
        profileCache.save(profile: profile, notificationPreference: notificationPreference, for: user.id)
        try await services.profile.saveSubscriptionState(subscriptionState, for: user.id)
        try await services.profile.saveProfile(profile, for: user.id)
        try await services.profile.saveNotificationPreference(notificationPreference, for: user.id)
    }

    private func syncSubscriptionAccessIfPossible() async throws {
        guard let user else { return }
        try await services.profile.saveSubscriptionState(subscriptionState, for: user.id)
        try await enforcePremiumNotificationAccess(for: user)
    }

    private func enforcePremiumNotificationAccess(for user: MotiveUser) async throws {
        try await services.profile.saveSubscriptionState(subscriptionState, for: user.id)
        guard !subscriptionState.hasPremiumAccess, notificationPreference.isEnabled else { return }
        notificationPreference.isEnabled = false
        profileCache.save(profile: profile, notificationPreference: notificationPreference, for: user.id)
        try await services.profile.saveNotificationPreference(notificationPreference, for: user.id)
        try await syncSavedQuoteNotifications()
    }

    private func mergedProfile(serverProfile: UserProfile, cachedProfile: UserProfile?) -> UserProfile {
        var merged = serverProfile
        if merged.preferredName.trimmed.isEmpty,
           let cachedName = cachedProfile?.preferredName.trimmed,
           !cachedName.isEmpty {
            merged.preferredName = cachedName
        }
        return merged
    }

    private func boundedRecentQuotes(for userID: String) -> [String] {
        profileCache.loadRecentGeneratedQuotes(for: userID)
            .map { String($0.trimmed.prefix(recentQuoteCharacterLimit)) }
            .filter { !$0.isEmpty }
            .prefix(recentQuoteMemoryLimit)
            .map { String($0) }
    }

    private func rememberRecentQuote(_ quote: String, for userID: String) {
        let cleanedQuote = String(quote.trimmed.prefix(recentQuoteCharacterLimit))
        guard !cleanedQuote.isEmpty else { return }

        var recentQuotes = profileCache.loadRecentGeneratedQuotes(for: userID)
            .filter { $0 != cleanedQuote }
        recentQuotes.insert(cleanedQuote, at: 0)
        profileCache.saveRecentGeneratedQuotes(Array(recentQuotes.prefix(recentQuoteMemoryLimit)), for: userID)
    }

    @discardableResult
    private func repeatSavedQuoteInMainQuoteIfAvailable(chanceDivisor: Int) -> Bool {
        guard !savedQuotes.isEmpty, Int.random(in: 0..<max(chanceDivisor, 1)) == 0 else { return false }
        let quote = savedQuotes.randomElement() ?? savedQuotes[0]
        currentQuote = MotivationQuote(text: quote.text)
        return true
    }

    private func rescheduleSavedQuoteNotificationsSoon() {
        Task { @MainActor in
            try? await syncSavedQuoteNotifications()
        }
    }

    private func syncSavedQuoteNotifications() async throws {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await pendingNotificationRequests(for: center)
        let existingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(savedQuoteNotificationPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)

        guard subscriptionState.hasPremiumAccess,
              notificationPreference.isEnabled,
              !savedQuotes.isEmpty else {
            return
        }

        let settings = await notificationSettings(for: center)
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral else {
            return
        }

        let quotesToSchedule = Array(savedQuotes.prefix(4))
        for (index, quote) in quotesToSchedule.enumerated() {
            guard let trigger = savedQuoteNotificationTrigger(offset: index + 1) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Saved quote"
            content.body = quote.text
            content.sound = .default
            content.userInfo = ["type": "motivation", "source": "savedQuote"]

            let request = UNNotificationRequest(
                identifier: "\(savedQuoteNotificationPrefix).\(quote.id.uuidString).\(index)",
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }

    private func savedQuoteNotificationTrigger(offset: Int) -> UNCalendarNotificationTrigger? {
        let calendar = Calendar.current
        let daysAhead = offset * 3
        guard let date = calendar.date(byAdding: .day, value: daysAhead, to: Date()) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let time = notificationTimeComponents(for: offset)
        components.hour = time.hour
        components.minute = time.minute
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private func notificationTimeComponents(for offset: Int) -> (hour: Int, minute: Int) {
        switch notificationPreference.timing {
        case .morning:
            return (8, 0)
        case .afternoon:
            return (13, 0)
        case .evening:
            return (19, 0)
        case .custom:
            return (notificationPreference.customHour, notificationPreference.customMinute)
        case .random:
            let hour = [8, 12, 17, 20][offset % 4]
            return (hour, 0)
        }
    }

    private func pendingNotificationRequests(for center: UNUserNotificationCenter) async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func notificationSettings(for center: UNUserNotificationCenter) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func generateInitialQuoteIfNeeded(for user: MotiveUser) async throws {
        guard shouldGenerateInitialQuote else { return }
        let recentQuotes = boundedRecentQuotes(for: user.id)
        let quote = try await services.motivation.generateQuote(for: profile, avoiding: recentQuotes)
        currentQuote = quote
        rememberRecentQuote(quote.text, for: user.id)
    }

    private var shouldGenerateInitialQuote: Bool {
        let quoteText = currentQuote.text.trimmed
        return quoteText.isEmpty
            || quoteText == Self.defaultQuoteText
            || quoteText == "Your next quote will appear here after a notification."
    }

    private func observeAPNsRegistration() {
        let tokenObserver = NotificationCenter.default.addObserver(
            forName: APNsDeviceTokenCenter.didRegisterToken,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let token = notification.userInfo?["token"] as? String else { return }
            Task { @MainActor in
                guard self.user != nil else { return }
                try? await self.services.notifications.uploadAPNsDeviceToken(token)
            }
        }

        let failureObserver = NotificationCenter.default.addObserver(
            forName: APNsDeviceTokenCenter.didFailToRegister,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let error = notification.userInfo?["error"] as? Error else { return }
            Task { @MainActor in
                self.errorMessage = error.localizedDescription
            }
        }

        let quoteObserver = NotificationCenter.default.addObserver(
            forName: APNsDeviceTokenCenter.didReceiveMotivationQuote,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let quote = notification.userInfo?["quote"] as? String else {
                return
            }

            Task { @MainActor in
                self.applyDeliveredQuoteText(quote)
            }
        }

        notificationObservers = [tokenObserver, failureObserver, quoteObserver]
    }

    private func applyDeliveredQuoteText(_ quoteText: String) {
        let quote = quoteText.trimmed
        guard !quote.isEmpty, currentQuote.text != quote else { return }
        currentQuote = MotivationQuote(text: quote)
        if let user {
            rememberRecentQuote(quote, for: user.id)
        }
    }

    private func runTask(_ operation: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signInWithAppleMessage(for error: Error) -> String {
        guard let authorizationError = error as? ASAuthorizationError else {
            return error.localizedDescription
        }

        switch authorizationError.code {
        case .canceled:
            return "Sign in was canceled."
        case .unknown:
            return "Apple sign-in is not ready for this app. Check Sign in with Apple capability, bundle ID, Firebase Apple provider, and device Apple ID settings."
        case .failed:
            return "Apple sign-in failed. Check your Apple ID and try again."
        case .invalidResponse:
            return "Apple returned an invalid sign-in response. Try again."
        case .notHandled:
            return "Apple sign-in was not handled by the system. Try again."
        case .notInteractive:
            return "Apple sign-in needs an interactive session. Try again from the app screen."
        case .matchedExcludedCredential:
            return "This Apple credential cannot be used for this sign-in flow."
        case .credentialImport, .credentialExport:
            return "This Apple credential operation is not supported in this sign-in flow."
        default:
            return error.localizedDescription
        }
    }
}

private struct UserDefaultsProfileCache {
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load(for userID: String) -> CachedUserSettings? {
        guard let data = defaults.data(forKey: key(for: userID)),
              var cached = try? decoder.decode(CachedUserSettings.self, from: data) else {
            return nil
        }

        let storedName = defaults.string(forKey: nameKey(for: userID))?.trimmed ?? ""
        if !storedName.isEmpty {
            cached.profile.preferredName = storedName
        }
        return cached
    }

    func save(profile: UserProfile, notificationPreference: NotificationPreference, for userID: String) {
        let cached = CachedUserSettings(profile: profile, notificationPreference: notificationPreference)
        guard let data = try? encoder.encode(cached) else { return }
        defaults.set(data, forKey: key(for: userID))
        defaults.set(profile.preferredName, forKey: nameKey(for: userID))
    }

    func loadLastUser() -> MotiveUser? {
        guard let data = defaults.data(forKey: lastUserKey) else { return nil }
        return try? decoder.decode(MotiveUser.self, from: data)
    }

    func saveLastUser(_ user: MotiveUser) {
        guard let data = try? encoder.encode(user) else { return }
        defaults.set(data, forKey: lastUserKey)
    }

    func clearLastUser() {
        defaults.removeObject(forKey: lastUserKey)
    }

    func loadSavedQuotes(for userID: String) -> [SavedQuote] {
        guard let data = defaults.data(forKey: savedQuotesKey(for: userID)),
              let quotes = try? decoder.decode([SavedQuote].self, from: data) else {
            return []
        }
        return quotes.sorted { $0.savedAt > $1.savedAt }
    }

    func save(savedQuotes: [SavedQuote], for userID: String) {
        guard let data = try? encoder.encode(savedQuotes) else { return }
        defaults.set(data, forKey: savedQuotesKey(for: userID))
    }

    func loadRecentGeneratedQuotes(for userID: String) -> [String] {
        defaults.stringArray(forKey: recentGeneratedQuotesKey(for: userID)) ?? []
    }

    func saveRecentGeneratedQuotes(_ quotes: [String], for userID: String) {
        defaults.set(quotes, forKey: recentGeneratedQuotesKey(for: userID))
    }

    func loadDailyNewQuoteCount(for userID: String) -> Int {
        defaults.integer(forKey: dailyNewQuoteCountKey(for: userID))
    }

    func incrementDailyNewQuoteCount(for userID: String) {
        let key = dailyNewQuoteCountKey(for: userID)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    func clear(for userID: String) {
        defaults.removeObject(forKey: key(for: userID))
        defaults.removeObject(forKey: nameKey(for: userID))
        defaults.removeObject(forKey: savedQuotesKey(for: userID))
        defaults.removeObject(forKey: recentGeneratedQuotesKey(for: userID))
    }

    private var lastUserKey: String {
        "motive.lastSignedInUser"
    }

    private func key(for userID: String) -> String {
        "motive.cachedUserSettings.\(userID)"
    }

    private func nameKey(for userID: String) -> String {
        "motive.preferredName.\(userID)"
    }

    private func savedQuotesKey(for userID: String) -> String {
        "motive.savedQuotes.\(userID)"
    }

    private func recentGeneratedQuotesKey(for userID: String) -> String {
        "motive.recentGeneratedQuotes.\(userID)"
    }

    private func dailyNewQuoteCountKey(for userID: String) -> String {
        "motive.dailyNewQuoteCount.\(userID).\(dayStamp)"
    }

    private var dayStamp: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private struct CachedUserSettings: Codable {
    var profile: UserProfile
    var notificationPreference: NotificationPreference
}
