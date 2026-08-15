import Combine
import CryptoKit
import Foundation
import Model
import UIKit
import UserNotifications

@MainActor
public protocol ScheduleNotificationScheduling: AnyObject {
    func synchronizeReminder(for schedule: Schedule) async throws
    func removeReminder(scheduleId: UUID) async
}

@MainActor
public final class UserNotificationScheduler: ScheduleNotificationScheduling {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func synchronizeReminder(for schedule: Schedule) async throws {
        let identifier = Self.identifier(for: schedule.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let reminder = schedule.reminderSetting, reminder.isEnabled else {
            return
        }
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { return }
        let fireDate = schedule.startDateTime.addingTimeInterval(
            TimeInterval(-reminder.notifyBeforeMinutes * 60)
        )
        guard fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = schedule.title
        content.body = schedule.location
        content.sound = .default
        content.userInfo = ["scheduleId": schedule.id.uuidString]
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        try await center.add(
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
        )
    }

    public func removeReminder(scheduleId: UUID) async {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.identifier(for: scheduleId)]
        )
    }

    private static func identifier(for id: UUID) -> String {
        "schedule-reminder-\(id.uuidString)"
    }
}

public struct FcmToken: Identifiable, Equatable, Codable, Sendable {
    public enum OperatingSystem: String, Codable, Sendable {
        case iOS
        case android = "Android"
    }

    public enum Environment: String, Codable, Sendable {
        case development
        case production
    }

    public var id: String
    public var userId: String
    public var token: String
    public var appVariant: String
    public var os: OperatingSystem
    public var environment: Environment
    public var updatedAt: Date

    public init(
        id: String,
        userId: String,
        token: String,
        appVariant: String = "next",
        os: OperatingSystem,
        environment: Environment,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.token = token
        self.appVariant = appVariant
        self.os = os
        self.environment = environment
        self.updatedAt = updatedAt
    }

    public static func id(for token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public enum NotificationType: String, Codable, Sendable, CaseIterable {
    case announcement
    case adminReply = "admin_reply"
    case videoQuestionAnswer = "video_question_answer"
    case event
    case supportMessage = "support_message"

    fileprivate var host: String {
        switch self {
        case .announcement: "announcements"
        case .adminReply: "posts"
        case .videoQuestionAnswer: "video-questions"
        case .event: "events"
        case .supportMessage: "support"
        }
    }

    fileprivate var targetKey: String {
        switch self {
        case .announcement: "announcementId"
        case .adminReply: "postId"
        case .videoQuestionAnswer: "questionId"
        case .event: "eventId"
        case .supportMessage: "supportMessageId"
        }
    }
}

public struct NotificationRoute: Equatable, Codable, Sendable {
    public let type: NotificationType
    public let targetId: String
    public let communityId: String?

    public init(type: NotificationType, targetId: String, communityId: String? = nil) {
        self.type = type
        self.targetId = targetId
        self.communityId = communityId
    }
}

public struct NotificationNavigationDecision: Equatable, Sendable {
    public let route: NotificationRoute
    public let communityIdToSelect: String?

    public static func resolve(
        route: NotificationRoute,
        selectedCommunityId: String?
    ) -> Self {
        Self(
            route: route,
            communityIdToSelect: route.communityId == selectedCommunityId
                ? nil
                : route.communityId
        )
    }
}

public enum NotificationRouteParser {
    public static let typeKey = "notificationType"
    public static let deepLinkKey = "deepLink"
    public static let communityIdKey = "communityId"

    public static func url(for route: NotificationRoute) -> URL {
        var components = URLComponents()
        components.scheme = "orgportalnext"
        components.host = route.type.host
        let encodedTarget = route.targetId.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? route.targetId
        components.percentEncodedPath = route.type == .supportMessage
            ? "/messages/\(encodedTarget)"
            : "/\(encodedTarget)"
        if let communityId = route.communityId {
            components.queryItems = [URLQueryItem(name: communityIdKey, value: communityId)]
        }
        return components.url!
    }

    public static func route(userInfo: [AnyHashable: Any]) -> NotificationRoute? {
        if let value = userInfo[deepLinkKey] as? String,
           let url = URL(string: value),
           let route = route(url: url) {
            return route
        }
        guard let rawType = userInfo[typeKey] as? String,
              let type = NotificationType(rawValue: rawType) else { return nil }
        let targetId = (userInfo[type.targetKey] as? String)
            ?? (userInfo["targetId"] as? String)
            ?? (type == .supportMessage ? userInfo["messageId"] as? String : nil)
        guard let targetId, !targetId.isEmpty else { return nil }
        return NotificationRoute(
            type: type,
            targetId: targetId,
            communityId: (userInfo[communityIdKey] as? String)?.nilIfEmpty
        )
    }

    public static func route(url: URL) -> NotificationRoute? {
        guard url.scheme == "orgportalnext",
              let type = NotificationType.allCases.first(where: { $0.host == url.host }) else {
            return nil
        }
        let segments = url.pathComponents.filter { $0 != "/" }
        let targetId: String?
        if type == .supportMessage {
            targetId = segments.count == 2 && segments[0] == "messages" ? segments[1] : nil
        } else {
            targetId = segments.count == 1 ? segments[0] : nil
        }
        guard let targetId, !targetId.isEmpty else { return nil }
        let communityId = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == communityIdKey })?.value?.nilIfEmpty
        return NotificationRoute(type: type, targetId: targetId, communityId: communityId)
    }
}

