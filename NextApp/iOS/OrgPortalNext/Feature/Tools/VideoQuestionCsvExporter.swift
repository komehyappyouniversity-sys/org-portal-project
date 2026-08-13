import Foundation
import Model

public enum VideoQuestionCsvExporter {
    public static func data(for questions: [VideoQuestion], video: DistributedVideo) -> Data {
        let formatter = ISO8601DateFormatter()
        let lines = [
            "schema_version=1",
            "video_title,video_url,playback_seconds,question,answer,status,created_at,answered_at,memo",
        ] + questions.map { question in
            [
                video.title,
                exportedVideoUrl(video),
                String(question.playbackSeconds),
                question.questionText,
                question.answerText,
                question.answerText.isEmpty ? "unanswered" : "answered",
                question.createdAt.map { formatter.string(from: $0) } ?? "",
                "",
                question.memoText,
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
