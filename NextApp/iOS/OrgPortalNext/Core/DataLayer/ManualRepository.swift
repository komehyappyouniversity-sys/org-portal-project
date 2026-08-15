import Foundation
import Model

public protocol ManualRepository: Sendable {
    func manuals(communityId: String?, idToken: String?) async throws -> [Manual]
}

public enum ManualRepositoryError: LocalizedError, Equatable, Sendable {
    case invalidConfiguration
    case requestFailed
    case invalidResponse
    case notAuthorized

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Firebaseの接続設定を確認してください。"
        case .requestFailed:
            "マニュアルを読み込めませんでした。"
        case .invalidResponse:
            "マニュアルのデータを読み取れませんでした。"
        case .notAuthorized:
            "このコミュニティのマニュアルを閲覧できません。"
        }
    }
}

public struct FirebaseRESTManualRepository: ManualRepository {
    private let baseURL: URL
    private let session: URLSession

    public init(
        projectId: String,
        baseURL: URL? = nil,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL ?? URL(
            string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)"
        )!
        self.session = session
    }

    public func manuals(communityId: String?, idToken: String?) async throws -> [Manual] {
        let normalizedCommunityId = communityId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedToken = idToken?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalizedCommunityId,
           !normalizedCommunityId.isEmpty,
           let normalizedToken,
           !normalizedToken.isEmpty {
            async let shared = fetchManuals(
                collectionId: "sharedManuals",
                parentPath: nil,
                communityId: nil,
                idToken: nil
            )
            async let community = fetchManuals(
                collectionId: "manuals",
                parentPath: "organizations/\(encodedPathComponent(normalizedCommunityId))",
                communityId: normalizedCommunityId,
                idToken: normalizedToken
            )
            return Self.sorted(try await shared + community)
        }

        return Self.sorted(
            try await fetchManuals(
                collectionId: "sharedManuals",
                parentPath: nil,
                communityId: nil,
                idToken: nil
            )
        )
    }

    private func fetchManuals(
        collectionId: String,
        parentPath: String?,
        communityId: String?,
        idToken: String?
    ) async throws -> [Manual] {
        let runQueryPath = if let parentPath {
            "documents/\(parentPath):runQuery"
        } else {
            "documents:runQuery"
        }
        let url = baseURL.appending(path: runQueryPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "structuredQuery": [
                "from": [["collectionId": collectionId]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "isPublished"],
                        "op": "EQUAL",
                        "value": ["booleanValue": true]
                    ]
                ]
            ]
        ])
        if let idToken {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw ManualRepositoryError.requestFailed
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ManualRepositoryError.requestFailed
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw ManualRepositoryError.notAuthorized
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ManualRepositoryError.requestFailed
        }
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ManualRepositoryError.invalidResponse
        }
        return rows.compactMap { row in
            guard let document = row["document"] as? [String: Any] else { return nil }
            return parseManualDocument(document, communityId: communityId)
        }.filter(\.isPublished)
    }

    private func encodedPathComponent(_ value: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func sorted(_ manuals: [Manual]) -> [Manual] {
        manuals.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            let leftScope = $0.communityId == nil ? 0 : 1
            let rightScope = $1.communityId == nil ? 0 : 1
            if leftScope != rightScope { return leftScope < rightScope }
            return $0.id < $1.id
        }
    }
}

func parseManualDocument(
    _ document: [String: Any],
    communityId: String?
) -> Manual? {
    guard let fields = document["fields"] as? [String: Any],
          let id = (document["name"] as? String)?.split(separator: "/").last.map(String.init),
          !id.isEmpty,
          let title = firestoreString(fields, key: "title"),
          let body = firestoreString(fields, key: "body"),
          let sortOrder = firestoreInt(fields, key: "sortOrder") else {
        return nil
    }
    return Manual(
        id: id,
        communityId: communityId,
        title: title,
        body: body,
        sortOrder: sortOrder,
        imageUrls: firestoreStringArray(fields, key: "imageUrls"),
        pdfUrl: firestoreNonEmptyString(fields, key: "pdfUrl"),
        externalUrl: firestoreNonEmptyString(fields, key: "externalUrl"),
        isPublished: firestoreBool(fields, key: "isPublished") ?? false
    )
}

private func firestoreString(_ fields: [String: Any], key: String) -> String? {
    (fields[key] as? [String: Any])?["stringValue"] as? String
}

private func firestoreNonEmptyString(_ fields: [String: Any], key: String) -> String? {
    firestoreString(fields, key: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        .nilIfEmpty
}

private func firestoreBool(_ fields: [String: Any], key: String) -> Bool? {
    (fields[key] as? [String: Any])?["booleanValue"] as? Bool
}

private func firestoreInt(_ fields: [String: Any], key: String) -> Int? {
    guard let value = fields[key] as? [String: Any] else { return nil }
    if let integer = value["integerValue"] as? String { return Int(integer) }
    if let integer = value["integerValue"] as? Int { return integer }
    if let double = value["doubleValue"] as? Double { return Int(double) }
    return nil
}

private func firestoreStringArray(_ fields: [String: Any], key: String) -> [String] {
    guard let value = fields[key] as? [String: Any],
          let arrayValue = value["arrayValue"] as? [String: Any],
          let values = arrayValue["values"] as? [[String: Any]] else {
        return []
    }
    return values.compactMap { ($0["stringValue"] as? String)?.nilIfEmpty }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
