import Foundation
import Combine
import LocalAuthentication

@MainActor
final class AdminSecurityStore: ObservableObject {
    @Published var isUnlocked: Bool = false
    @Published var errorMessage: String?

    func authenticate() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            errorMessage = "Face IDが使用できません。端末の設定を確認してください。"
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "管理アプリを開くために認証してください。"
        ) { success, authenticationError in
            Task { @MainActor in
                if success {
                    self.isUnlocked = true
                    self.errorMessage = nil
                } else {
                    self.isUnlocked = false
                    self.errorMessage = authenticationError?.localizedDescription ?? "認証に失敗しました。"
                }
            }
        }
    }

    func lock() {
        isUnlocked = false
    }
}
