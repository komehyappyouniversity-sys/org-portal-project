//
//  KeychainHelper.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/13.
//

import Foundation
import LocalAuthentication
import Security

enum KeychainHelper {
    private static let service = "org.nagaoka.blog-k100"
    private static let account = "member_faceid_unlock"

    static func saveBiometricFlag() -> Bool {
        let data = Data("approved_member".utf8)

        let access =
            SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                .biometryCurrentSet,
                nil
            )

        guard let access else { return false }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func hasBiometricFlag() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let result = SecItemCopyMatching(query as CFDictionary, nil)
        return result == errSecSuccess
    }

    static func authenticateWithBiometrics(reason: String = "会員ページを開くには認証が必要です。") async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("生体認証利用不可:", error?.localizedDescription ?? "unknown")
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, evaluateError in
                if let evaluateError {
                    print("生体認証エラー:", evaluateError.localizedDescription)
                }
                continuation.resume(returning: success)
            }
        }
    }
}
