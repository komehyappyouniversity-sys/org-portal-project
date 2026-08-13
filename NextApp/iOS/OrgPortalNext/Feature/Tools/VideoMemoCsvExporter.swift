import Foundation
import Model

public enum VideoMemoCsvExporter {
    public static func data(for memos: [VimeoVideoMemo], video: DistributedVideo) -> Data {
        let formatter = ISO8601DateFormatter()
        let lines = [
            "schema_version=1",
            "video_title,video_url,playback_seconds,memo,category_primary,category_secondary,created_at",
        ] + memos.map { memo in
            [
                video.title,
                exportedVideoUrl(video),
                String(memo.playbackSeconds),
                memo.text,
                video.primaryCategoryId,
                video.secondaryCategoryId,
                memo.createdAtMillis > 0
                    ? formatter.string(from: Date(timeIntervalSince1970: TimeInterval(memo.createdAtMillis) / 1000))
                    : "",
            ]
            .map(escape)
            .joined(separator: ",")
        }

        let csv = lines.joined(separator: "\r\n") + "\r\n"
        return Data([0xEF, 0xBB, 0xBF]) + Data(csv.utf8)
    }

    private static func exportedVideoUrl(_ video: DistributedVideo) -> String {
        if !video.vimeoUrl.isEmpty { return video.vimeoUrl }
        return video.videoUrl
    }

    private static func escape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
