import Foundation
import Model

public enum FirebaseEnvironment: String, Sendable {
    case emulator
    case development
    case production
}

public protocol AnnouncementRepository: Sendable {
    func announcements(
        communityId: String?,
        membership: CommunityMembership?,
        userId: String?,
        idToken: String?
    ) async throws -> [Announcement]

    func readAnnouncementIDs(userId: String, idToken: String) async throws -> Set<String>

    func markRead(
        userId: String,
        announcementId: String,
        idToken: String
    ) async throws
}

public struct FirebaseRESTAnnouncementRepository: AnnouncementRepository {
    private let projectId: String
    private let session: URLSession

    public init(projectId: String, session: URLSession = .shared) {
        self.projectId = projectId
        self.session = session
    }

    public func announcements(
        communityId: String?,
        membership: CommunityMembership?,
        userId: String?,
        idToken: String?
    ) async throws -> [Announcement] {
        let approved = membership?.status == .approved
        let documents: [(String, [String: Any])]
        if let communityId, approved, let idToken {
            let canonical = try await listDocuments(
                communityId: communityId,
                collection: "announcements",
                idToken: idToken
            )
            let legacy = try await listDocuments(
                communityId: communityId,
                collection: "messages",
                idToken: idToken
            )
            documents = canonical + legacy
        } else {
            let canonical = try await publicDocuments(
                collection: "announcements",
                field: "publishScope",
                value: "public"
            )
            let publicLegacy = try await publicDocuments(
                collection: "messages",
                field: "messageType",
                value: "publicAnnouncement"
            )
            let visibleLegacy = try await publicDocuments(
                collection: "messages",
                field: "visibility",
                value: "public"
            )
            documents = canonical + publicLegacy + visibleLegacy
        }
        var seen = Set<String>()
        return documents
            .compactMap(parseAnnouncement)
            .filter { seen.insert($0.id).inserted }
            .filter {
                $0.isVisible(
                    userId: userId,
                    categoryIds: membership?.categoryIds ?? [],
                    isApprovedMember: approved
                )
            }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    public func readAnnouncementIDs(
        userId: String,
        idToken: String
    ) async throws -> Set<String> {
        let response = try await requestJSON(
            path: "documents/memberPrivate/\(userId)"
                + "/announcementReadStates?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return Set(documents.compactMap { document in
            guard let fields = document["fields"] as? [String: Any] else { return nil }
            return string(fields, "announcementId")
        })
    }

    public func markRead(
        userId: String,
        announcementId: String,
        idToken: String
    ) async throws {
        let documentID = announcementId
            .replacingOccurrences(
                of: "[^A-Za-z0-9_-]",
                with: "_",
                options: .regularExpression
            )
        let fields: [String: Any] = [
            "userId": stringValue(userId),
            "announcementId": stringValue(announcementId),
            "readAt": timestampValue(ISO8601DateFormatter().string(from: Date()))
        ]
        _ = try await requestJSON(
            path: "documents/memberPrivate/\(userId)"
                + "/announcementReadStates/\(documentID)",
            method: "PATCH",
            idToken: idToken,
            body: ["fields": fields]
        )
    }

    private func listDocuments(
        communityId: String,
        collection: String,
        idToken: String
    ) async throws -> [(String, [String: Any])] {
        let result = try await requestJSON(
            path: "documents/organizations/\(communityId)/\(collection)?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        return (result?["documents"] as? [[String: Any]] ?? []).map {
            (collection, $0)
        }
    }

