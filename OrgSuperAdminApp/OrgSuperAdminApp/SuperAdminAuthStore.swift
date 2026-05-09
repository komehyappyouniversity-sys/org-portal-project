import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class SuperAdminAuthStore: ObservableObject {

    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    @Published var uid: String = ""
    @Published var email: String = ""

    private let db = Firestore.firestore()

    init() {
        checkCurrentUser()
    }

    // MARK: - Current User Check

    func checkCurrentUser() {
        guard let user = Auth.auth().currentUser else {
            print("ℹ️ No current Auth user")

            isLoggedIn = false
            uid = ""
            email = ""

            return
        }

        print("✅ Current Auth user found")
        print("✅ current uid:", user.uid)
        print("✅ current email:", user.email ?? "")

        uid = user.uid
        email = user.email ?? ""

        Task {
            await verifySuperAdmin(user: user)
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        errorMessage = ""
        isLoading = true

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        print("🔐 SuperAdmin login start")
        print("📧 email:", trimmedEmail)

        do {
            let result = try await Auth.auth().signIn(
                withEmail: trimmedEmail,
                password: password
            )

            let user = result.user

            print("✅ Firebase Auth login success")
            print("✅ login uid:", user.uid)
            print("✅ login email:", user.email ?? "")

            await verifySuperAdmin(user: user)

        } catch {
            print("❌ Firebase Auth login error:", error.localizedDescription)

            errorMessage = "ログインに失敗しました。メールアドレスまたはパスワードを確認してください。"

            isLoggedIn = false
            isLoading = false
        }
    }

    // MARK: - Verify Super Admin

    private func verifySuperAdmin(user: FirebaseAuth.User) async {

        print("🔎 checking path: superAdmins/\(user.uid)")

        do {
            let snapshot = try await db
                .collection("superAdmins")
                .document(user.uid)
                .getDocument()

            guard snapshot.exists else {

                print("❌ superAdmins document not found")
                print("❌ missing path: superAdmins/\(user.uid)")

                errorMessage = "上位管理者情報が見つかりませんでした。"

                isLoggedIn = false
                isLoading = false

                return
            }

            let data = snapshot.data() ?? [:]

            print("📄 superAdmin data:", data)

            let isActive = data["isActive"] as? Bool ?? false
            let role = data["role"] as? String ?? ""
            let registeredEmail = data["email"] as? String ?? ""

            print("🔎 isActive:", isActive)
            print("🔎 role:", role)
            print("🔎 registeredEmail:", registeredEmail)

            guard isActive else {

                print("❌ superAdmin isActive is false")

                errorMessage = "上位管理者が有効化されていません。"

                isLoggedIn = false
                isLoading = false

                return
            }

            guard role == "superAdmin" else {

                print("❌ role is not superAdmin:", role)

                errorMessage = "上位管理者の権限がありません。"

                isLoggedIn = false
                isLoading = false

                return
            }

            self.uid = user.uid
            self.email = user.email ?? registeredEmail
            self.isLoggedIn = true
            self.errorMessage = ""
            self.isLoading = false

            print("✅ SuperAdmin verified successfully")
            print("✅ login completed")

        } catch {

            print("❌ superAdmin check error:", error.localizedDescription)

            errorMessage = "上位管理者情報の確認に失敗しました。"

            isLoggedIn = false
            isLoading = false
        }
    }

    // MARK: - Logout

    func logout() {
        do {
            try Auth.auth().signOut()

            isLoggedIn = false
            uid = ""
            email = ""
            errorMessage = ""

            print("✅ SuperAdmin logged out")

        } catch {

            print("❌ logout error:", error.localizedDescription)

            errorMessage = "ログアウトに失敗しました。"
        }
    }

    // MARK: - Compatibility

    var isSignedIn: Bool {
        isLoggedIn
    }

    var isSuperAdmin: Bool {
        isLoggedIn
    }

    func start() {
        checkCurrentUser()
    }

    func signIn(email: String, password: String) async {
        await login(email: email, password: password)
    }

    func signOut() {
        logout()
    }
}
