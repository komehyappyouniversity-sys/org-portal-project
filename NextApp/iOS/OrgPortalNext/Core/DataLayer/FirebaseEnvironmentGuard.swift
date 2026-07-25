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

    public init(userId: String, email: String, emailVerified: Bool) {
        self.userId = userId
        self.email = email
        self.emailVerified = emailVerified
    }
}

public protocol AccountAuthRepository: Sendable {
    func register(credentials: AccountCredentials) async throws -> AuthenticatedAccount
    func login(credentials: AccountCredentials) async throws -> AuthenticatedAccount
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
            let idToken = response["idToken"] as? String
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
            emailVerified: false
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
        guard let idToken = response["idToken"] as? String else {
            throw FirebaseRESTAuthError.invalidResponse
        }
        let account = try await lookup(idToken: idToken)
        guard account.emailVerified else {
            try await sendEmailVerification(idToken: idToken)
            throw FirebaseRESTAuthError.emailNotVerified
        }
        return account
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

    private func lookup(idToken: String) async throws -> AuthenticatedAccount {
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
            emailVerified: user["emailVerified"] as? Bool ?? false
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
    case server(code: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "認証サーバーから正しい応答を受信できませんでした。"
        case .emailNotVerified:
            return "メールアドレスの確認が完了していません。確認メールを再送しました。"
        case .profileSaveFailed:
            return "アカウントは作成されましたが、会員情報を保存できませんでした。"
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
