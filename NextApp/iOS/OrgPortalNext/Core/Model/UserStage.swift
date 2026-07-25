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
    case pendingApproval
    case rejected
    case member
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
