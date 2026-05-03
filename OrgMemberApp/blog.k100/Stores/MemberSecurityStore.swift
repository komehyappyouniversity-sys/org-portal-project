import Foundation
import SwiftUI
import Combine
import LocalAuthentication

@MainActor
final class MemberSecurityStore: ObservableObject {
    @Published var isUnlocked = false
    @Published var isAuthenticating = false
    @Published var errorMessage = ""

    private var lastInactiveDate: Date?
    let relockInterval: TimeInterval = 30

    func authenticateIfNeededOnFirstEntry() {
        // 今回は自動認証を止める
    }

    func handleScenePhaseChange(to newPhase: ScenePhase) {
        switch newPhase {
        case .inactive, .background:
            if isUnlocked {
                lastInactiveDate = Date()
            }

        case .active:
            if shouldRelock {
                isUnlocked = false
            }

        @unknown default:
            break
        }
    }

    func authenticate() {
        guard !isAuthenticating else { return }

        print("🔐 authenticate start")

        let context = LAContext()
        var error: NSError?

        isAuthenticating = true
        errorMessage = ""

        let reason = "会員機能を開くためにFace IDを使用します。"

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ canEvaluatePolicy false:", error?.localizedDescription ?? "unknown")
            isAuthenticating = false
            isUnlocked = false
            errorMessage = error?.localizedDescription ?? "この端末ではFace IDが利用できません。"
            return
        }

        print("✅ canEvaluatePolicy true")

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { [weak self] success, evalError in
            DispatchQueue.main.async {
                guard let self else { return }

                print("🟡 evaluatePolicy returned success =", success)
                if let evalError {
                    print("🟠 evalError =", evalError.localizedDescription)
                }

                self.isAuthenticating = false

                if success {
                    self.isUnlocked = true
                    self.errorMessage = ""
                    self.lastInactiveDate = nil
                    print("✅ unlocked")
                } else {
                    self.isUnlocked = false
                    self.errorMessage = evalError?.localizedDescription ?? "Face ID認証に失敗しました。"
                    print("❌ unlock failed")
                }
            }
        }
    }

    func lockNow() {
        isUnlocked = false
        isAuthenticating = false
        errorMessage = ""
    }

    private var shouldRelock: Bool {
        guard let lastInactiveDate else { return false }
        return Date().timeIntervalSince(lastInactiveDate) >= relockInterval
    }
}