    private func publicDocuments(
        collection: String,
        field: String,
        value: String
    ) async throws -> [(String, [String: Any])] {
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [[
                    "collectionId": collection,
                    "allDescendants": true
                ]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": field],
                        "op": "EQUAL",
                        "value": stringValue(value)
                    ]
                ]
            ]
        ]
        let rows = try await requestJSON(
            path: "documents:runQuery",
            method: "POST",
            idToken: nil,
            body: body
        ) as? [[String: Any]] ?? []
        return rows.compactMap {
            guard let document = $0["document"] as? [String: Any] else { return nil }
            return (collection, document)
        }
    }

    private func parseAnnouncement(
        _ sourceDocument: (String, [String: Any])
    ) -> Announcement? {
        let (source, document) = sourceDocument
        guard let fields = document["fields"] as? [String: Any],
              let name = document["name"] as? String else { return nil }
        let path = name.split(separator: "/").map(String.init)
        guard let organizationsIndex = path.lastIndex(of: "organizations"),
              organizationsIndex + 1 < path.count,
              let rawID = path.last else { return nil }
        let communityId = path[organizationsIndex + 1]
        let scope: AnnouncementPublishScope
        if source == "announcements" {
            switch string(fields, "publishScope") {
            case "public": scope = .public
            case "category": scope = .category
            case "individual": scope = .individual
            default: scope = .memberAll
            }
        } else if string(fields, "messageType") == "publicAnnouncement"
                    || string(fields, "visibility") == "public"
                    || string(fields, "deliveryType") == "公開お知らせ" {
            scope = .public
        } else if !(
            stringArray(fields, "targetMemberUids")
                + stringArray(fields, "toUids")
        ).isEmpty {
            scope = .individual
        } else if !stringArray(fields, "categoryTargets").isEmpty {
            scope = .category
        } else {
            scope = .memberAll
        }
        guard let title = string(fields, "title") else { return nil }
        return Announcement(
            id: "\(communityId):\(source):\(rawID)",
            communityId: communityId,
            title: title,
            body: string(fields, "body") ?? "",
            publishScope: scope,
            targetCategoryIds: Set(
                stringArray(fields, "targetCategoryIds")
                    + stringArray(fields, "categoryTargets")
                    + [string(fields, "targetCategoryId")].compactMap { $0 }
            ),
            targetUserIds: Set(
                stringArray(fields, "targetUserIds")
                    + stringArray(fields, "targetMemberUids")
                    + stringArray(fields, "toUids")
            ),
            attachments: attachments(fields),
            zoomURL: URL(
                string: string(fields, "zoomUrl")
                    ?? string(fields, "zoomURL")
                    ?? ""
            ),
            videoURL: URL(
                string: string(fields, "videoUrl")
                    ?? string(fields, "videoURL")
                    ?? ""
            ),
            createdAt: timestamp(fields, "createdAt")
        )
    }

    private func attachments(_ fields: [String: Any]) -> [AnnouncementAttachment] {
        guard let value = fields["attachments"] as? [String: Any],
              let array = value["arrayValue"] as? [String: Any],
              let values = array["values"] as? [[String: Any]] else { return [] }
        return values.compactMap { value in
            guard let map = value["mapValue"] as? [String: Any],
                  let attachmentFields = map["fields"] as? [String: Any],
                  let rawURL = string(attachmentFields, "url"),
                  let url = URL(string: rawURL) else { return nil }
            return AnnouncementAttachment(
                type: string(attachmentFields, "type") ?? "url",
                name: string(attachmentFields, "name") ?? "添付ファイル",
                url: url
            )
        }
    }

    private func requestJSON(
        path: String,
        method: String,
        idToken: String?,
        body: [String: Any]? = nil
    ) async throws -> Any {
        guard let url = URL(
            string: "https://firestore.googleapis.com/v1/projects/\(projectId)"
                + "/databases/(default)/\(path)"
        ) else { throw CommunityRepositoryError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        idToken.map { request.setValue("Bearer \($0)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw CommunityRepositoryError.requestFailed
        }
        guard (200...299).contains(response.statusCode) else {
            throw CommunityRepositoryError.requestFailed
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func stringValue(_ value: String) -> [String: Any] {
        ["stringValue": value]
    }

    private func timestampValue(_ value: String) -> [String: Any] {
        ["timestampValue": value]
    }

    private func string(_ fields: [String: Any], _ key: String) -> String? {
        (fields[key] as? [String: Any])?["stringValue"] as? String
    }

    private func stringArray(_ fields: [String: Any], _ key: String) -> [String] {
        guard let value = fields[key] as? [String: Any],
              let array = value["arrayValue"] as? [String: Any],
              let values = array["values"] as? [[String: Any]] else { return [] }
        return values.compactMap { $0["stringValue"] as? String }
    }

    private func timestamp(_ fields: [String: Any], _ key: String) -> Date? {
        guard let value = (fields[key] as? [String: Any])?["timestampValue"]
            as? String else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}

public struct FirebaseRuntimeConfiguration: Sendable {
    public let environment: FirebaseEnvironment
    public let projectId: String
    public let isDebugBuild: Bool
    public let productionProjectId: String

    public init(
        environment: FirebaseEnvironment,
        projectId: String,
        isDebugBuild: Bool,
        productionProjectId: String
    ) {
        self.environment = environment
        self.projectId = projectId
        self.isDebugBuild = isDebugBuild
        self.productionProjectId = productionProjectId
    }

    public func validate() throws {
        if isDebugBuild,
           environment == .production || projectId == productionProjectId {
            throw FirebaseEnvironmentError.debugBuildReferencesProduction
        }
    }
}

public enum FirebaseEnvironmentError: Error, Equatable {
    case debugBuildReferencesProduction
}

public enum LegacyAdapterNamespace {
    // Legacy Adapter implementations are added here per feature.
}

public struct AuthenticatedAccount: Equatable, Sendable {
    public let userId: String
    public let email: String
    public let emailVerified: Bool
    public let idToken: String
    public let refreshToken: String

    public init(
        userId: String,
        email: String,
        emailVerified: Bool,
        idToken: String,
        refreshToken: String
    ) {
        self.userId = userId
        self.email = email
        self.emailVerified = emailVerified
        self.idToken = idToken
        self.refreshToken = refreshToken
    }
}

public protocol AccountAuthRepository: Sendable {
    func register(credentials: AccountCredentials) async throws -> AuthenticatedAccount
    func login(credentials: AccountCredentials) async throws -> AuthenticatedAccount
    func refresh(refreshToken: String) async throws -> AuthenticatedAccount
    func sendPasswordReset(email: String) async throws
}

public struct DevelopmentFirebaseNotConfiguredError: LocalizedError, Sendable {
    public init() {}

    public var errorDescription: String? {
        "開発用Firebase認証が未設定です。本番Firebaseには接続していません。"
    }
}

/// 開発用Firebase設定が安全に用意されるまで使用する明示的な未接続実装。
public struct UnavailableAccountAuthRepository: AccountAuthRepository {
    public init() {}

    public func register(credentials: AccountCredentials) async throws -> AuthenticatedAccount {
        throw DevelopmentFirebaseNotConfiguredError()
    }

    public func login(credentials: AccountCredentials) async throws -> AuthenticatedAccount {
        throw DevelopmentFirebaseNotConfiguredError()
    }

    public func refresh(refreshToken: String) async throws -> AuthenticatedAccount {
        throw DevelopmentFirebaseNotConfiguredError()
    }

    public func sendPasswordReset(email: String) async throws {
        throw DevelopmentFirebaseNotConfiguredError()
    }
}

public struct FirebaseRESTAccountAuthRepository: AccountAuthRepository {
    private let apiKey: String
    private let projectId: String
    private let session: URLSession

    public init(
        apiKey: String,
        projectId: String,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.session = session
    }

    public func register(credentials: AccountCredentials) async throws -> AuthenticatedAccount {
        let response = try await request(
            endpoint: "accounts:signUp",
            body: [
                "email": credentials.email.trimmingCharacters(in: .whitespacesAndNewlines),
                "password": credentials.password,
                "returnSecureToken": true
            ]
        )
        guard
            let userId = response["localId"] as? String,
            let email = response["email"] as? String,
            let idToken = response["idToken"] as? String,
            let refreshToken = response["refreshToken"] as? String
        else {
            throw FirebaseRESTAuthError.invalidResponse
        }
        let name = credentials.name?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let furigana = credentials.furigana?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        try await updateDisplayName(idToken: idToken, name: name)
        try await saveMemberProfile(
            idToken: idToken,
            userId: userId,
            email: email,
            name: name,
            furigana: furigana
        )
        try await sendEmailVerification(idToken: idToken)
        return AuthenticatedAccount(
            userId: userId,
            email: email,
            emailVerified: false,
            idToken: idToken,
            refreshToken: refreshToken
        )
    }

    public func login(credentials: AccountCredentials) async throws -> AuthenticatedAccount {
        let response = try await request(
            endpoint: "accounts:signInWithPassword",
            body: [
                "email": credentials.email.trimmingCharacters(in: .whitespacesAndNewlines),
                "password": credentials.password,
                "returnSecureToken": true
            ]
        )
        guard
            let idToken = response["idToken"] as? String,
            let refreshToken = response["refreshToken"] as? String
        else {
            throw FirebaseRESTAuthError.invalidResponse
        }
        let account = try await lookup(idToken: idToken, refreshToken: refreshToken)
        guard account.emailVerified else {
            try await sendEmailVerification(idToken: idToken)
            throw FirebaseRESTAuthError.emailNotVerified
        }
        return account
    }

    public func refresh(refreshToken: String) async throws -> AuthenticatedAccount {
        guard var components = URLComponents(
            string: "https://securetoken.googleapis.com/v1/token"
        ) else {
            throw FirebaseRESTAuthError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            throw FirebaseRESTAuthError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode),
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let idToken = json["id_token"] as? String,
            let newRefreshToken = json["refresh_token"] as? String
        else {
            throw FirebaseRESTAuthError.biometricCredentialExpired
        }
        return try await lookup(
            idToken: idToken,
            refreshToken: newRefreshToken
        )
    }

    public func sendPasswordReset(email: String) async throws {
        _ = try await request(
            endpoint: "accounts:sendOobCode",
            body: [
                "requestType": "PASSWORD_RESET",
                "email": email.trimmingCharacters(in: .whitespacesAndNewlines)
            ]
        )
    }

    private func lookup(
        idToken: String,
        refreshToken: String
    ) async throws -> AuthenticatedAccount {
        let response = try await request(
            endpoint: "accounts:lookup",
            body: ["idToken": idToken]
        )
        guard
            let users = response["users"] as? [[String: Any]],
            let user = users.first,
            let userId = user["localId"] as? String,
            let email = user["email"] as? String
        else {
            throw FirebaseRESTAuthError.invalidResponse
        }
        return AuthenticatedAccount(
            userId: userId,
            email: email,
            emailVerified: user["emailVerified"] as? Bool ?? false,
            idToken: idToken,
            refreshToken: refreshToken
        )
    }

    private func sendEmailVerification(idToken: String) async throws {
        _ = try await request(
            endpoint: "accounts:sendOobCode",
            body: [
                "requestType": "VERIFY_EMAIL",
                "idToken": idToken
            ]
        )
    }

    private func updateDisplayName(idToken: String, name: String) async throws {
        _ = try await request(
            endpoint: "accounts:update",
            body: [
                "idToken": idToken,
                "displayName": name,
                "returnSecureToken": true
            ]
        )
    }

    private func saveMemberProfile(
        idToken: String,
        userId: String,
        email: String,
        name: String,
        furigana: String
    ) async throws {
        guard let url = URL(
            string: "https://firestore.googleapis.com/v1/projects/\(projectId)"
                + "/databases/(default)/documents/memberPrivate/\(userId)"
        ) else {
            throw FirebaseRESTAuthError.invalidResponse
        }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fields: [String: Any] = [
            "uid": ["stringValue": userId],
            "email": ["stringValue": email],
            "name": ["stringValue": name],
            "furigana": ["stringValue": furigana],
            "createdAt": ["timestampValue": timestamp],
            "updatedAt": ["timestampValue": timestamp]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 15
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["fields": fields]
        )

        let (_, response) = try await session.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw FirebaseRESTAuthError.profileSaveFailed
        }
    }

    private func request(
        endpoint: String,
        body: [String: Any]
    ) async throws -> [String: Any] {
        guard
            var components = URLComponents(
                string: "https://identitytoolkit.googleapis.com/v1/\(endpoint)"
            )
        else {
            throw FirebaseRESTAuthError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            throw FirebaseRESTAuthError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseRESTAuthError.invalidResponse
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard (200...299).contains(httpResponse.statusCode) else {
            let error = json["error"] as? [String: Any]
            let code = error?["message"] as? String ?? ""
            throw FirebaseRESTAuthError.server(code: code)
        }
        return json
    }
}

public enum FirebaseRESTAuthError: LocalizedError, Sendable {
    case invalidResponse
    case emailNotVerified
    case profileSaveFailed
    case biometricCredentialExpired
    case server(code: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "認証サーバーから正しい応答を受信できませんでした。"
        case .emailNotVerified:
            return "メールアドレスの確認が完了していません。確認メールを再送しました。"
        case .profileSaveFailed:
            return "アカウントは作成されましたが、会員情報を保存できませんでした。"
        case .biometricCredentialExpired:
            return "生体認証ログインの有効期限が切れました。パスワードで再度ログインしてください。"
        case .server(let code):
            let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
            let codeDescription = normalizedCode.isEmpty
                ? ""
                : "（Firebase: \(normalizedCode)）"
            switch normalizedCode {
            case "EMAIL_EXISTS":
                return "このメールアドレスはすでに登録されています。\(codeDescription)"
            case "EMAIL_NOT_FOUND", "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD":
                return "メールアドレスまたはパスワードが正しくありません。\(codeDescription)"
            case "USER_DISABLED":
                return "このアカウントは利用停止中です。\(codeDescription)"
            case "TOO_MANY_ATTEMPTS_TRY_LATER":
                return "試行回数が多すぎます。時間をおいて再度お試しください。\(codeDescription)"
            case "OPERATION_NOT_ALLOWED":
                return "Firebaseでメール/パスワード認証が有効になっていません。\(codeDescription)"
            case "INVALID_EMAIL", "MISSING_EMAIL":
                return "メールアドレスの形式を確認してください。\(codeDescription)"
            case "RESET_PASSWORD_EXCEED_LIMIT":
                return "再設定メールの送信回数が上限に達しています。時間をおいて再度お試しください。\(codeDescription)"
            case "API_KEY_INVALID":
                return "Firebase APIキーが正しくありません。アプリの設定を確認してください。\(codeDescription)"
            case "PROJECT_NOT_FOUND":
                return "Firebaseプロジェクトが見つかりません。接続先の設定を確認してください。\(codeDescription)"
            case "QUOTA_EXCEEDED":
                return "Firebaseの利用上限に達しています。時間をおいて再度お試しください。\(codeDescription)"
            default:
                if normalizedCode.hasPrefix("WEAK_PASSWORD") {
                    return "パスワードは8文字以上で入力してください。\(codeDescription)"
                }
                return "Firebase認証エラーです。通信環境とFirebase設定を確認してください。\(codeDescription)"
            }
        }
    }
}

public protocol CommunityRepository: Sendable {
    func publicCommunities(query: String) async throws -> [Community]
    func findCommunity(code: String, idToken: String) async throws -> Community
    func apply(community: Community, userId: String, idToken: String) async throws
    func memberships(userId: String, idToken: String) async throws
        -> [(CommunityMembership, Community)]
    func adminAccess(
        communityId: String,
        userId: String,
        idToken: String
    ) async throws -> CommunityAdminAccess?
    func pendingApplications(
        communityId: String,
        idToken: String
    ) async throws -> [CommunityMembership]
    func reviewApplication(
        communityId: String,
        applicantUserId: String,
        reviewerUserId: String,
        status: CommunityMembershipStatus,
        auditAction: String?,
        idToken: String
    ) async throws
    func administrators(
        communityId: String,
        idToken: String
    ) async throws -> [CommunityAdmin]
    func saveAdministrator(
        communityId: String,
        adminUserId: String,
        role: String,
        permissions: Set<String>,
        isActive: Bool,
        actorUserId: String,
        idToken: String
    ) async throws
    func communityMembers(
        communityId: String,
        idToken: String
    ) async throws -> [CommunityMembership]
    func auditLogs(
        communityId: String,
        idToken: String
    ) async throws -> [CommunityAuditLog]
    func bookingEvents(
        communityId: String,
        idToken: String
    ) async throws -> [BookingEvent]
    func adminBookingEvents(
        communityId: String,
        idToken: String
    ) async throws -> [BookingEvent]
    func saveBookingEvent(
        communityId: String,
        eventId: String,
        title: String,
        description: String,
        eventDate: Date?,
        feeAmount: Int,
        paymentRequired: Bool,
        zoomURL: String,
        isPublished: Bool,
        idToken: String
    ) async throws
    func bookingSlots(
        communityId: String,
        eventId: String,
        idToken: String
    ) async throws -> [BookingSlot]
    func bookingReservations(
        communityId: String,
        eventId: String,
        idToken: String
    ) async throws -> [BookingReservation]
    func saveBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        startAt: Date?,
        endAt: Date?,
        capacity: Int,
        isOpen: Bool,
        idToken: String
    ) async throws
    func bookedSlotIDs(
        communityId: String,
        eventId: String,
        userId: String,
        idToken: String
    ) async throws -> Set<String>
    func myBookingReservations(
        communityId: String,
        userId: String,
        idToken: String
    ) async throws -> [BookingReservation]
    func reserveBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String
    ) async throws
    func cancelBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String
    ) async throws
    func communityVideos(
        communityId: String,
        idToken: String
    ) async throws -> [DistributedVideo]
    func videoMemos(userId: String, idToken: String) async throws -> [String: String]
    func saveVideoMemo(
        userId: String,
        communityId: String,
        videoId: String,
        memo: String,
        idToken: String
    ) async throws
    func videoQuestions(
        communityId: String,
        memberUid: String,
        idToken: String
    ) async throws -> [VideoQuestion]
    func adminVideoQuestions(
        communityId: String,
        idToken: String
    ) async throws -> [VideoQuestion]
    func saveVideoQuestion(
        communityId: String,
        memberUid: String,
        video: DistributedVideo,
        memoText: String,
        questionText: String,
        playbackSeconds: Double,
        clientRequestId: String,
        idToken: String
    ) async throws
    func answerVideoQuestion(
        communityId: String,
        questionId: String,
        answerText: String,
        idToken: String
    ) async throws
    func adminCommunityVideos(
        communityId: String,
        idToken: String
    ) async throws -> [DistributedVideo]
    func vimeoLibraryVideos(
        communityId: String,
        idToken: String
    ) async throws -> [DistributedVideo]
    func vimeoFolders(
        communityId: String,
        idToken: String
    ) async throws -> [VimeoFolder]
    func vimeoFolderVideos(
        communityId: String,
        folderId: String,
        idToken: String
    ) async throws -> [DistributedVideo]
    func vimeoConfiguration(
        communityId: String,
        idToken: String
    ) async throws -> VimeoConfiguration
    func saveVimeoConfiguration(
        communityId: String,
        accessToken: String,
        userId: String,
        query: String,
        idToken: String
    ) async throws
    func saveCommunityVideo(
        communityId: String,
        videoId: String,
        title: String,
        description: String,
        vimeoVideoId: String,
        vimeoURL: String,
        thumbnailURL: String,
        isPublished: Bool,
        idToken: String
    ) async throws
}

