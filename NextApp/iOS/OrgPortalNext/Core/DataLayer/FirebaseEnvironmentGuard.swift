import Foundation

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
