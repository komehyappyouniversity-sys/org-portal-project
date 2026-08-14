import Foundation
import Model
import XCTest
@testable import DataLayer

final class FirebaseRESTCommunityRepositoryVideoQuestionTests: XCTestCase {
    func testSaveVideoQuestionUsesClientRequestIdAsIdempotentDocumentId() async throws {
        MockFirestoreProtocol.reset()
        let session = URLSession(configuration: mockSessionConfiguration())
        let repository = FirebaseRESTCommunityRepository(projectId: "test-project", session: session)
        let path = "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions"
        let request = requestKey(
            path: path,
            method: "POST",
            query: "documentId=request-123"
        )
        let video = DistributedVideo(
            id: "video-1",
            communityId: "org-1",
            videoTitle: "動画",
            description: "",
            embedHtml: "",
            videoUrl: "",
            vimeoUrl: "",
            providerVideoId: "",
            videoType: "distributed_vimeo",
            thumbnailUrl: "",
            isPremium: false,
            createdAt: nil,
            updatedAt: nil,
            isPublished: true,
            isMembersOnly: false,
            sortOrder: 0
        )

        for statusCode in [200, 409] {
            MockFirestoreProtocol.responses[request] = FakeResponse(
                statusCode: statusCode,
                body: ["writeTime": [:]]
            )
            try await repository.saveVideoQuestion(
                communityId: "org-1",
                memberUid: "member",
                video: video,
                memoText: "メモ",
                questionText: "質問",
                playbackSeconds: 10,
                clientRequestId: "request-123",
                idToken: "id-token"
            )
        }

        XCTAssertEqual(MockFirestoreProtocol.requests.map(\.path), [path, path])
        XCTAssertEqual(MockFirestoreProtocol.requests.map(\.method), ["POST", "POST"])
        XCTAssertEqual(
            MockFirestoreProtocol.requests.map(\.query),
            ["documentId=request-123", "documentId=request-123"]
        )
        let payload = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: MockFirestoreProtocol.requests[0].body) as? [String: Any]
        )
        let fields = try XCTUnwrap(payload["fields"] as? [String: Any])
        XCTAssertEqual(
            (fields["clientRequestId"] as? [String: Any])?["stringValue"] as? String,
            "request-123"
        )
        XCTAssertEqual(
            (fields["syncStatus"] as? [String: Any])?["stringValue"] as? String,
            "synced"
        )
    }

    func testAdminVideoQuestionsLoadsAllQuestionsSortedByCreatedAt() async throws {
        MockFirestoreProtocol.reset()
        let session = URLSession(
            configuration: mockSessionConfiguration()
        )
        let repository = FirebaseRESTCommunityRepository(
            projectId: "test-project",
            session: session,
        )

        MockFirestoreProtocol.responses[requestKey(
            path: "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions",
            method: "GET",
            query: "pageSize=1000",
        )] = FakeResponse(
            statusCode: 200,
            body: [
                "documents": [
                    [
                        "name": "projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions/q-new",
                        "fields": [
                            "questionText": ["stringValue": "新しい質問"],
                            "videoTitle": ["stringValue": "動画A"],
                            "memoText": ["stringValue": "メモ"],
                            "answerText": ["stringValue": ""],
                            "memberUid": ["stringValue": "member-a"],
                            "videoId": ["stringValue": "video-a"],
                            "playbackSeconds": ["doubleValue": 10.0],
                            "createdAt": ["timestampValue": "2026-08-13T12:00:00Z"],
                        ],
                    ],
                    [
                        "name": "projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions/q-old",
                        "fields": [
                            "questionText": ["stringValue": "古い質問"],
                            "videoTitle": ["stringValue": "動画B"],
                            "answerText": ["stringValue": "既に回答"],
                            "memberUid": ["stringValue": "member-b"],
                            "videoId": ["stringValue": "video-b"],
                            "playbackSeconds": ["doubleValue": 20.0],
                            "createdAt": ["timestampValue": "2026-08-12T09:00:00Z"],
                            "answeredAt": ["timestampValue": "2026-08-12T10:00:00Z"],
                        ],
                    ],
                ],
            ],
        )

        let result = try await repository.adminVideoQuestions(
            communityId: "org-1",
            idToken: "id-token",
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, "q-new")
        XCTAssertEqual(result[1].id, "q-old")
        XCTAssertEqual(result[0].videoTitle, "動画A")
        XCTAssertEqual(result[0].memberUid, "member-a")
        XCTAssertEqual(result[0].memoText, "メモ")
        XCTAssertEqual(result[0].answerText, "")
        XCTAssertNil(result[0].answeredAt)
        XCTAssertEqual(
            result[1].answeredAt,
            ISO8601DateFormatter().date(from: "2026-08-12T10:00:00Z")
        )
    }

    func testAnswerVideoQuestionSendsTrimmedPayload() async throws {
        MockFirestoreProtocol.reset()
        let session = URLSession(
            configuration: mockSessionConfiguration()
        )
        let repository = FirebaseRESTCommunityRepository(
            projectId: "test-project",
            session: session,
        )

        MockFirestoreProtocol.responses[requestKey(
            path: "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions/q-new",
            method: "PATCH",
        )] = FakeResponse(
            statusCode: 200,
            body: ["writeTime": [:]],
        )

        _ = try await repository.answerVideoQuestion(
            communityId: "org-1",
            questionId: "q-new",
            answerText: "  回答します  ",
            idToken: "id-token",
        )

        XCTAssertEqual(MockFirestoreProtocol.requests.count, 1)
        let request = try XCTUnwrap(MockFirestoreProtocol.requests.first)
        XCTAssertEqual(request.method, "PATCH")
        XCTAssertEqual(
            request.path,
            "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions/q-new"
        )

        let payload = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: request.body) as? [String: Any]
        )
        let fields = try XCTUnwrap(payload["fields"] as? [String: Any])
        let answerText = try XCTUnwrap((fields["answerText"] as? [String: Any])?["stringValue"] as? String)
        let updatedAt = (fields["updatedAt"] as? [String: Any])?["timestampValue"] as? String
        let answeredAt = (fields["answeredAt"] as? [String: Any])?["timestampValue"] as? String

        XCTAssertEqual(answerText, "回答します")
        XCTAssertNotNil(updatedAt)
        XCTAssertNotNil(answeredAt)
        XCTAssertEqual(answeredAt, updatedAt)
    }

    private func mockSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockFirestoreProtocol.self]
        return configuration
    }
}

