import XCTest
@testable import Model

final class SnsCustomLinkTests: XCTestCase {
    func testValidationTrimsValues() throws {
        let link = try SnsCustomLink(
            title: "  公式ブログ  ",
            url: "  https://example.com/post  "
        ).validated()

        XCTAssertEqual(link.title, "公式ブログ")
        XCTAssertEqual(link.url, "https://example.com/post")
    }

    func testValidationRejectsMissingTitleAndUnsafeURL() {
        XCTAssertThrowsError(
            try SnsCustomLink(title: " ", url: "https://example.com").validated()
        ) { error in
            XCTAssertEqual(error as? SnsCustomLinkValidationError, .titleRequired)
        }

        XCTAssertThrowsError(
            try SnsCustomLink(title: "危険", url: "javascript:alert(1)").validated()
        ) { error in
            XCTAssertEqual(error as? SnsCustomLinkValidationError, .invalidURL)
        }
    }
}