@MainActor
public final class NotificationRouter: NSObject, ObservableObject,
    UNUserNotificationCenterDelegate {
    public nonisolated static let messageIdKey = "supportMessageId"
    public nonisolated static let typeKey = NotificationRouteParser.typeKey
    public nonisolated static let supportType = NotificationType.supportMessage.rawValue
    @Published public private(set) var route: NotificationRoute?
    @Published public private(set) var routeSequence = 0
    private let center: UNUserNotificationCenter

    public var messageId: String? {
        route?.type == .supportMessage ? route?.targetId : nil
    }

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
        Task {
            let granted = (try? await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )) ?? false
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    public func open(url: URL) {
        publish(NotificationRouteParser.route(url: url))
    }

    public nonisolated static func messageId(userInfo: [AnyHashable: Any]) -> String? {
        if let value = userInfo[messageIdKey] as? String, !value.isEmpty {
            return value
        }
        return NotificationRouteParser.route(userInfo: userInfo)
            .flatMap { $0.type == .supportMessage ? $0.targetId : nil }
    }

    public nonisolated static func messageId(url: URL) -> String? {
        NotificationRouteParser.route(url: url)
            .flatMap { $0.type == .supportMessage ? $0.targetId : nil }
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let route = NotificationRouteParser.route(
            userInfo: response.notification.request.content.userInfo
        )
        await MainActor.run { self.publish(route) }
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    private func publish(_ route: NotificationRoute?) {
        guard let route else { return }
        self.route = route
        routeSequence += 1
    }
}

public typealias SupportNotificationRouter = NotificationRouter

public enum SupportNotificationContent {
    public static func make(messageId: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "サポート"
        content.body = "サポートから新しいメッセージがあります"
        content.sound = .default
        content.userInfo = [
            NotificationRouter.messageIdKey: messageId,
            NotificationRouter.typeKey: NotificationRouter.supportType
        ]
        return content
    }
}

public protocol FcmTokenStoring: Sendable {
    func save(_ token: FcmToken, idToken: String) async throws
    func delete(userId: String, tokenId: String, idToken: String) async throws
}

public protocol FcmRegistrationTokenProviding: Sendable {
    func currentToken() async throws -> String
}

public actor FcmTokenRegistrationManager {
    private struct Registration: Sendable {
        let userId: String
        let idToken: String
        let tokenId: String
    }

    private let store: any FcmTokenStoring
    private let tokenProvider: any FcmRegistrationTokenProviding
    private let environment: FcmToken.Environment
    private let now: @Sendable () -> Date
    private var registration: Registration?

    public init(
        store: any FcmTokenStoring,
        tokenProvider: any FcmRegistrationTokenProviding,
        environment: FcmToken.Environment,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.tokenProvider = tokenProvider
        self.environment = environment
        self.now = now
    }

    public func synchronize(userId: String?, idToken: String?) async throws {
        guard let userId, !userId.isEmpty,
              let idToken, !idToken.isEmpty else {
            if let registration {
                try await store.delete(
                    userId: registration.userId,
                    tokenId: registration.tokenId,
                    idToken: registration.idToken
                )
            }
            registration = nil
            return
        }
        if let previous = registration, previous.userId != userId {
            try await store.delete(
                userId: previous.userId,
                tokenId: previous.tokenId,
                idToken: previous.idToken
            )
            registration = nil
        }
        let token = try await tokenProvider.currentToken()
        try await register(userId: userId, idToken: idToken, rawToken: token)
    }

    public func tokenRefreshed(_ token: String) async throws {
        guard let previous = registration else { return }
        try await register(userId: previous.userId, idToken: previous.idToken, rawToken: token)
        let newId = FcmToken.id(for: token)
        if previous.tokenId != newId {
            try await store.delete(
                userId: previous.userId,
                tokenId: previous.tokenId,
                idToken: previous.idToken
            )
        }
    }

    private func register(userId: String, idToken: String, rawToken: String) async throws {
        guard !rawToken.isEmpty else { return }
        let token = FcmToken(
            id: FcmToken.id(for: rawToken),
            userId: userId,
            token: rawToken,
            os: .iOS,
            environment: environment,
            updatedAt: now()
        )
        try await store.save(token, idToken: idToken)
        registration = Registration(userId: userId, idToken: idToken, tokenId: token.id)
    }
}

public struct FirestoreFcmTokenStore: FcmTokenStoring {
    private let projectId: String
    private let session: URLSession

    public init(projectId: String, session: URLSession = .shared) {
        self.projectId = projectId
        self.session = session
    }

    public func save(_ token: FcmToken, idToken: String) async throws {
        let fields: [String: Any] = [
            "id": stringValue(token.id),
            "userId": stringValue(token.userId),
            "token": stringValue(token.token),
            "appVariant": stringValue(token.appVariant),
            "os": stringValue(token.os.rawValue),
            "environment": stringValue(token.environment.rawValue),
            "updatedAt": ["timestampValue": ISO8601DateFormatter().string(from: token.updatedAt)]
        ]
        try await request(
            userId: token.userId,
            tokenId: token.id,
            method: "PATCH",
            idToken: idToken,
            body: ["fields": fields]
        )
    }

    public func delete(userId: String, tokenId: String, idToken: String) async throws {
        try await request(
            userId: userId,
            tokenId: tokenId,
            method: "DELETE",
            idToken: idToken,
            body: nil
        )
    }

    private func request(
        userId: String,
        tokenId: String,
        method: String,
        idToken: String,
        body: [String: Any]?
    ) async throws {
        let escapedUser = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        let escapedToken = tokenId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tokenId
        let value = "https://firestore.googleapis.com/v1/projects/\(projectId)"
            + "/databases/(default)/documents/memberPrivate/\(escapedUser)/fcmTokens/\(escapedToken)"
        var request = URLRequest(url: URL(string: value)!)
        request.httpMethod = method
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) || (method == "DELETE" && status == 404) else {
            throw URLError(.badServerResponse)
        }
    }

    private func stringValue(_ value: String) -> [String: String] {
        ["stringValue": value]
    }
}

public extension Notification.Name {
    static let fcmTokenRefreshed = Notification.Name("OrgPortalNext.fcmTokenRefreshed")
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