private struct RequestKey: Hashable {
    let path: String
    let method: String
    let query: String?

    init(path: String, method: String, query: String? = nil) {
        self.path = path
        self.method = method
        self.query = query
    }
}

private func requestKey(
    path: String,
    method: String,
    query: String? = nil,
) -> RequestKey {
    RequestKey(path: path, method: method, query: query)
}

private struct FakeResponse {
    let statusCode: Int
    let body: [String: Any]
}

private struct RecordedRequest {
    let method: String
    let path: String
    let query: String?
    let body: Data
}

private final class MockFirestoreProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [RequestKey: FakeResponse] = [:]
    nonisolated(unsafe) static var requests: [RecordedRequest] = []

    static func reset() {
        responses = [:]
        requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let requestMethod = request.httpMethod ?? "GET"
        let requestPath = request.url?.path ?? ""
        let requestQuery = request.url?.query
        let key = requestKey(
            path: requestPath,
            method: requestMethod,
            query: requestQuery,
        )

        let response = Self.responses[key]
            ?? Self.responses[requestKey(path: requestPath, method: requestMethod)]
            ?? FakeResponse(statusCode: 500, body: ["error": "not found"])

        // URLSession.data(for:) converts httpBody into httpBodyStream before handing the
        // request to a custom URLProtocol, so fall back to draining the stream.
        let requestBody = request.httpBody ?? Self.readBody(from: request.httpBodyStream)
        Self.requests.append(
            RecordedRequest(
                method: requestMethod,
                path: requestPath,
                query: requestQuery,
                body: requestBody,
            )
        )

        guard let url = request.url else {
            let error = NSError(domain: "MockFirestoreProtocol", code: -1)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let responseData = try! JSONSerialization.data(withJSONObject: response.body)
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"],
        )!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func readBody(from stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            if bytesRead <= 0 { break }
            data.append(buffer, count: bytesRead)
        }
        return data
    }

    override func stopLoading() {
        // No-op.
    }
}
