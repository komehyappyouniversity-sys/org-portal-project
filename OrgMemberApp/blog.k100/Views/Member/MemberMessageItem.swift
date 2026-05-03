import Foundation
import FirebaseFirestore

struct MemberMessageItem: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date?
    let updatedAt: Date?
    let isBroadcast: Bool
    let toUid: String?
    let toUids: [String]
    let categoryTargets: [String]
    let isReadBy: [String]
    let organizationId: String

    var createdAtText: String {
        guard let createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: createdAt)
    }

    func isRead(by uid: String?) -> Bool {
        guard let uid, !uid.isEmpty else { return false }
        return isReadBy.contains(uid)
    }

    static func from(document: DocumentSnapshot, organizationId: String) -> MemberMessageItem {
        let data = document.data() ?? [:]

        let rawTitle = (data["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        return MemberMessageItem(
            id: document.documentID,
            title: rawTitle.isEmpty ? "お知らせ" : rawTitle,
            body: data["body"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
            isBroadcast: data["isBroadcast"] as? Bool ?? true,
            toUid: data["toUid"] as? String,
            toUids: data["toUids"] as? [String] ?? [],
            categoryTargets: data["categoryTargets"] as? [String] ?? [],
            isReadBy: data["isReadBy"] as? [String] ?? [],
            organizationId: organizationId
        )
    }
}
