import Foundation

struct MemberMessageItem: Identifiable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date
    var isRead: Bool
}
