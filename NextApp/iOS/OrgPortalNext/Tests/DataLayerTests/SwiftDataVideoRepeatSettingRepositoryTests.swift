import Model
import SwiftData
import XCTest
@testable import DataLayer

@MainActor
final class SwiftDataVideoRepeatSettingRepositoryTests: XCTestCase {
    func testSaveUpdateAndFetchByVideoId() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: VideoRepeatSettingRecord.self,
            configurations: configuration
        )
        let repository = SwiftDataVideoRepeatSettingRepository(modelContainer: container)

        let initialSetting = try await repository.setting(videoId: "video-1")
        XCTAssertNil(initialSetting)

        try await repository.save(
            VideoRepeatSetting(
                userId: "guest-local",
                videoId: "video-1",
                isEnabled: true
            )
        )
        try await repository.save(
            VideoRepeatSetting(
                userId: "member-1",
                videoId: "video-2",
                isEnabled: true
            )
        )

        let saved = try await repository.setting(videoId: "video-1")
        XCTAssertEqual(saved?.userId, "guest-local")
        XCTAssertEqual(saved?.isEnabled, true)
        XCTAssertEqual(saved?.mode, .full)
        XCTAssertNil(saved?.repeatStartSeconds)
        XCTAssertNil(saved?.repeatEndSeconds)

        try await repository.save(
            VideoRepeatSetting(
                userId: "member-1",
                videoId: "video-1",
                isEnabled: false
            )
        )

        let updated = try await repository.setting(videoId: "video-1")
        let otherVideo = try await repository.setting(videoId: "video-2")
        XCTAssertEqual(updated?.userId, "member-1")
        XCTAssertEqual(updated?.isEnabled, false)
        XCTAssertEqual(otherVideo?.isEnabled, true)
    }
}
