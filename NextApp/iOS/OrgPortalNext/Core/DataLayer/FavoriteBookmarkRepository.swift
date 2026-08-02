import Foundation
import Model

@MainActor
public protocol FavoriteBookmarkRepository {
    func fetchAll() async throws -> [FavoriteBookmark]
    func save(_ favorite: FavoriteBookmark) async throws
    func delete(id: UUID) async throws
}

@MainActor
public protocol PersonalVideoRepository {
    func fetchVideos() async throws -> [PersonalVideo]
    func fetchMemos(videoId: UUID) async throws -> [VideoMemo]
    func saveVideo(_ video: PersonalVideo) async throws
    func saveMemo(_ memo: VideoMemo) async throws
    func deleteVideo(id: UUID) async throws
    func deleteMemo(id: UUID) async throws
}

public protocol VideoQuestionRepository: Sendable {
    func myQuestions(communityId: String, memberUid: String, idToken: String) async throws -> [VideoQuestion]
    func createQuestion(
        communityId: String,
        videoId: String,
        videoType: String,
        videoTitle: String,
        memberUid: String,
        memberName: String,
        memberEmail: String,
        questionText: String,
        noteText: String,
        seconds: Int,
        idToken: String
    ) async throws
}

public struct FirebaseRESTVideoQuestionRepository: VideoQuestionRepository {
    private let projectId: String
    private let session: URLSession

    public init(
        projectId: String,
        session: URLSession = .shared
    ) {
        self.projectId = projectId
        self.session = session
    }

    public func myQuestions(
        communityId: String,
        memberUid: String,
        idToken: String
    ) async throws -> [VideoQuestion] {
        let result = try await request(
            path: "documents/organizations/\(communityId)/videoQuestions?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]

        return (result?["documents"] as? [[String: Any]] ?? [])
            .compactMap { parseQuestion($0) }
            .filter { $0.memberUid == memberUid }
            .sorted {
                ($0.updatedAt) > ($1.updatedAt)
            }
    }

    public func createQuestion(
        communityId: String,
        videoId: String,
        videoType: String,
        videoTitle: String,
        memberUid: String,
        memberName: String,
        memberEmail: String,
        questionText: String,
        noteText: String,
        seconds: Int,
        idToken: String
    ) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        _ = try await request(
            path: "documents/organizations/\(communityId)/videoQuestions",
            method: "POST",
            idToken: idToken,
            body: ["fields": [
                "organizationId": stringValue(communityId),
                "videoId": stringValue(videoId),
                "videoType": stringValue(videoType.ifEmpty(.personal_youtube)),
                "videoTitle": stringValue(videoTitle),
                "memberUid": stringValue(memberUid),
                "memberName": stringValue(memberName.isEmpty ? "会員" : memberName),
                "memberEmail": stringValue(memberEmail),
                "questionText": stringValue(questionText),
                "noteText": stringValue(noteText),
                "answerText": stringValue(""),
                "seconds": integerValue(max(0, seconds)),
                "status": stringValue("unanswered"),
                "createdAt": timestampValue(now),
                "updatedAt": timestampValue(now),
            ]]
        )
    }

    private func parseQuestion(_ document: [String: Any]) -> VideoQuestion? {
        guard let fields = document["fields"] as? [String: Any],
              let name = document["name"] as? String,
              let id = name.split(separator: "/").last.map(String.init)
        else { return nil }

        return VideoQuestion(
            id: id,
            organizationId: string(fields, "organizationId") ?? "",
            videoId: string(fields, "videoId") ?? "",
            videoType: string(fields, "videoType") ?? "personal_youtube",
            videoTitle: string(fields, "videoTitle") ?? "",
            memberUid: string(fields, "memberUid") ?? "",
            memberName: string(fields, "memberName") ?? "会員",
            memberEmail: string(fields, "memberEmail") ?? "",
            noteText: string(fields, "noteText") ?? "",
            questionText: string(fields, "questionText") ?? "",
            answerText: string(fields, "answerText") ?? "",
            status: VideoQuestionStatus.parse(string(fields, "status")),
            seconds: int(fields, "seconds"),
            createdAt: timestamp(fields, "createdAt") ?? .now,
            updatedAt: timestamp(fields, "updatedAt") ?? .now,
            answeredAt: timestamp(fields, "answeredAt")
        )
    }

    private func request(
        path: String,
        method: String,
        idToken: String? = nil,
        body: [String: Any]? = nil
    ) async throws -> Any {
        guard !projectId.isEmpty,
              let url = URL(
                string: "https://firestore.googleapis.com/v1/projects/\(projectId)"
                    + "/databases/(default)/\(path)"
              ) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idToken {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.cannotParseResponse)
        }
        if data.isEmpty { return [:] }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func string(_ fields: [String: Any], _ key: String) -> String? {
        (fields[key] as? [String: Any])?["stringValue"] as? String
    }

    private func int(_ fields: [String: Any], _ key: String) -> Int {
        if let integer = (fields[key] as? [String: Any])?["integerValue"] as? String {
            return Int(integer) ?? 0
        }
        if let integer = (fields[key] as? [String: Any])?["integerValue"] as? Int {
            return integer
        }
        if let integer = (fields[key] as? [String: Any])?["doubleValue"] as? Double {
            return Int(integer)
        }
        return 0
    }

    private func timestamp(_ fields: [String: Any], _ key: String) -> Date? {
        guard let raw = (fields[key] as? [String: Any])?["timestampValue"] as? String else {
            return nil
        }
        return ISO8601DateFormatter().date(from: raw)
    }

    private func stringValue(_ value: String) -> [String: Any] {
        ["stringValue": value]
    }

    private func integerValue(_ value: Int) -> [String: Any] {
        ["integerValue": "\(value)"]
    }

    private func timestampValue(_ value: String) -> [String: Any] {
        ["timestampValue": value]
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
