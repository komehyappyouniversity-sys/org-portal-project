import Foundation
import FirebaseFirestore

struct MemberPostItem: Identifiable, Hashable {
    let id: String

    let memberUid: String
    let memberName: String

    let title: String
    let body: String

    let imageURLs: [String]
    let pdfURL: String?

    let status: String
    let adminReply: String?
    let memberHasReadReply: Bool

    let createdAt: Date?
    let updatedAt: Date?

    init(
        id: String,
        memberUid: String,
        memberName: String,
        title: String,
        body: String,
        imageURLs: [String] = [],
        pdfURL: String? = nil,
        status: String = "new",
        adminReply: String? = nil,
        memberHasReadReply: Bool = true,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.memberUid = memberUid
        self.memberName = memberName
        self.title = title
        self.body = body
        self.imageURLs = imageURLs
        self.pdfURL = pdfURL
        self.status = status
        self.adminReply = adminReply
        self.memberHasReadReply = memberHasReadReply
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        let memberUid = data["memberUid"] as? String ?? ""
        let memberName = data["memberName"] as? String ?? ""

        let title = data["title"] as? String ?? ""
        let body = data["body"] as? String ?? ""

        let imageURLs = data["imageURLs"] as? [String] ?? []
        let pdfURL = data["pdfURL"] as? String

        let status = data["status"] as? String ?? "new"
        let adminReply = data["adminReply"] as? String
        let memberHasReadReply = data["memberHasReadReply"] as? Bool ?? true

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()

        self.init(
            id: document.documentID,
            memberUid: memberUid,
            memberName: memberName,
            title: title,
            body: body,
            imageURLs: imageURLs,
            pdfURL: pdfURL,
            status: status,
            adminReply: adminReply,
            memberHasReadReply: memberHasReadReply,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    var hasUnreadReply: Bool {
        let trimmedReply = adminReply?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmedReply.isEmpty && memberHasReadReply == false
    }

    var hasReply: Bool {
        let trimmedReply = adminReply?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmedReply.isEmpty
    }
}