public struct VimeoConfiguration: Equatable, Sendable {
    public let hasAccessToken: Bool
    public let userId: String
    public let query: String

    public init(hasAccessToken: Bool = false, userId: String = "", query: String = "") {
        self.hasAccessToken = hasAccessToken
        self.userId = userId
        self.query = query
    }
}

public struct VimeoFolder: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum CommunityRepositoryError: LocalizedError, Equatable {
    case invalidCode
    case notFound
    case inactive
    case joiningDisabled
    case invalidResponse
    case requestFailed
    case notAuthorized
    case alreadyExists

    public var errorDescription: String? {
        switch self {
        case .invalidCode: "コミュニティコードを確認してください。"
        case .notFound: "該当するコミュニティが見つかりませんでした。"
        case .inactive: "このコミュニティは現在利用できません。"
        case .joiningDisabled: "このコミュニティは現在、参加申請を受け付けていません。"
        case .invalidResponse: "コミュニティ情報を読み取れませんでした。"
        case .requestFailed: "通信に失敗しました。時間をおいて再度お試しください。"
        case .notAuthorized: "この操作を行う管理者権限がありません。"
        case .alreadyExists: "同じ内容は送信済みです。"
        }
    }
}

public struct FirebaseRESTCommunityRepository: CommunityRepository {
    private let projectId: String
    private let session: URLSession

    public init(projectId: String, session: URLSession = .shared) {
        self.projectId = projectId
        self.session = session
    }

