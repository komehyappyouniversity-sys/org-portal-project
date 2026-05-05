import Foundation
import Combine
import LocalAuthentication

@MainActor
final class SuperAdminSecurityStore: ObservableObject {
    @Published var isUnlocked = false
    @Published var errorMessage = ""

    func unlockWithFaceID() {
        errorMessage = ""

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = "Face IDを利用できません。"
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "上位管理アプリを開くためにFace IDで認証してください"
        ) { success, authError in
            Task { @MainActor in
                if success {
                    self.isUnlocked = true
                } else {
                    self.isUnlocked = false
                    self.errorMessage = "Face ID認証に失敗しました。"
                    print("❌ Face ID error:", authError?.localizedDescription ?? "")
                }
            }
        }
    }

    func lock() {
        isUnlocked = false
    }
}
