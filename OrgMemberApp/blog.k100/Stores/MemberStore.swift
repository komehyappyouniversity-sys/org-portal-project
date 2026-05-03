import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct MemberProfile: Identifiable, Equatable {
    let id: String
    let uid: String
    let name: String
    let status: String
    let messageReadBaselineAt: Date?

    var isApproved: Bool {
        status == "approved"
    }
}

@MainActor
final class MemberStore: ObservableObject {

    @Published var isLoading = false
    @Published var authUid: String?
    @Published var profile: MemberProfile?

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var memberListener: ListenerRegistration?

    private let db = Firestore.firestore()

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
        memberListener?.remove()
    }

    func ensureSignedIn() {
        if authHandle != nil { return }

        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            print("👤 Auth state changed:", user?.uid ?? "未ログイン")

            self.authUid = user?.uid
            self.profile = nil

            if let uid = user?.uid, !uid.isEmpty {
                self.watchMember(uid: uid)
            } else {
                self.memberListener?.remove()
                self.memberListener = nil
            }
        }
    }

    private func watchMember(uid: String) {
        let organizationId = OrganizationConfig.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty else {
            print("❌ organizationId が空")
            return
        }

        memberListener?.remove()
        isLoading = true

        let ref = db
            .collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)

        print("🔥 watchMember path:", ref.path)

        memberListener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error {
                print("❌ member 読み込み失敗:", error.localizedDescription)
                return
            }

            guard let data = snapshot?.data() else {
                print("⚠️ member ドキュメントなし")
                DispatchQueue.main.async {
                    self.profile = nil
                }
                return
            }

            let name = data["name"] as? String ?? ""
            let status = data["status"] as? String ?? "pending"

            let baselineAt = (data["messageReadBaselineAt"] as? Timestamp)?.dateValue()

            if baselineAt == nil {
                ref.setData([
                    "messageReadBaselineAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error {
                        print("❌ messageReadBaselineAt 保存失敗:", error.localizedDescription)
                    } else {
                        print("✅ messageReadBaselineAt 初回保存")
                    }
                }
            }

            print("✅ member 読み込み:", name, status)

            DispatchQueue.main.async {
                self.profile = MemberProfile(
                    id: uid,
                    uid: uid,
                    name: name,
                    status: status,
                    messageReadBaselineAt: baselineAt
                )
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.authUid = result.user.uid
    }

    func signOut() {
        try? Auth.auth().signOut()
        authUid = nil
        profile = nil
        memberListener?.remove()
    }
}
