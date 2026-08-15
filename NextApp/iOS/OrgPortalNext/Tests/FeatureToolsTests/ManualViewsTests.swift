import DataLayer
import Model
import XCTest
@testable import FeatureTools

@MainActor
final class ManualViewsTests: XCTestCase {
    func testLoadPublishesRepositoryManuals() async {
        let expected = [sampleManual(id: "shared", communityId: nil)]
        let model = ManualFeatureModel(
            repository: FakeManualRepository(result: .success(expected))
        )

        await model.load(communityId: nil, idToken: nil)

        XCTAssertEqual(model.manuals, expected)
        XCTAssertTrue(model.hasLoaded)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
    }

    func testLoadFailureUsesSharedErrorMessage() async {
        let model = ManualFeatureModel(
            repository: FakeManualRepository(result: .failure(.requestFailed))
        )

        await model.load(communityId: "org-1", idToken: "token")

        XCTAssertEqual(model.manuals, [])
        XCTAssertEqual(model.errorMessage, "マニュアルを読み込めませんでした。")
        XCTAssertTrue(model.hasLoaded)
    }

    private func sampleManual(id: String, communityId: String?) -> Manual {
        Manual(
            id: id,
            communityId: communityId,
            title: "タイトル",
            body: "本文",
            sortOrder: 1,
            isPublished: true
        )
    }
}

private struct FakeManualRepository: ManualRepository {
    let result: Result<[Manual], ManualRepositoryError>

    func manuals(communityId: String?, idToken: String?) async throws -> [Manual] {
        try result.get()
    }
}
