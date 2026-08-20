import Foundation
import Model
import XCTest
@testable import DataLayer

final class FirebaseRESTManualRepositoryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ManualURLProtocol.reset()
    }

    func testGuestLoadsOnlyPublishedSharedManuals() async throws {
        ManualURLProtocol.sharedResponse = rows(
            document(id: "published", title: "公開", sortOrder: 2, isPublished: true),
            document(id: "draft", title: "下書き", sortOrder: 1, isPublished: false)
        )
        let repository = makeRepository()

        let manuals = try await repository.manuals(communityId: nil, idToken: nil)

        XCTAssertEqual(manuals.map(\.id), ["published"])
        XCTAssertNil(manuals.first?.communityId)
        XCTAssertEqual(ManualURLProtocol.requests.count, 1)
        XCTAssertNil(ManualURLProtocol.requests.first?.authorization)
        assertPublishedQuery(ManualURLProtocol.requests[0].body)
    }

    func testMemberMergesCollectionsInStableSortOrder() async throws {
        ManualURLProtocol.sharedResponse = rows(
            document(id: "z-shared", title: "共通Z", sortOrder: 10, isPublished: true),
            document(id: "a-shared", title: "共通A", sortOrder: 10, isPublished: true)
        )
        ManualURLProtocol.communityResponse = rows(
            document(id: "community", title: "専用", sortOrder: 5, isPublished: true),
            document(id: "same", title: "専用同順", sortOrder: 10, isPublished: true)
        )
        let repository = makeRepository()

        let manuals = try await repository.manuals(
            communityId: "org-1",
            idToken: "member-token"
        )

        XCTAssertEqual(manuals.map(\.id), ["community", "a-shared", "z-shared", "same"])
        XCTAssertEqual(manuals.map(\.communityId), ["org-1", nil, nil, "org-1"])
        XCTAssertEqual(ManualURLProtocol.requests.count, 2)
        let communityRequest = try XCTUnwrap(
            ManualURLProtocol.requests.first { $0.path.contains("organizations/org-1") }
        )
        XCTAssertEqual(communityRequest.authorization, "Bearer member-token")
        let sharedRequest = try XCTUnwrap(
            ManualURLProtocol.requests.first { !$0.path.contains("organizations/org-1") }
        )
        XCTAssertNil(sharedRequest.authorization)
        ManualURLProtocol.requests.forEach { assertPublishedQuery($0.body) }
    }

    func testParserMapsAllDomainFields() throws {
        let parsed = try XCTUnwrap(
            parseManualDocument(
                document(
                    id: "guide",
                    title: "ガイド",
                    sortOrder: 3,
                    isPublished: true,
                    body: "本文",
                    imageUrls: ["https://example.com/1.jpg", "https://example.com/2.jpg"],
                    pdfUrl: "https://example.com/guide.pdf",
                    externalUrl: "https://example.com/help"
                ),
                communityId: "org-1"
            )
        )

        XCTAssertEqual(parsed.id, "guide")
        XCTAssertEqual(parsed.communityId, "org-1")
        XCTAssertEqual(parsed.body, "本文")
        XCTAssertEqual(parsed.sortOrder, 3)
        XCTAssertEqual(parsed.imageUrls.count, 2)
        XCTAssertEqual(parsed.pdfUrl, "https://example.com/guide.pdf")
        XCTAssertEqual(parsed.externalUrl, "https://example.com/help")
        XCTAssertTrue(parsed.isPublished)
    }

    private func makeRepository() -> FirebaseRESTManualRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ManualURLProtocol.self]
        return FirebaseRESTManualRepository(
            projectId: "test-project",
            session: URLSession(configuration: configuration)
        )
    }

    private func assertPublishedQuery(_ data: Data) {
        let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let structuredQuery = payload?["structuredQuery"] as? [String: Any]
        let whereValue = structuredQuery?["where"] as? [String: Any]
        let filter = whereValue?["fieldFilter"] as? [String: Any]
        let field = filter?["field"] as? [String: Any]
        let value = filter?["value"] as? [String: Any]
        XCTAssertEqual(field?["fieldPath"] as? String, "isPublished")
        XCTAssertEqual(filter?["op"] as? String, "EQUAL")
        XCTAssertEqual(value?["booleanValue"] as? Bool, true)
    }
}

private struct ManualRecordedRequest {
    let path: String
    let authorization: String?
    let body: Data
}

private final class ManualURLProtocol: URLProtocol {
    nonisolated(unsafe) static var sharedResponse = Data("[]".utf8)
    nonisolated(unsafe) static var communityResponse = Data("[]".utf8)
    private nonisolated(unsafe) static var recordedRequests: [ManualRecordedRequest] = []
    private static let requestLock = NSLock()

    static var requests: [ManualRecordedRequest] {
        requestLock.lock()
        defer { requestLock.unlock() }
        return recordedRequests
    }

    static func reset() {
        sharedResponse = Data("[]".utf8)
        communityResponse = Data("[]".utf8)
        requestLock.lock()
        recordedRequests = []
        requestLock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let body = request.httpBody ?? Self.readBody(from: request.httpBodyStream)
        Self.requestLock.lock()
        Self.recordedRequests.append(
            ManualRecordedRequest(
                path: path,
                authorization: request.value(forHTTPHeaderField: "Authorization"),
                body: body
            )
        )
        Self.requestLock.unlock()
        let data = path.contains("organizations/org-1")
            ? Self.communityResponse
            : Self.sharedResponse
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func readBody(from stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    override func stopLoading() {}
}

private func rows(_ documents: [String: Any]...) -> Data {
    try! JSONSerialization.data(withJSONObject: documents.map { ["document": $0] })
}

private func document(
    id: String,
    title: String,
    sortOrder: Int,
    isPublished: Bool,
    body: String = "本文",
    imageUrls: [String] = [],
    pdfUrl: String? = nil,
    externalUrl: String? = nil
) -> [String: Any] {
    var fields: [String: Any] = [
        "title": ["stringValue": title],
        "body": ["stringValue": body],
        "sortOrder": ["integerValue": String(sortOrder)],
        "imageUrls": [
            "arrayValue": ["values": imageUrls.map { ["stringValue": $0] }]
        ],
        "isPublished": ["booleanValue": isPublished]
    ]
    if let pdfUrl { fields["pdfUrl"] = ["stringValue": pdfUrl] }
    if let externalUrl { fields["externalUrl"] = ["stringValue": externalUrl] }
    return [
        "name": "projects/test-project/databases/(default)/documents/manuals/\(id)",
        "fields": fields
    ]
}
