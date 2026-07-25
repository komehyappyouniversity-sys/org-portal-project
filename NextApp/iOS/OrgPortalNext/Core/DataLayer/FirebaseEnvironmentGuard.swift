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

    public init(userId: String, email: String) {
        self.userId = userId
        self.email = email
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
