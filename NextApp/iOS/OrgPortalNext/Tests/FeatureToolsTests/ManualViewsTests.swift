import XCTest
@testable import FeatureTools

final class ManualViewsTests: XCTestCase {
    func testManualCatalogHasExpectedOrder() {
        let expectedIds = ["quick-start", "tools-start", "sns-favorites", "troubleshoot"]
        XCTAssertEqual(expectedIds, availableManuals.map(\.id))
    }

    func testManualCatalogHasRequiredContent() {
        XCTAssertEqual(4, availableManuals.count)
        for manual in availableManuals {
            XCTAssertFalse(manual.id.isEmpty)
            XCTAssertFalse(manual.title.isEmpty)
            XCTAssertFalse(manual.description.isEmpty)
            XCTAssertFalse(manual.detail.isEmpty)
        }
    }
}
