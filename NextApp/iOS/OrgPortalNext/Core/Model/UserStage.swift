import Foundation

public enum UserStage: String, CaseIterable, Codable, Sendable {
    case guest
    case member
    case creator
    case manager
    case owner
}

public enum AccountAccessState: String, CaseIterable, Codable, Sendable {
    case guest
    case registered
    case pendingApproval
    case rejected
    case member
}

public enum CommunityMembershipStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case approved
    case rejected
}

public struct Community: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let code: String
    public let name: String
    public let description: String
    public let logoURL: URL?
    public let homepageURL: URL?
    public let isActive: Bool
    public let joinEnabled: Bool

    public init(
        id: String,
        code: String,
        name: String,
        description: String = "",
        logoURL: URL? = nil,
        homepageURL: URL? = nil,
        isActive: Bool = true,
        joinEnabled: Bool = false
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.description = description
        self.logoURL = logoURL
        self.homepageURL = homepageURL
        self.isActive = isActive
        self.joinEnabled = joinEnabled
    }
}

public struct CommunityMembership: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let communityId: String
    public let userId: String
    public let status: CommunityMembershipStatus
    public let role: String
    public let joinedAt: Date?

    public init(
        id: String,
        communityId: String,
        userId: String,
        status: CommunityMembershipStatus,
        role: String = "member",
        joinedAt: Date? = nil
    ) {
        self.id = id
        self.communityId = communityId
        self.userId = userId
        self.status = status
        self.role = role
        self.joinedAt = joinedAt
    }
}

public enum CommunityCodeParser {
    public static func parse(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let components = URLComponents(string: trimmed), components.scheme != nil {
            let supportedNames = ["communityCode", "organizationCode", "code"]
            if let queryCode = components.queryItems?
                .first(where: { supportedNames.contains($0.name) })?.value {
                return normalized(queryCode)
            }
            if let last = components.path.split(separator: "/").last {
                return normalized(String(last))
            }
        }
        return normalized(trimmed)
    }

    private static func normalized(_ value: String) -> String? {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty, result.count <= 100 else { return nil }
        return result.lowercased()
    }
}

public struct AccountCredentials: Equatable, Sendable {
    public static let minimumPasswordLength = 8

    public let email: String
    public let password: String
    public let passwordConfirmation: String?
    public let name: String?
    public let furigana: String?

    public init(
        email: String,
        password: String,
        passwordConfirmation: String? = nil,
        name: String? = nil,
        furigana: String? = nil
    ) {
        self.email = email
        self.password = password
        self.passwordConfirmation = passwordConfirmation
        self.name = name
        self.furigana = furigana
    }

    public func validationMessage() -> String? {
        if passwordConfirmation != nil,
           name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return "名前を入力してください。"
        }
        if passwordConfirmation != nil,
           furigana?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return "ふりがなを入力してください。"
        }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = normalizedEmail.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].contains(".") else {
            return "メールアドレスの形式を確認してください。"
        }
        guard password.count >= Self.minimumPasswordLength else {
            return "パスワードは8文字以上で入力してください。"
        }
        if let passwordConfirmation, password != passwordConfirmation {
            return "確認用パスワードが一致しません。"
        }
        return nil
    }
}