    public func publicCommunities(query: String) async throws -> [Community] {
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "organizations"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "communitySurfingVisible"],
                        "op": "EQUAL",
                        "value": ["booleanValue": true]
                    ]
                ]
            ]
        ]
        let rows = try await requestJSON(
            path: "documents:runQuery",
            method: "POST",
            idToken: nil,
            body: body
        ) as? [[String: Any]] ?? []
        return rows
            .compactMap { $0["document"] as? [String: Any] }
            .compactMap { try? parseCommunity($0) }
            .filter { $0.isActive && $0.surfingVisible && $0.matchesPublicSearch(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func findCommunity(code: String, idToken: String) async throws -> Community {
        guard let normalized = CommunityCodeParser.parse(code) else {
            throw CommunityRepositoryError.invalidCode
        }
        if let direct = try? await getCommunity(id: normalized, idToken: idToken) {
            return try validated(direct)
        }
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "organizations"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "organizationCode"],
                        "op": "EQUAL",
                        "value": ["stringValue": normalized]
                    ]
                ],
                "limit": 1
            ]
        ]
        let rows = try await requestJSON(
            path: "documents:runQuery",
            method: "POST",
            idToken: idToken,
            body: body
        ) as? [[String: Any]]
        guard let document = rows?
            .compactMap({ $0["document"] as? [String: Any] }).first else {
            throw CommunityRepositoryError.notFound
        }
        return try validated(try parseCommunity(document))
    }

    public func apply(
        community: Community,
        userId: String,
        idToken: String
    ) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        var fields: [String: Any] = [
            "uid": ["stringValue": userId],
            "userId": ["stringValue": userId],
            "organizationId": ["stringValue": community.id],
            "communityId": ["stringValue": community.id],
            "status": ["stringValue": "pending"],
            "role": ["stringValue": "member"],
            "createdAt": ["timestampValue": now],
            "updatedAt": ["timestampValue": now]
        ]
        if let profile = try? await memberProfile(userId: userId, idToken: idToken) {
            if let value = string(profile, "name"), !value.isEmpty {
                fields["applicantName"] = ["stringValue": value]
            }
            if let value = string(profile, "furigana"), !value.isEmpty {
                fields["applicantFurigana"] = ["stringValue": value]
            }
            if let value = string(profile, "email"), !value.isEmpty {
                fields["applicantEmail"] = ["stringValue": value]
            }
        }
        _ = try await requestJSON(
            path: "documents/organizations/\(community.id)/members/\(userId)",
            method: "PATCH",
            idToken: idToken,
            body: ["fields": fields]
        )
    }

    public func memberships(
        userId: String,
        idToken: String
    ) async throws -> [(CommunityMembership, Community)] {
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "members", "allDescendants": true]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "uid"],
                        "op": "EQUAL",
                        "value": ["stringValue": userId]
                    ]
                ]
            ]
        ]
        let rows = try await requestJSON(
            path: "documents:runQuery",
            method: "POST",
            idToken: idToken,
            body: body
        ) as? [[String: Any]] ?? []
        var result: [(CommunityMembership, Community)] = []
        for row in rows {
            guard let document = row["document"] as? [String: Any],
                  let membership = parseMembership(document, userId: userId),
                  let community = try? await getCommunity(
                    id: membership.communityId,
                    idToken: idToken
                  ) else { continue }
            result.append((membership, community))
        }
        return result.sorted {
            $0.1.name.localizedStandardCompare($1.1.name) == .orderedAscending
        }
    }

    public func adminAccess(
        communityId: String,
        userId: String,
        idToken: String
    ) async throws -> CommunityAdminAccess? {
        do {
            guard let document = try await requestJSON(
                path: "documents/organizations/\(communityId)/admins/\(userId)",
                method: "GET",
                idToken: idToken
            ) as? [String: Any],
            let fields = document["fields"] as? [String: Any],
            bool(fields, "isActive") == true else {
                return nil
            }
            let permissions = permissionValues(fields, "permissions")
            return CommunityAdminAccess(
                communityId: communityId,
                userId: userId,
                role: string(fields, "role") ?? "admin",
                permissions: permissions,
                isLegacyFullAccess: fields["permissions"] == nil
            )
        } catch CommunityRepositoryError.notFound {
            return nil
        } catch CommunityRepositoryError.notAuthorized {
            return nil
        }
    }

    public func pendingApplications(
        communityId: String,
        idToken: String
    ) async throws -> [CommunityMembership] {
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "members"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "status"],
                        "op": "EQUAL",
                        "value": ["stringValue": CommunityMembershipStatus.pending.rawValue]
                    ]
                ]
            ]
        ]
        let rows = try await requestJSON(
            path: "documents/organizations/\(communityId):runQuery",
            method: "POST",
            idToken: idToken,
            body: body
        ) as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let document = row["document"] as? [String: Any],
                  let path = document["name"] as? String,
                  let userId = path.split(separator: "/").last.map(String.init) else {
                return nil
            }
            return parseMembership(document, userId: userId)
        }.sorted {
            ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast)
        }
    }

    public func reviewApplication(
        communityId: String,
        applicantUserId: String,
        reviewerUserId: String,
        status: CommunityMembershipStatus,
        auditAction: String?,
        idToken: String
    ) async throws {
        guard status == .approved || status == .rejected else {
            throw CommunityRepositoryError.invalidResponse
        }
        let auditId = UUID().uuidString.lowercased()
        let databaseRoot = "projects/\(projectId)/databases/(default)/documents"
        let body: [String: Any] = [
            "writes": [
                [
                    "update": [
                        "name": "\(databaseRoot)/organizations/\(communityId)/members/\(applicantUserId)",
                        "fields": [
                            "status": ["stringValue": status.rawValue],
                            "reviewedByUserId": ["stringValue": reviewerUserId]
                        ]
                    ],
                    "updateMask": [
                        "fieldPaths": ["status", "reviewedByUserId"]
                    ],
                    "updateTransforms": [
                        [
                            "fieldPath": "updatedAt",
                            "setToServerValue": "REQUEST_TIME"
                        ],
                        [
                            "fieldPath": "reviewedAt",
                            "setToServerValue": "REQUEST_TIME"
                        ]
                    ],
                    "currentDocument": ["exists": true]
                ],
                [
                    "update": [
                        "name": "\(databaseRoot)/organizations/\(communityId)/auditLogs/\(auditId)",
                        "fields": [
                            "action": ["stringValue": auditAction ?? "membership.\(status.rawValue)"],
                            "actorUserId": ["stringValue": reviewerUserId],
                            "targetUserId": ["stringValue": applicantUserId],
                            "communityId": ["stringValue": communityId]
                        ]
                    ],
                    "updateTransforms": [
                        [
                            "fieldPath": "createdAt",
                            "setToServerValue": "REQUEST_TIME"
                        ]
                    ],
                    "currentDocument": ["exists": false]
                ]
            ]
        ]
        _ = try await requestJSON(
            path: "documents:commit",
            method: "POST",
            idToken: idToken,
            body: body
        )
    }

    public func administrators(
        communityId: String,
        idToken: String
    ) async throws -> [CommunityAdmin] {
        let response = try await requestJSON(
            path: "documents/organizations/\(communityId)/admins?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return documents.compactMap { document in
            guard let fields = document["fields"] as? [String: Any],
                  let name = document["name"] as? String else { return nil }
            let userId = name.split(separator: "/").last.map(String.init) ?? ""
            guard !userId.isEmpty else { return nil }
            return CommunityAdmin(
                userId: userId,
                role: string(fields, "role") ?? "admin",
                permissions: Set(permissionValues(fields, "permissions")),
                isActive: bool(fields, "isActive") ?? true
            )
        }.sorted { $0.userId < $1.userId }
    }

    public func saveAdministrator(
        communityId: String,
        adminUserId: String,
        role: String,
        permissions: Set<String>,
        isActive: Bool,
        actorUserId: String,
        idToken: String
    ) async throws {
        let normalizedUserId = adminUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedActorUserId = actorUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedUserId.isEmpty, !normalizedActorUserId.isEmpty else {
            throw CommunityRepositoryError.invalidResponse
        }
        let fields: [String: Any] = [
            "uid": stringValue(normalizedUserId),
            "role": stringValue(role.isEmpty ? "admin" : role),
            "isActive": ["booleanValue": isActive],
            "permissions": [
                "arrayValue": [
                    "values": permissions.sorted().map { stringValue($0) }
                ]
            ]
        ]
        let databaseRoot = "projects/\(projectId)/databases/(default)/documents"
        let auditId = UUID().uuidString.lowercased()
        let auditAction = isActive ? "administrator.added" : "administrator.deactivated"
        _ = try await requestJSON(
            path: "documents:commit",
            method: "POST",
            idToken: idToken,
            body: [
                "writes": [
                    [
                        "update": [
                            "name": "\(databaseRoot)/organizations/\(communityId)/admins/\(normalizedUserId)",
                            "fields": fields
                        ],
                        "updateTransforms": [
                            [
                                "fieldPath": "updatedAt",
                                "setToServerValue": "REQUEST_TIME"
                            ]
                        ]
                    ],
                    [
                        "update": [
                            "name": "\(databaseRoot)/organizations/\(communityId)/auditLogs/\(auditId)",
                            "fields": [
                                "action": ["stringValue": auditAction],
                                "actorUserId": ["stringValue": normalizedActorUserId],
                                "targetUserId": ["stringValue": normalizedUserId],
                                "communityId": ["stringValue": communityId]
                            ]
                        ],
                        "updateTransforms": [
                            [
                                "fieldPath": "createdAt",
                                "setToServerValue": "REQUEST_TIME"
                            ]
                        ],
                        "currentDocument": ["exists": false]
                    ]
                ]
            ]
        )
    }

    public func communityMembers(
        communityId: String,
        idToken: String
    ) async throws -> [CommunityMembership] {
        let response = try await requestJSON(
            path: "documents/organizations/\(communityId)/members?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return documents.compactMap { document in
            let userId = (document["name"] as? String)?
                .split(separator: "/")
                .last
                .map(String.init) ?? ""
            return parseMembership(document, userId: userId)
        }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    public func auditLogs(
        communityId: String,
        idToken: String
    ) async throws -> [CommunityAuditLog] {
        let response = try await requestJSON(
            path: "documents/organizations/\(communityId)/auditLogs?pageSize=100",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return documents.compactMap(parseAuditLog)
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    public func bookingEvents(
        communityId: String,
        idToken: String
    ) async throws -> [BookingEvent] {
        let response = try await requestJSON(
            path: "documents/organizations/\(communityId)/bookingEvents?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return documents.compactMap { document in
            guard let fields = document["fields"] as? [String: Any],
                  bool(fields, "isPublished") == true else { return nil }
            let id = (document["name"] as? String)?.split(separator: "/").last.map(String.init) ?? ""
            guard !id.isEmpty else { return nil }
            return BookingEvent(
                id: id,
                communityId: communityId,
                title: string(fields, "title") ?? "イベント",
                description: string(fields, "description") ?? "",
                eventDate: timestamp(fields, "eventDate"),
                feeAmount: Int(number(fields, "feeAmount") ?? 0),
                paymentRequired: bool(fields, "paymentRequired") ?? false,
                zoomURL: (string(fields, "zoomURL") ?? string(fields, "zoomUrl"))
                    .flatMap(URL.init(string:)),
                isPublished: true
            )
        }.sorted { ($0.eventDate ?? .distantFuture) < ($1.eventDate ?? .distantFuture) }
    }

    public func adminBookingEvents(
        communityId: String,
        idToken: String
    ) async throws -> [BookingEvent] {
        let response = try await requestJSON(
            path: "documents/organizations/\(communityId)/bookingEvents?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return documents.compactMap { document in
            guard let fields = document["fields"] as? [String: Any] else { return nil }
            let id = (document["name"] as? String)?.split(separator: "/").last.map(String.init) ?? ""
            guard !id.isEmpty else { return nil }
            return BookingEvent(
                id: id,
                communityId: communityId,
                title: string(fields, "title") ?? "イベント",
                description: string(fields, "description") ?? "",
                eventDate: timestamp(fields, "eventDate"),
                feeAmount: Int(number(fields, "feeAmount") ?? 0),
                paymentRequired: bool(fields, "paymentRequired") ?? false,
                zoomURL: (string(fields, "zoomURL") ?? string(fields, "zoomUrl"))
                    .flatMap(URL.init(string:)),
                isPublished: bool(fields, "isPublished") ?? false
            )
        }.sorted { ($0.eventDate ?? .distantFuture) < ($1.eventDate ?? .distantFuture) }
    }

    public func saveBookingEvent(
        communityId: String,
        eventId: String,
        title: String,
        description: String,
        eventDate: Date?,
        feeAmount: Int,
        paymentRequired: Bool,
        zoomURL: String,
        isPublished: Bool,
        idToken: String
    ) async throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty, feeAmount >= 0 else {
            throw CommunityRepositoryError.invalidResponse
        }
        var fields: [String: Any] = [
            "title": stringValue(normalizedTitle),
            "description": stringValue(description.trimmingCharacters(in: .whitespacesAndNewlines)),
            "feeAmount": ["integerValue": String(feeAmount)],
            "paymentRequired": ["booleanValue": paymentRequired],
            "zoomURL": stringValue(zoomURL.trimmingCharacters(in: .whitespacesAndNewlines)),
            "isPublished": ["booleanValue": isPublished],
            "updatedAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
        ]
        if let eventDate {
            fields["eventDate"] = ["timestampValue": ISO8601DateFormatter().string(from: eventDate)]
        }
        _ = try await requestJSON(
            path: "documents/organizations/\(communityId)/bookingEvents/\(eventId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UUID().uuidString : eventId)",
            method: "PATCH",
            idToken: idToken,
            body: ["fields": fields]
        )
    }

    public func bookingSlots(
        communityId: String,
        eventId: String,
        idToken: String
    ) async throws -> [BookingSlot] {
        let response = try await requestJSON(
            path: "documents/organizations/\(communityId)/bookingEvents/\(eventId)/slots?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return documents.compactMap { document in
            guard let fields = document["fields"] as? [String: Any] else { return nil }
            let id = (document["name"] as? String)?.split(separator: "/").last.map(String.init) ?? ""
            guard !id.isEmpty else { return nil }
            return BookingSlot(
                id: id,
                eventId: eventId,
                startAt: timestamp(fields, "startAt"),
                endAt: timestamp(fields, "endAt"),
                capacity: Int(number(fields, "capacity") ?? 0),
                reservedCount: Int(number(fields, "reservedCount") ?? 0),
                paidCount: Int(number(fields, "paidCount") ?? 0),
                isOpen: bool(fields, "isOpen") ?? true
            )
        }.sorted { ($0.startAt ?? .distantFuture) < ($1.startAt ?? .distantFuture) }
    }

    public func bookingReservations(
        communityId: String,
        eventId: String,
        idToken: String
    ) async throws -> [BookingReservation] {
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "bookings", "allDescendants": true]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "eventId"],
                        "op": "EQUAL",
                        "value": stringValue(eventId)
                    ]
                ]
            ]
        ]
        let rows = try await requestJSON(
            path: "documents:runQuery",
            method: "POST",
            idToken: idToken,
            body: body
        ) as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let fields = (row["document"] as? [String: Any])?["fields"] as? [String: Any],
                  string(fields, "organizationId") == communityId,
                  let slotId = string(fields, "slotId"),
                  let userId = string(fields, "memberUid") else { return nil }
            return BookingReservation(
                slotId: slotId,
                userId: userId,
                status: string(fields, "status") ?? "reserved",
                purchaseStatus: string(fields, "purchaseStatus") ?? "not-required"
            )
        }.sorted { ($0.slotId, $0.userId) < ($1.slotId, $1.userId) }
    }

    public func saveBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        startAt: Date?,
        endAt: Date?,
        capacity: Int,
        isOpen: Bool,
        idToken: String
    ) async throws {
        guard !eventId.isEmpty, capacity > 0 else {
            throw CommunityRepositoryError.invalidResponse
        }
        var fields: [String: Any] = [
            "capacity": ["integerValue": String(capacity)],
            "isOpen": ["booleanValue": isOpen],
            "updatedAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
        ]
        if let startAt {
            fields["startAt"] = ["timestampValue": ISO8601DateFormatter().string(from: startAt)]
        }
        if let endAt {
            fields["endAt"] = ["timestampValue": ISO8601DateFormatter().string(from: endAt)]
        }
        _ = try await requestJSON(
            path: "documents/organizations/\(communityId)/bookingEvents/\(eventId)/slots/\(slotId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UUID().uuidString : slotId)",
            method: "PATCH",
            idToken: idToken,
            body: ["fields": fields]
        )
    }

    public func bookedSlotIDs(
        communityId: String,
        eventId: String,
        userId: String,
        idToken: String
    ) async throws -> Set<String> {
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "bookings", "allDescendants": true]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "memberUid"],
                        "op": "EQUAL",
                        "value": stringValue(userId)
                    ]
                ]
            ]
        ]
        let rows = try await requestJSON(
            path: "documents:runQuery",
            method: "POST",
            idToken: idToken,
            body: body
        ) as? [[String: Any]] ?? []
        return Set(rows.compactMap { row -> String? in
            guard let fields = (row["document"] as? [String: Any])?["fields"] as? [String: Any],
                  string(fields, "organizationId") == communityId,
                  string(fields, "eventId") == eventId,
                  string(fields, "status") == "reserved" else { return nil }
            return string(fields, "slotId")
        })
    }

    public func myBookingReservations(
        communityId: String,
        userId: String,
        idToken: String
    ) async throws -> [BookingReservation] {
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "bookings", "allDescendants": true]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "memberUid"],
                        "op": "EQUAL",
                        "value": stringValue(userId)
                    ]
                ]
            ]
        ]
        let rows = try await requestJSON(
            path: "documents:runQuery",
            method: "POST",
            idToken: idToken,
            body: body
        ) as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let fields = (row["document"] as? [String: Any])?["fields"] as? [String: Any],
                  string(fields, "organizationId") == communityId,
                  let eventId = string(fields, "eventId"),
                  let slotId = string(fields, "slotId"),
                  string(fields, "status") == "reserved" else { return nil }
            return BookingReservation(
                eventId: eventId,
                slotId: slotId,
                userId: userId,
                status: "reserved",
                purchaseStatus: string(fields, "purchaseStatus") ?? "not-required"
            )
        }.sorted { ($0.eventId, $0.slotId) < ($1.eventId, $1.slotId) }
    }

    public func reserveBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String
    ) async throws {
        try await bookingRequest(
            endpoint: "reserveBookingSlotHttp",
            communityId: communityId,
            eventId: eventId,
            slotId: slotId,
            idToken: idToken
        )
    }

    public func cancelBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String
    ) async throws {
        try await bookingRequest(
            endpoint: "cancelBookingSlotHttp",
            communityId: communityId,
            eventId: eventId,
            slotId: slotId,
            idToken: idToken
        )
    }

    public func communityVideos(
        communityId: String,
        idToken: String
    ) async throws -> [DistributedVideo] {
        let response = try await requestJSON(
            path: "documents/organizations/\(communityId)/videos?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return documents.compactMap { document in
            let fields = document["fields"] as? [String: Any] ?? [:]
            let video = parseDistributedVideo(
                document: document,
                fields: fields,
                communityId: communityId,
            )
            guard video.isPublished,
                  !video.isPremium else { return nil }
            return video
        }.sorted {
            $0.sortOrder == $1.sortOrder
                ? $0.title < $1.title
                : $0.sortOrder < $1.sortOrder
        }
    }

    public func videoMemos(
        userId: String,
        idToken: String
    ) async throws -> [String: String] {
        let response = try await requestJSON(
            path: "documents/memberPrivate/\(userId)/videoMemos?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return documents.reduce(into: [String: String]()) { result, document in
            guard let fields = document["fields"] as? [String: Any],
                  let communityId = string(fields, "communityId"),
                  let videoId = string(fields, "videoId"),
                  let memo = string(fields, "memo") else { return }
            result["\(communityId):\(videoId)"] = memo
        }
    }

    public func saveVideoMemo(
        userId: String,
        communityId: String,
        videoId: String,
        memo: String,
        idToken: String
    ) async throws {
        let documentId = "\(communityId)-\(videoId)"
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        let path = "documents/memberPrivate/\(userId)/videoMemos/\(documentId)"
        let normalized = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            do { _ = try await requestJSON(path: path, method: "DELETE", idToken: idToken) }
            catch CommunityRepositoryError.notFound { }
        } else {
            let fields: [String: Any] = [
                "userId": stringValue(userId),
                "communityId": stringValue(communityId),
                "videoId": stringValue(videoId),
                "memo": stringValue(normalized),
                "updatedAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
            ]
            _ = try await requestJSON(
                path: path,
                method: "PATCH",
                idToken: idToken,
                body: ["fields": fields]
            )
        }
    }

    public func videoQuestions(
        communityId: String,
        memberUid: String,
        idToken: String
    ) async throws -> [VideoQuestion] {
        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "videoQuestions"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "memberUid"],
                        "op": "EQUAL",
                        "value": stringValue(memberUid)
                    ]
                ]
            ]
        ]
        let rows = try await requestJSON(
            path: "documents/organizations/\(communityId):runQuery",
            method: "POST",
            idToken: idToken,
            body: body
        ) as? [[String: Any]] ?? []
        return rows.compactMap { (row: [String: Any]) -> VideoQuestion? in
            guard let document = row["document"] as? [String: Any],
                  let fields = document["fields"] as? [String: Any],
                  let questionText = string(fields, "questionText") else { return nil }
            let id = (document["name"] as? String)?.split(separator: "/").last.map(String.init) ?? ""
            return VideoQuestion(
                id: id,
                communityId: communityId,
                memberUid: string(fields, "memberUid") ?? memberUid,
                videoId: string(fields, "videoId") ?? "",
                videoTitle: string(fields, "videoTitle") ?? "",
                playbackSeconds: number(fields, "playbackSeconds") ?? 0,
                memoText: string(fields, "memoText") ?? "",
                questionText: questionText,
                answerText: string(fields, "answerText") ?? "",
                createdAt: timestamp(fields, "createdAt"),
                answeredAt: timestamp(fields, "answeredAt"),
                syncStatus: VideoQuestionSyncStatus(
                    rawValue: string(fields, "syncStatus") ?? "synced"
                ) ?? .synced,
                clientRequestId: string(fields, "clientRequestId") ?? id
            )
        }.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    public func saveVideoQuestion(
        communityId: String,
        memberUid: String,
        video: DistributedVideo,
        memoText: String,
        questionText: String,
        playbackSeconds: Double,
        clientRequestId: String,
        idToken: String
    ) async throws {
        let normalized = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw CommunityRepositoryError.invalidResponse }
        let normalizedRequestId = clientRequestId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRequestId.isEmpty else { throw CommunityRepositoryError.invalidResponse }
        let documentId = normalizedRequestId.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        let fields: [String: Any] = [
            "memberUid": stringValue(memberUid),
            "videoId": stringValue(video.id),
            "videoType": stringValue("vimeo"),
            "videoTitle": stringValue(video.title),
            "playbackSeconds": ["doubleValue": playbackSeconds],
            "memoText": stringValue(memoText.trimmingCharacters(in: .whitespacesAndNewlines)),
            "questionText": stringValue(normalized),
            "answerText": stringValue(""),
            "answeredAt": ["nullValue": NSNull()],
            "syncStatus": stringValue(VideoQuestionSyncStatus.synced.rawValue),
            "clientRequestId": stringValue(normalizedRequestId),
            "createdAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
        ]
        do {
            _ = try await requestJSON(
                path: "documents/organizations/\(communityId)/videoQuestions?documentId=\(documentId)",
                method: "POST",
                idToken: idToken,
                body: ["fields": fields]
            )
        } catch CommunityRepositoryError.alreadyExists {
            // The first request may have committed even if its response was lost.
            // A create-only retry with the same clientRequestId is therefore success.
        }
    }

    public func adminVideoQuestions(
        communityId: String,
        idToken: String
    ) async throws -> [VideoQuestion] {
        let response = try await requestJSON(
            path: "documents/organizations/\(communityId)/videoQuestions?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return documents.compactMap { document in
            guard let fields = document["fields"] as? [String: Any],
                  let questionText = string(fields, "questionText") else { return nil }
            let id = (document["name"] as? String)?.split(separator: "/").last.map(String.init) ?? ""
            return VideoQuestion(
                id: id,
                communityId: communityId,
                memberUid: string(fields, "memberUid") ?? "",
                videoId: string(fields, "videoId") ?? "",
                videoTitle: string(fields, "videoTitle") ?? "",
                playbackSeconds: number(fields, "playbackSeconds") ?? 0,
                memoText: string(fields, "memoText") ?? "",
                questionText: questionText,
                answerText: string(fields, "answerText") ?? "",
                createdAt: timestamp(fields, "createdAt"),
                answeredAt: timestamp(fields, "answeredAt"),
                syncStatus: VideoQuestionSyncStatus(
                    rawValue: string(fields, "syncStatus") ?? "synced"
                ) ?? .synced,
                clientRequestId: string(fields, "clientRequestId") ?? id
            )
        }.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    public func answerVideoQuestion(
        communityId: String,
        questionId: String,
        answerText: String,
        idToken: String
    ) async throws {
        let normalized = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let answeredAt = ISO8601DateFormatter().string(from: Date())
        let fields: [String: Any] = [
            "answerText": stringValue(normalized),
            "answeredAt": ["timestampValue": answeredAt],
            "updatedAt": ["timestampValue": answeredAt],
        ]
        _ = try await requestJSON(
            path: "documents/organizations/\(communityId)/videoQuestions/\(questionId)",
            method: "PATCH",
            idToken: idToken,
            body: ["fields": fields]
        )
    }

    public func adminCommunityVideos(
        communityId: String,
        idToken: String
    ) async throws -> [DistributedVideo] {
        let response = try await requestJSON(
            path: "documents/organizations/\(communityId)/videos?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        let documents = response?["documents"] as? [[String: Any]] ?? []
        return documents.compactMap { document in
            let fields = document["fields"] as? [String: Any] ?? [:]
            let video = parseDistributedVideo(
                document: document,
                fields: fields,
                communityId: communityId,
            )
            return video.isPremium ? nil : video
        }.sorted {
            $0.sortOrder == $1.sortOrder ? $0.title < $1.title : $0.sortOrder < $1.sortOrder
        }
    }

    public func vimeoLibraryVideos(
        communityId: String,
        idToken: String
    ) async throws -> [DistributedVideo] {
        guard let url = URL(
            string: "https://asia-northeast1-\(projectId).cloudfunctions.net/fetchVimeoVideosHttp"
        ) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "organizationId": communityId
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let videos = payload["videos"] as? [[String: Any]] else {
            throw URLError(.badServerResponse)
        }
        return videos.compactMap { item in
            guard let vimeoVideoId = item["id"] as? String,
                  !vimeoVideoId.isEmpty else { return nil }
            return DistributedVideo(
                id: vimeoVideoId,
                communityId: communityId,
                videoTitle: item["title"] as? String ?? "Vimeo動画",
                description: item["description"] as? String ?? "",
                videoUrl: item["link"] as? String ?? "",
                vimeoUrl: "https://vimeo.com/\(vimeoVideoId)",
                providerVideoId: vimeoVideoId,
                thumbnailUrl: item["thumbnailUrl"] as? String ?? "",
                isPublished: false,
                isMembersOnly: true,
                sortOrder: 0
            )
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public func vimeoFolders(
        communityId: String,
        idToken: String
    ) async throws -> [VimeoFolder] {
        guard let url = URL(
            string: "https://asia-northeast1-\(projectId).cloudfunctions.net/fetchVimeoFoldersHttp"
        ) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["organizationId": communityId])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let folders = payload["folders"] as? [[String: Any]] else {
            throw URLError(.badServerResponse)
        }
        return folders.compactMap { item in
            guard let id = item["id"] as? String, !id.isEmpty else { return nil }
            return VimeoFolder(id: id, name: item["name"] as? String ?? "名称未設定フォルダ")
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func vimeoFolderVideos(
        communityId: String,
        folderId: String,
        idToken: String
    ) async throws -> [DistributedVideo] {
        guard let url = URL(
            string: "https://asia-northeast1-\(projectId).cloudfunctions.net/fetchVimeoVideosHttp"
        ) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "organizationId": communityId,
            "folderId": folderId
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let videos = payload["videos"] as? [[String: Any]] else {
            throw URLError(.badServerResponse)
        }
        return videos.compactMap { item in
            guard let vimeoVideoId = item["id"] as? String, !vimeoVideoId.isEmpty else { return nil }
            return DistributedVideo(
                id: vimeoVideoId,
                communityId: communityId,
                videoTitle: item["title"] as? String ?? "Vimeo動画",
                description: item["description"] as? String ?? "",
                videoUrl: item["link"] as? String ?? "",
                vimeoUrl: "https://vimeo.com/\(vimeoVideoId)",
                providerVideoId: vimeoVideoId,
                thumbnailUrl: item["thumbnailUrl"] as? String ?? "",
                isPublished: false,
                isMembersOnly: true,
                sortOrder: 0
            )
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public func vimeoConfiguration(
        communityId: String,
        idToken: String
    ) async throws -> VimeoConfiguration {
        guard let url = URL(
            string: "https://asia-northeast1-\(projectId).cloudfunctions.net/getVimeoConfigHttp"
        ) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["organizationId": communityId])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.badServerResponse)
        }
        return VimeoConfiguration(
            hasAccessToken: payload["hasAccessToken"] as? Bool ?? false,
            userId: payload["userId"] as? String ?? "",
            query: payload["query"] as? String ?? ""
        )
    }

    public func saveVimeoConfiguration(
        communityId: String,
        accessToken: String,
        userId: String,
        query: String,
        idToken: String
    ) async throws {
        guard let url = URL(
            string: "https://asia-northeast1-\(projectId).cloudfunctions.net/saveVimeoConfigHttp"
        ) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "organizationId": communityId,
            "accessToken": accessToken.trimmingCharacters(in: .whitespacesAndNewlines),
            "userId": userId.trimmingCharacters(in: .whitespacesAndNewlines),
            "query": query.trimmingCharacters(in: .whitespacesAndNewlines)
        ])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func saveCommunityVideo(
        communityId: String,
        videoId: String,
        title: String,
        description: String,
        vimeoVideoId: String,
        vimeoURL: String,
        thumbnailURL: String,
        isPublished: Bool,
        idToken: String
    ) async throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedVimeoID = vimeoVideoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty, !normalizedVimeoID.isEmpty else {
            throw CommunityRepositoryError.invalidResponse
        }
        let fields: [String: Any] = [
            "title": stringValue(normalizedTitle),
            "description": stringValue(description.trimmingCharacters(in: .whitespacesAndNewlines)),
            "vimeoVideoId": stringValue(normalizedVimeoID),
            "vimeoUrl": stringValue(vimeoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "https://vimeo.com/\(normalizedVimeoID)" : vimeoURL),
            "thumbnailUrl": stringValue(thumbnailURL.trimmingCharacters(in: .whitespacesAndNewlines)),
            "isPublished": ["booleanValue": isPublished],
            "isMembersOnly": ["booleanValue": true],
            "sortOrder": stringValue("0"),
            "updatedAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
        ]
        _ = try await requestJSON(
            path: "documents/organizations/\(communityId)/videos/\(videoId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UUID().uuidString : videoId)",
            method: "PATCH",
            idToken: idToken,
            body: ["fields": fields]
        )
    }

    private func memberProfile(
        userId: String,
        idToken: String
    ) async throws -> [String: Any] {
        guard let document = try await requestJSON(
            path: "documents/memberPrivate/\(userId)",
            method: "GET",
            idToken: idToken
        ) as? [String: Any],
        let fields = document["fields"] as? [String: Any] else {
            throw CommunityRepositoryError.invalidResponse
        }
        return fields
    }

    private func getCommunity(id: String, idToken: String) async throws -> Community {
        guard let document = try await requestJSON(
            path: "documents/organizations/\(id)",
            method: "GET",
            idToken: idToken
        ) as? [String: Any] else {
            throw CommunityRepositoryError.invalidResponse
        }
        return try parseCommunity(document)
    }

    private func validated(_ community: Community) throws -> Community {
        guard community.isActive else { throw CommunityRepositoryError.inactive }
        guard community.joinEnabled else { throw CommunityRepositoryError.joiningDisabled }
        return community
    }

    private func parseCommunity(_ document: [String: Any]) throws -> Community {
        guard let fields = document["fields"] as? [String: Any] else {
            throw CommunityRepositoryError.invalidResponse
        }
        let id = (document["name"] as? String)?.split(separator: "/").last.map(String.init) ?? ""
        guard !id.isEmpty, let name = string(fields, "name"), !name.isEmpty else {
            throw CommunityRepositoryError.invalidResponse
        }
        return Community(
            id: id,
            code: string(fields, "organizationCode") ?? id,
            name: name,
            description: string(fields, "description") ?? "",
            logoURL: string(fields, "logoImageURL").flatMap(URL.init(string:)),
            homepageURL: string(fields, "homepageURL").flatMap(URL.init(string:)),
            isActive: bool(fields, "isActive") ?? true,
            joinEnabled: bool(fields, "communityJoinEnabled") ?? false,
            surfingVisible: bool(fields, "communitySurfingVisible") ?? false
        )
    }

    private func parseMembership(
        _ document: [String: Any],
        userId: String
    ) -> CommunityMembership? {
        guard let fields = document["fields"] as? [String: Any],
              let path = document["name"] as? String else { return nil }
        let components = path.split(separator: "/")
        guard let organizationIndex = components.lastIndex(of: "organizations"),
              components.indices.contains(organizationIndex + 1),
              let rawStatus = string(fields, "status"),
              let status = CommunityMembershipStatus(rawValue: rawStatus) else { return nil }
        return CommunityMembership(
            id: components.last.map(String.init) ?? userId,
            communityId: String(components[organizationIndex + 1]),
            userId: userId,
            status: status,
            role: string(fields, "role") ?? "member",
            joinedAt: timestamp(fields, "joinedAt"),
            applicantName: string(fields, "applicantName"),
            applicantFurigana: string(fields, "applicantFurigana"),
            applicantEmail: string(fields, "applicantEmail"),
            createdAt: timestamp(fields, "createdAt"),
            categoryIds: Set(
                stringArray(fields, "categoryIds")
                    + stringArray(fields, "categories")
                    + [string(fields, "categoryId")].compactMap { $0 }
            )
            )
    }

    private func parseAuditLog(_ document: [String: Any]) -> CommunityAuditLog? {
        guard let fields = document["fields"] as? [String: Any],
              let name = document["name"] as? String else { return nil }
        let id = name.split(separator: "/").last.map(String.init) ?? ""
        guard !id.isEmpty, let action = string(fields, "action") else { return nil }
        let components = name.split(separator: "/")
        let communityId = string(fields, "communityId")
            ?? components.lastIndex(of: "organizations")
            .flatMap { index in
                components.indices.contains(index + 1)
                    ? String(components[index + 1])
                    : nil
            }
            ?? ""
        return CommunityAuditLog(
            id: id,
            action: action,
            actorUserId: string(fields, "actorUserId"),
            targetUserId: string(fields, "targetUserId"),
            communityId: communityId,
            createdAt: timestamp(fields, "createdAt")
        )
    }

    private func permissionValues(
        _ fields: [String: Any],
        _ key: String
    ) -> Set<String> {
        guard let value = fields[key] as? [String: Any] else { return [] }
        if let array = (value["arrayValue"] as? [String: Any])?["values"]
            as? [[String: Any]] {
            return Set(array.compactMap { $0["stringValue"] as? String })
        }
        if let mapFields = (value["mapValue"] as? [String: Any])?["fields"]
            as? [String: [String: Any]] {
            return Set(mapFields.compactMap { key, value in
                value["booleanValue"] as? Bool == true ? key : nil
            })
        }
        return []
    }

    private func string(_ fields: [String: Any], _ key: String) -> String? {
        (fields[key] as? [String: Any])?["stringValue"] as? String
    }

    private func stringValue(_ value: String) -> [String: Any] {
        ["stringValue": value]
    }

    private func bool(_ fields: [String: Any], _ key: String) -> Bool? {
        (fields[key] as? [String: Any])?["booleanValue"] as? Bool
    }

    private func number(_ fields: [String: Any], _ key: String) -> Double? {
        guard let value = fields[key] as? [String: Any] else { return nil }
        if let doubleValue = value["doubleValue"] as? Double { return doubleValue }
        if let integerValue = value["integerValue"] as? String { return Double(integerValue) }
        return nil
    }

    private func timestamp(_ fields: [String: Any], _ key: String) -> Date? {
        guard let value = (fields[key] as? [String: Any])?["timestampValue"] as? String else {
            return nil
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private func stringArray(_ fields: [String: Any], _ key: String) -> [String] {
        guard let value = fields[key] as? [String: Any],
              let array = value["arrayValue"] as? [String: Any],
              let values = array["values"] as? [[String: Any]] else {
            return []
        }
        return values.compactMap { $0["stringValue"] as? String }
    }

    private func bookingRequest(
        endpoint: String,
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String
    ) async throws {
        guard let url = URL(
            string: "https://asia-northeast1-\(projectId).cloudfunctions.net/\(endpoint)"
        ) else {
            throw CommunityRepositoryError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "organizationId": communityId,
            "eventId": eventId,
            "slotId": slotId,
        ])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CommunityRepositoryError.requestFailed
        }
    }

    private func requestJSON(
        path: String,
        method: String,
        idToken: String?,
        body: [String: Any]? = nil
    ) async throws -> Any {
        guard let url = URL(
            string: "https://firestore.googleapis.com/v1/projects/\(projectId)"
                + "/databases/(default)/\(path)"
        ) else { throw CommunityRepositoryError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        if let idToken {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CommunityRepositoryError.requestFailed
        }
        if httpResponse.statusCode == 404 { throw CommunityRepositoryError.notFound }
        if httpResponse.statusCode == 409 { throw CommunityRepositoryError.alreadyExists }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw CommunityRepositoryError.notAuthorized
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw CommunityRepositoryError.requestFailed
        }
        return try JSONSerialization.jsonObject(with: data)
    }
}

private func string(_ fields: [String: Any], _ key: String) -> String? {
    (fields[key] as? [String: Any])?["stringValue"] as? String
}

private func bool(_ fields: [String: Any], _ key: String) -> Bool? {
    (fields[key] as? [String: Any])?["booleanValue"] as? Bool
}

private func number(_ fields: [String: Any], _ key: String) -> Double? {
    guard let value = fields[key] as? [String: Any] else { return nil }
    if let doubleValue = value["doubleValue"] as? Double { return doubleValue }
    if let integerValue = value["integerValue"] as? String { return Double(integerValue) }
    return nil
}

private func timestamp(_ fields: [String: Any], _ key: String) -> Date? {
    guard let value = (fields[key] as? [String: Any])?["timestampValue"] as? String else {
        return nil
    }
    return ISO8601DateFormatter().date(from: value)
}

internal func parseDistributedVideo(
    document: [String: Any],
    fields: [String: Any],
    communityId: String
) -> DistributedVideo {
    let id = document["name"] as? String
    let documentID = id?.split(separator: "/").last.map(String.init) ?? ""
    let vimeoVideoId = string(fields, "providerVideoId")
        ?? string(fields, "vimeoVideoId")
        ?? ""
    let resolvedID = documentID.isEmpty ? (vimeoVideoId.isEmpty ? UUID().uuidString : vimeoVideoId) : documentID
    return DistributedVideo(
        id: resolvedID,
        communityId: communityId,
        videoTitle: string(fields, "videoTitle") ?? string(fields, "title") ?? "Vimeo動画",
        description: string(fields, "description") ?? "",
        embedHtml: string(fields, "embedHtml") ?? "",
        videoUrl: string(fields, "videoUrl") ?? "",
        vimeoUrl: vimeoVideoId.isEmpty
            ? (string(fields, "vimeoUrl") ?? string(fields, "videoUrl") ?? "")
            : "https://vimeo.com/\(vimeoVideoId)",
        providerVideoId: vimeoVideoId,
        videoType: string(fields, "videoType") ?? "distributed_vimeo",
        thumbnailUrl: string(fields, "thumbnailUrl") ?? "",
        primaryCategoryId: string(fields, "primaryCategoryId")
            ?? string(fields, "category")
            ?? string(fields, "categoryId")
            ?? "",
        secondaryCategoryId: string(fields, "secondaryCategoryId") ?? "",
        isPremium: bool(fields, "isPremium") ?? false,
        createdAt: timestamp(fields, "createdAt"),
        updatedAt: timestamp(fields, "updatedAt"),
        isPublished: bool(fields, "isPublished") ?? false,
        isMembersOnly: bool(fields, "isMembersOnly") ?? false,
        sortOrder: Int(number(fields, "sortOrder") ?? 0)
    )
}
