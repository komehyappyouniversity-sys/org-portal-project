import Foundation

struct MemberRegistration: Identifiable, Codable {
    let id: String

    var uid: String
    var organizationId: String

    var name: String
    var kana: String
    var birthDate: Date
    var email: String
    var phone: String

    var memberCode: String
    var category: String
    var note: String

    var status: RegistrationStatus

    var createdAt: Date
    var updatedAt: Date?

    init(
        id: String = UUID().uuidString,
        uid: String = "",
        organizationId: String = "",
        name: String = "",
        kana: String = "",
        birthDate: Date = Date(),
        email: String = "",
        phone: String = "",
        memberCode: String = "",
        category: String = "",
        note: String = "",
        status: RegistrationStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.uid = uid
        self.organizationId = organizationId
        self.name = name
        self.kana = kana
        self.birthDate = birthDate
        self.email = email
        self.phone = phone
        self.memberCode = memberCode
        self.category = category
        self.note = note
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum RegistrationStatus: String, Codable, CaseIterable {
    case pending
    case approved
    case rejected
}
