import Foundation
import Model
import SwiftData

@Model
public final class VideoRepeatSettingRecord {
    @Attribute(.unique) public var videoId: String
    public var userId: String
    public var isEnabled: Bool
    public var mode: String
    public var repeatStartSeconds: Double?
    public var repeatEndSeconds: Double?

    public init(setting: VideoRepeatSetting) {
        videoId = setting.videoId
        userId = setting.userId
        isEnabled = setting.isEnabled
        mode = setting.mode.rawValue
        repeatStartSeconds = setting.repeatStartSeconds
        repeatEndSeconds = setting.repeatEndSeconds
    }

    public func update(from setting: VideoRepeatSetting) {
        userId = setting.userId
        isEnabled = setting.isEnabled
        mode = setting.mode.rawValue
        repeatStartSeconds = setting.repeatStartSeconds
        repeatEndSeconds = setting.repeatEndSeconds
    }

    public func domainModel() -> VideoRepeatSetting {
        VideoRepeatSetting(
            userId: userId,
            videoId: videoId,
            isEnabled: isEnabled,
            mode: VideoRepeatMode(rawValue: mode) ?? .full,
            repeatStartSeconds: repeatStartSeconds,
            repeatEndSeconds: repeatEndSeconds
        )
    }
}

@MainActor
public final class SwiftDataVideoRepeatSettingRepository: VideoRepeatSettingRepository {
    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        context = modelContainer.mainContext
    }

    public func setting(videoId: String) async throws -> VideoRepeatSetting? {
        let requestedVideoId = videoId
        let descriptor = FetchDescriptor<VideoRepeatSettingRecord>(
            predicate: #Predicate { $0.videoId == requestedVideoId }
        )
        return try context.fetch(descriptor).first?.domainModel()
    }

    public func save(_ setting: VideoRepeatSetting) async throws {
        let videoId = setting.videoId
        let descriptor = FetchDescriptor<VideoRepeatSettingRecord>(
            predicate: #Predicate { $0.videoId == videoId }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: setting)
        } else {
            context.insert(VideoRepeatSettingRecord(setting: setting))
        }
        try context.save()
    }
}
