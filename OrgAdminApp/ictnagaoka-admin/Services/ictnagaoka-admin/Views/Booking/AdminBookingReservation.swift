import Foundation
import FirebaseFirestore

struct AdminBookingReservation: Identifiable {
    var id: String

    var memberUid: String
    var memberName: String
    var memberEmail: String
    var createdAt: Date?

    init(
        id: String = UUID().uuidString,
        memberUid: String = "",
        memberName: String = "",
        memberEmail: String = "",
        createdAt: Date? = nil
    ) {
        self.id = id
        self.memberUid = memberUid
        self.memberName = memberName
        self.memberEmail = memberEmail
        self.createdAt = createdAt
    }

    init(documentId: String, data: [String: Any]) {
        self.id = documentId

        self.memberUid =
            data["memberUid"] as? String ??
            data["uid"] as? String ??
            data["userId"] as? String ??
            ""

        self.memberName =
            data["memberName"] as? String ??
            data["name"] as? String ??
            ""

        self.memberEmail =
            data["memberEmail"] as? String ??
            data["email"] as? String ??
            ""

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }
    }
}
