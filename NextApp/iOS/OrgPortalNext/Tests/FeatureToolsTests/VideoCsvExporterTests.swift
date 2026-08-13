import Foundation
import XCTest
import Model
@testable import FeatureTools

final class VideoCsvExporterTests: XCTestCase {
    func testMemoCsvExporterUsesBomCrlfAndEscapesQuotes() throws {
        let video = DistributedVideo(
            id: "video-1",
            communityId: "community-1",
            videoTitle: "配信動画",
            vimeoUrl: "https://vimeo.com/abc",
        )
        let memo = VimeoVideoMemo(
            id: "memo-1",
            text: "quote\" and, comma",
            playbackSeconds: 12.5,
            createdAtMillis: 1_700_000_000_000,
            updatedAtMillis: 1_700_000_001_000,
        )

        let data = VideoMemoCsvExporter.data(for: [memo], video: video)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])

        let text = try XCTUnwrap(String(data: data.dropFirst(3), encoding: .utf8))
        let lines = text.components(separatedBy: "\r\n")
        let createdAt = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(lines[0], "schema_version=1")
        XCTAssertEqual(lines[1], "video_title,video_url,playback_seconds,memo,category_primary,category_secondary,created_at")
        XCTAssertEqual(
            lines[2],
            "\"配信動画\",\"https://vimeo.com/abc\",\"12.5\",\"quote\"\" and, comma\",\"\",\"\",\"\(createdAt)\"",
        )
        XCTAssertEqual(lines.last, "")
    }

    func testQuestionCsvExporterIncludesAnswerStatusAndMetadata() throws {
        let video = DistributedVideo(
            id: "video-2",
            communityId: "community-1",
            videoTitle: "質問動画",
            vimeoUrl: "https://vimeo.com/def",
        )
        let question = VideoQuestion(
            id: "question-1",
            communityId: "community-1",
            memberUid: "member-1",
            videoId: "video-2",
            videoTitle: "質問動画",
            playbackSeconds: 9,
            memoText: "メモ\"付き,",
            questionText: "質問\"内容\"",
            answerText: "",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        )

        let data = VideoQuestionCsvExporter.data(for: [question], video: video)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])

        let text = try XCTUnwrap(String(data: data.dropFirst(3), encoding: .utf8))
        let lines = text.components(separatedBy: "\r\n")
        let createdAt = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(lines[0], "schema_version=1")
        XCTAssertEqual(lines[1], "video_title,video_url,playback_seconds,question,answer,status,created_at,answered_at,memo")
        XCTAssertEqual(
            lines[2],
            "\"質問動画\",\"https://vimeo.com/def\",\"9.0\",\"質問\"\"内容\"\"\",\"\",\"unanswered\",\"\(createdAt)\",\"\",\"メモ\"\"付き,\"",
        )
        XCTAssertEqual(lines.last, "")
    }

    func testMemoCsvExporterWritesOnlyMetadataHeadersWhenEmpty() {
        let video = DistributedVideo(
            id: "video-empty",
            communityId: "community-1",
            videoTitle: "配信動画",
        )
        let data = VideoMemoCsvExporter.data(for: [], video: video)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])

        let lines = String(data: data.dropFirst(3), encoding: .utf8)!
            .components(separatedBy: "\r\n")

        XCTAssertEqual(lines, [
            "schema_version=1",
            "video_title,video_url,playback_seconds,memo,category_primary,category_secondary,created_at",
            "",
        ])
    }

    func testQuestionCsvExporterWritesOnlyMetadataHeadersWhenEmpty() {
        let video = DistributedVideo(
            id: "video-empty-question",
            communityId: "community-1",
            videoTitle: "質問動画",
        )
        let data = VideoQuestionCsvExporter.data(for: [], video: video)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])

        let lines = String(data: data.dropFirst(3), encoding: .utf8)!
            .components(separatedBy: "\r\n")

        XCTAssertEqual(lines, [
            "schema_version=1",
            "video_title,video_url,playback_seconds,question,answer,status,created_at,answered_at,memo",
            "",
        ])
    }
}
