import Foundation
import Model

public protocol PostRepository: Sendable {
    func publicPosts() async throws -> [PublicPost]
    func memberPosts(
        communityId: String,
        userId: String,
        idToken: String
    ) async throws -> [MemberPost]
    func replies(
        communityId: String,
        postId: String,
        idToken: String
    ) async throws -> [AdminReply]
    func createMemberPost(
        communityId: String,
        userId: String,
        authorName: String,
        title: String,
        body: String,
        idToken: String
    ) async throws
    func updateMemberPost(
        communityId: String,
        postId: String,
        title: String,
        body: String,
        idToken: String
    ) async throws
    func deleteMemberPost(
        communityId: String,
        postId: String,
        idToken: String
    ) async throws
    func markReplyRead(
        communityId: String,
        postId: String,
        idToken: String
    ) async throws
}

public struct FirebaseRESTPostRepository: PostRepository {
    private let projectId: String
    private let session: URLSession

    public init(projectId: String, session: URLSession = .shared) {
        self.projectId = projectId
        self.session = session
    }

    public func publicPosts() async throws -> [PublicPost] {
        let rows = try await request(
            path: "documents:runQuery",
            method: "POST",
            body: [
                "structuredQuery": [
                    "from": [["collectionId": "publicPosts", "allDescendants": true]],
                    "where": [
                        "fieldFilter": [
                            "field": ["fieldPath": "isPublic"],
                            "op": "EQUAL",
                            "value": boolValue(true)
                        ]
                    ]
                ]
            ]
        ) as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let document = row["document"] as? [String: Any] else { return nil }
            return parsePublicPost(document)
        }
        .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    public func memberPosts(
        communityId: String,
        userId: String,
        idToken: String
    ) async throws -> [MemberPost] {
        let result = try await request(
            path: "documents/organizations/\(communityId)/memberPosts?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        return (result?["documents"] as? [[String: Any]] ?? [])
            .compactMap { parseMemberPost($0, communityId: communityId) }
            .filter { $0.authorUserId == userId }
            .sorted {
                ($0.updatedAt ?? $0.createdAt ?? .distantPast)
                    > ($1.updatedAt ?? $1.createdAt ?? .distantPast)
            }
    }

    public func replies(
        communityId: String,
        postId: String,
        idToken: String
    ) async throws -> [AdminReply] {
        let result = try await request(
            path: "documents/organizations/\(communityId)/memberPosts/\(postId)"
                + "/replies?pageSize=1000",
            method: "GET",
            idToken: idToken
        ) as? [String: Any]
        return (result?["documents"] as? [[String: Any]] ?? []).compactMap {
            guard let fields = $0["fields"] as? [String: Any],
                  let name = $0["name"] as? String,
                  let id = name.split(separator: "/").last.map(String.init),
                  let body = string(fields, "body") else { return nil }
            return AdminReply(
                id: id,
                postId: postId,
                adminUserId: string(fields, "createdBy") ?? "",
                adminName: string(fields, "createdByName"),
                body: body,
                createdAt: timestamp(fields, "createdAt")
            )
        }
        .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    public func createMemberPost(
        communityId: String,
        userId: String,
        authorName: String,
        title: String,
        body: String,
        idToken: String
    ) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        _ = try await request(
            path: "documents/organizations/\(communityId)/memberPosts",
            method: "POST",
            idToken: idToken,
            body: ["fields": [
                "organizationId": stringValue(communityId),
                "memberUid": stringValue(userId),
                "memberName": stringValue(authorName),
                "title": stringValue(title),
                "body": stringValue(body),
                "imageURLs": arrayValue([]),
                "status": stringValue("submitted"),
                "adminReply": stringValue(""),
                "memberHasReadReply": boolValue(true),
                "createdAt": timestampValue(now),
                "updatedAt": timestampValue(now)
            ]]
        )
    }

    public func updateMemberPost(
        communityId: String,
        postId: String,
        title: String,
        body: String,
        idToken: String
    ) async throws {
        _ = try await request(
            path: "documents/organizations/\(communityId)/memberPosts/\(postId)"
                + "?updateMask.fieldPaths=title&updateMask.fieldPaths=body"
                + "&updateMask.fieldPaths=updatedAt",
            method: "PATCH",
            idToken: idToken,
            body: ["fields": [
                "title": stringValue(title),
                "body": stringValue(body),
                "updatedAt": timestampValue(ISO8601DateFormatter().string(from: Date()))
            ]]
        )
    }

    public func deleteMemberPost(
        communityId: String,
        postId: String,
        idToken: String
    ) async throws {
        _ = try await request(
            path: "documents/organizations/\(communityId)/memberPosts/\(postId)",
            method: "DELETE",
            idToken: idToken
        )
    }

    public func markReplyRead(
        communityId: String,
        postId: String,
        idToken: String
    ) async throws {
        _ = try await request(
            path: "documents/organizations/\(communityId)/memberPosts/\(postId)"
                + "?updateMask.fieldPaths=memberHasReadReply",
            method: "PATCH",
            idToken: idToken,
            body: ["fields": ["memberHasReadReply": boolValue(true)]]
        )
    }

    private func parseMemberPost(
        _ document: [String: Any],
        communityId: String
    ) -> MemberPost? {
        guard let fields = document["fields"] as? [String: Any],
              let name = document["name"] as? String,
              let id = name.split(separator: "/").last.map(String.init) else { return nil }
        let imageURLs = stringArray(fields, "imageURLs")
        var attachments = imageURLs.compactMap { rawURL -> PostAttachment? in
            guard let url = URL(string: rawURL) else { return nil }
            return PostAttachment(type: "image", name: "画像", url: url)
        }
        if let rawPDF = string(fields, "pdfURL"), let url = URL(string: rawPDF) {
            attachments.append(PostAttachment(type: "pdf", name: "PDF", url: url))
        }
        return MemberPost(
            id: id,
            communityId: string(fields, "organizationId") ?? communityId,
            authorUserId: string(fields, "memberUid")
                ?? string(fields, "authorUserId") ?? "",
            authorName: string(fields, "memberName")
                ?? string(fields, "authorName") ?? "会員",
            title: string(fields, "title") ?? "",
            body: string(fields, "body") ?? "",
            attachments: attachments,
            status: string(fields, "status") ?? "submitted",
            legacyAdminReply: string(fields, "adminReply"),
            memberHasReadReply: bool(fields, "memberHasReadReply") ?? true,
            createdAt: timestamp(fields, "createdAt"),
            updatedAt: timestamp(fields, "updatedAt")
        )
    }

    private func parsePublicPost(_ document: [String: Any]) -> PublicPost? {
        guard let fields = document["fields"] as? [String: Any],
              bool(fields, "isPublic") == true,
              let name = document["name"] as? String,
              let id = name.split(separator: "/").last.map(String.init) else { return nil }
        return PublicPost(
            id: id,
            authorUserId: string(fields, "authorUserId")
                ?? string(fields, "memberUid") ?? "",
            authorName: string(fields, "authorName")
                ?? string(fields, "memberName") ?? "会員",
            title: string(fields, "title") ?? "",
            categoryId: string(fields, "categoryId") ?? string(fields, "category"),
            body: string(fields, "body") ?? "",
            attachments: attachments(fields),
            createdAt: timestamp(fields, "createdAt")
        )
    }

    private func attachments(_ fields: [String: Any]) -> [PostAttachment] {
        guard let value = fields["attachments"] as? [String: Any],
              let array = value["arrayValue"] as? [String: Any],
              let values = array["values"] as? [[String: Any]] else { return [] }
        return values.compactMap { value in
            guard let map = value["mapValue"] as? [String: Any],
                  let attachmentFields = map["fields"] as? [String: Any],
                  let rawURL = string(attachmentFields, "url"),
                  let url = URL(string: rawURL) else { return nil }
            return PostAttachment(
                type: string(attachmentFields, "type") ?? "url",
                name: string(attachmentFields, "name") ?? "添付ファイル",
                url: url
            )
        }
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
        if let idToken {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.cannotParseResponse)
        }
        if data.isEmpty { return [:] }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func string(_ fields: [String: Any], _ key: String) -> String? {
        (fields[key] as? [String: Any])?["stringValue"] as? String
    }

    private func bool(_ fields: [String: Any], _ key: String) -> Bool? {
        (fields[key] as? [String: Any])?["booleanValue"] as? Bool
    }

    private func stringArray(_ fields: [String: Any], _ key: String) -> [String] {
        guard let value = fields[key] as? [String: Any],
              let array = value["arrayValue"] as? [String: Any],
              let values = array["values"] as? [[String: Any]] else { return [] }
        return values.compactMap { $0["stringValue"] as? String }
    }

    private func timestamp(_ fields: [String: Any], _ key: String) -> Date? {
        guard let value = (fields[key] as? [String: Any])?["timestampValue"] as? String
        else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private func stringValue(_ value: String) -> [String: Any] {
        ["stringValue": value]
    }

    private func boolValue(_ value: Bool) -> [String: Any] {
        ["booleanValue": value]
    }

    private func timestampValue(_ value: String) -> [String: Any] {
        ["timestampValue": value]
    }

    private func arrayValue(_ values: [[String: Any]]) -> [String: Any] {
        ["arrayValue": ["values": values]]
    }
}
