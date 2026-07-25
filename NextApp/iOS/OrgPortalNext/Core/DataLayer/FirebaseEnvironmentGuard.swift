import Foundation
import Model

public enum FirebaseEnvironment: String, Sendable {
    case emulator
    case development
    case production
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
            switch code {
            case "EMAIL_EXISTS":
                return "このメールアドレスはすでに登録されています。"
            case "EMAIL_NOT_FOUND", "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD":
                return "メールアドレスまたはパスワードが正しくありません。"
            case "USER_DISABLED":
                return "このアカウントは利用停止中です。"
            case "TOO_MANY_ATTEMPTS_TRY_LATER":
                return "試行回数が多すぎます。時間をおいて再度お試しください。"
            default:
                if code.hasPrefix("WEAK_PASSWORD") {
                    return "パスワードは8文字以上で入力してください。"
                }
                return "認証処理に失敗しました。通信環境を確認して再度お試しください。"
            }
        }
    }
}

public protocol CommunityRepository: Sendable {
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
        idToken: String
    ) async throws
}

public enum CommunityRepositoryError: LocalizedError, Equatable {
    case invalidCode
    case notFound
    case inactive
    case joiningDisabled
    case invalidResponse
    case requestFailed
    case notAuthorized

    public var errorDescription: String? {
        switch self {
        case .invalidCode: "コミュニティコードを確認してください。"
        case .notFound: "該当するコミュニティが見つかりませんでした。"
        case .inactive: "このコミュニティは現在利用できません。"
        case .joiningDisabled: "このコミュニティは現在、参加申請を受け付けていません。"
        case .invalidResponse: "コミュニティ情報を読み取れませんでした。"
        case .requestFailed: "通信に失敗しました。時間をおいて再度お試しください。"
        case .notAuthorized: "この操作を行う管理者権限がありません。"
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
                            "action": ["stringValue": "membership.\(status.rawValue)"],
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
            joinEnabled: bool(fields, "communityJoinEnabled") ?? false
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

    private func bool(_ fields: [String: Any], _ key: String) -> Bool? {
        (fields[key] as? [String: Any])?["booleanValue"] as? Bool
    }

    private func timestamp(_ fields: [String: Any], _ key: String) -> Date? {
        guard let value = (fields[key] as? [String: Any])?["timestampValue"] as? String else {
            return nil
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private func requestJSON(
        path: String,
        method: String,
        idToken: String,
        body: [String: Any]? = nil
    ) async throws -> Any {
        guard let url = URL(
            string: "https://firestore.googleapis.com/v1/projects/\(projectId)"
                + "/databases/(default)/\(path)"
        ) else { throw CommunityRepositoryError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CommunityRepositoryError.requestFailed
        }
        if httpResponse.statusCode == 404 { throw CommunityRepositoryError.notFound }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw CommunityRepositoryError.notAuthorized
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw CommunityRepositoryError.requestFailed
        }
        return try JSONSerialization.jsonObject(with: data)
    }
}
