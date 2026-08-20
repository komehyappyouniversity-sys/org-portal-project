import XCTest
@testable import DataLayer

final class FirebaseEnvironmentGuardTests: XCTestCase {
    func testDebugBuildRejectsProductionProject() {
        let configuration = FirebaseRuntimeConfiguration(
            environment: .production,
            projectId: "ictnagaoka-member",
            isDebugBuild: true,
            productionProjectId: "ictnagaoka-member"
        )

        XCTAssertThrowsError(try configuration.validate()) { error in
            XCTAssertEqual(
                error as? FirebaseEnvironmentError,
                .debugBuildReferencesProduction
            )
        }
    }

    func testDebugBuildAcceptsDemoProject() throws {
        let configuration = FirebaseRuntimeConfiguration(
            environment: .emulator,
            projectId: "demo-org-portal-next",
            isDebugBuild: true,
            productionProjectId: "ictnagaoka-member"
        )

        XCTAssertNoThrow(try configuration.validate())
    }

    func testDebugDevelopmentBuildRejectsUnexpectedProject() {
        let configuration = FirebaseRuntimeConfiguration(
            environment: .development,
            projectId: "unexpected-project",
            isDebugBuild: true,
            productionProjectId: "ictnagaoka-member"
        )

        XCTAssertThrowsError(try configuration.validate()) { error in
            XCTAssertEqual(
                error as? FirebaseEnvironmentError,
                .debugBuildReferencesUnexpectedProject
            )
        }
    }
}
