import Foundation
import XCTest
@testable import DataLayer

final class FirebaseRESTPostRepositoryAdminReplyTests: XCTestCase {
    func testSaveAdminReplySendsTrimmedPayloadAndMarksUnreadAsFalse() async throws {
        MockFirestoreProtocol.reset()
        let session = URLSession(configuration: mockSessionConfiguration())
        let repository = FirebaseRESTPostRepository(
            projectId: "test-project",
            session: session,
        )

        MockFirestoreProtocol.responses[requestKey(
            path: "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/memberPosts/post-1/replies/adminReply",
            method: "PATCH",
        )] = FakeResponse(
            statusCode: 200,
            body: ["writeTime": [:]],
        )
        MockFirestoreProtocol.responses[requestKey(
            path: "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/memberPosts/post-1",
            method: "PATCH",
            query: "updateMask.fieldPaths=adminReply&updateMask.fieldPaths=memberHasReadReply&updateMask.fieldPaths=updatedAt",
        )] = FakeResponse(
            statusCode: 200,
            body: ["writeTime": [:]],
        )

        _ = try await repository.saveAdminReply(
            communityId: "org-1",
            postId: "post-1",
            adminUserId: "admin-1",
            adminName: "運営者名",
            body: "  ありがとうございました  ",
            idToken: "id-token",
        )

        XCTAssertEqual(MockFirestoreProtocol.requests.count, 2)

        let replyRequest = try XCTUnwrap(MockFirestoreProtocol.requests.first)
        XCTAssertEqual(replyRequest.method, "PATCH")
        XCTAssertEqual(
            replyRequest.path,
            "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/memberPosts/post-1/replies/adminReply",
        )
        let replyPayload = try JSONSerialization.jsonObject(with: replyRequest.body) as? [String: Any]
        let replyFields = try XCTUnwrap(replyPayload?["fields"] as? [String: Any])
        let replyBody = try XCTUnwrap((replyFields["body"] as? [String: Any])?["stringValue"] as? String)
        let createdByName = try XCTUnwrap(
            (replyFields["createdByName"] as? [String: Any])?["stringValue"] as? String
        )
        XCTAssertEqual(replyBody, "ありがとうございました")
        XCTAssertEqual(createdByName, "運営者名")

        let syncRequest = try XCTUnwrap(
            MockFirestoreProtocol.requests.indices.contains(1)
                ? MockFirestoreProtocol.requests[1]
                : nil
        )
        XCTAssertEqual(
            syncRequest.query,
            "updateMask.fieldPaths=adminReply&updateMask.fieldPaths=memberHasReadReply&updateMask.fieldPaths=updatedAt",
        )
        let syncPayload = try JSONSerialization.jsonObject(with: syncRequest.body) as? [String: Any]
        let syncFields = try XCTUnwrap(syncPayload?["fields"] as? [String: Any])
        let syncBody = try XCTUnwrap((syncFields["adminReply"] as? [String: Any])?["stringValue"] as? String)
        let memberHasReadReply = try XCTUnwrap(
            (syncFields["memberHasReadReply"] as? [String: Any])?["booleanValue"] as? Bool
        )
        XCTAssertEqual(syncBody, "ありがとうございました")
        XCTAssertEqual(memberHasReadReply, false)
    }

    func testSaveAdminReplyUsesDefaultAdminName() async throws {
        MockFirestoreProtocol.reset()
        let session = URLSession(configuration: mockSessionConfiguration())
        let repository = FirebaseRESTPostRepository(
            projectId: "test-project",
            session: session,
        )

        MockFirestoreProtocol.responses[requestKey(
            path: "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/memberPosts/post-1/replies/adminReply",
            method: "PATCH",
        )] = FakeResponse(
            statusCode: 200,
            body: ["writeTime": [:]],
        )
        MockFirestoreProtocol.responses[requestKey(
            path: "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/memberPosts/post-1",
            method: "PATCH",
            query: "updateMask.fieldPaths=adminReply&updateMask.fieldPaths=memberHasReadReply&updateMask.fieldPaths=updatedAt",
        )] = FakeResponse(
            statusCode: 200,
            body: ["writeTime": [:]],
        )

        _ = try await repository.saveAdminReply(
            communityId: "org-1",
            postId: "post-1",
            adminUserId: "admin-1",
            adminName: nil,
            body: "返信",
            idToken: "id-token",
        )

        let replyRequest = try XCTUnwrap(MockFirestoreProtocol.requests.first)
        let replyPayload = try JSONSerialization.jsonObject(with: replyRequest.body) as? [String: Any]
        let replyFields = try XCTUnwrap(replyPayload?["fields"] as? [String: Any])
        let createdByName = try XCTUnwrap(
            (replyFields["createdByName"] as? [String: Any])?["stringValue"] as? String
        )
        XCTAssertEqual(createdByName, "管理者")
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

private func requestKey(path: String, method: String, query: String? = nil) -> RequestKey {
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
        let key = requestKey(path: requestPath, method: requestMethod, query: requestQuery)
        let response = Self.responses[key] ?? Self.responses[requestKey(path: requestPath, method: requestMethod)]
            ?? FakeResponse(statusCode: 500, body: ["error": "not found"])

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
