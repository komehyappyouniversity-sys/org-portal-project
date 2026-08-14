import Foundation

public enum VideoRepeatMode: String, Codable, CaseIterable, Sendable {
    case full
}

public struct VideoRepeatSetting: Codable, Equatable, Sendable {
    public var userId: String
    public var videoId: String
    public var isEnabled: Bool
    public var mode: VideoRepeatMode
    public var repeatStartSeconds: Double?
    public var repeatEndSeconds: Double?

    public init(
        userId: String,
        videoId: String,
        isEnabled: Bool,
        mode: VideoRepeatMode = .full,
        repeatStartSeconds: Double? = nil,
        repeatEndSeconds: Double? = nil
    ) {
        self.userId = userId
        self.videoId = videoId
        self.isEnabled = isEnabled
        self.mode = mode
        self.repeatStartSeconds = repeatStartSeconds
        self.repeatEndSeconds = repeatEndSeconds
    }
}
