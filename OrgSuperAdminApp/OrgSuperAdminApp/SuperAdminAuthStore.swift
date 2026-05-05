import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SuperAdminAuthStore: ObservableObject {
    @Published var isSignedIn = false
    @Published var isSuperAdmin = false
    @Published var email = ""
    @Published var errorMessage = ""
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var handle: AuthStateDidChangeListenerHandle?

    func start() {
        guard handle == nil else { return }

        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }

                self.isSignedIn = user != nil
                self.email = user?.email ?? ""

                if let uid = user?.uid {
                    print("✅ SuperAdmin login uid:", uid)
                    await self.checkSuperAdmin(uid: uid)
                } else {
                    self.isSuperAdmin = false
                }
            }
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = ""
        isLoading = true

        do {
            let result = try await Auth.auth().signIn(
                withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )

            print("✅ Login success:", result.user.uid)
            await checkSuperAdmin(uid: result.user.uid)

        } catch {
            errorMessage = "ログインできませんでした。メールアドレスまたはパスワードを確認してください。"
            print("❌ Login error:", error.localizedDescription)
        }

        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isSignedIn = false
            isSuperAdmin = false
            email = ""
        } catch {
            errorMessage = "ログアウトできませんでした。"
            print("❌ Sign out error:", error.localizedDescription)
        }
    }

    private func checkSuperAdmin(uid: String) async {
        do {
            let doc = try await db.collection("superAdmins")
                .document(uid)
                .getDocument()

            let isActive = doc.data()?["isActive"] as? Bool ?? false

            if doc.exists && isActive {
                isSuperAdmin = true
                print("✅ SuperAdmin approved")
            } else {
                isSuperAdmin = false
                errorMessage = "このアカウントは上位管理者として登録されていません。"
                print("⚠️ Not super admin:", uid)
            }

        } catch {
            isSuperAdmin = false
            errorMessage = "上位管理者情報の確認に失敗しました。"
            print("❌ SuperAdmin check error:", error.localizedDescription)
        }
    }
}
