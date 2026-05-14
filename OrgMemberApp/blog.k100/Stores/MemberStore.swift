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
    private var currentOrganizationId: String = ""
    private var watchingMemberPath: String = ""

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
                self.watchMemberIfPossible(uid: uid)
            } else {
                self.memberListener?.remove()
                self.memberListener = nil
                self.watchingMemberPath = ""
                self.isLoading = false
            }
        }
    }

    func setOrganizationId(_ organizationId: String) {
        let trimmed = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            print("⚠️ MemberStore organizationId empty")
            return
        }

        if currentOrganizationId == trimmed {
            print("ℹ️ MemberStore organizationId unchanged:", trimmed)
            return
        }

        currentOrganizationId = trimmed
        watchingMemberPath = ""

        print("🏢 MemberStore organizationId:", trimmed)

        if let uid = authUid, !uid.isEmpty {
            watchMemberIfPossible(uid: uid)
        }
    }

    private func watchMemberIfPossible(uid: String) {
        guard !currentOrganizationId.isEmpty else {
            print("⚠️ organizationId 未設定のため member 監視を待機")
            isLoading = false
            return
        }

        watchMember(uid: uid, organizationId: currentOrganizationId)
    }

    private func watchMember(uid: String, organizationId: String) {
        let ref = db
            .collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)

        if watchingMemberPath == ref.path {
            print("ℹ️ watchMember already active:", ref.path)
            return
        }

        memberListener?.remove()
        memberListener = nil

        watchingMemberPath = ref.path
        isLoading = true

        print("🔥 watchMember path:", ref.path)

        memberListener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            Task { @MainActor in
                self.isLoading = false

                if let error {
                    print("❌ member 読み込み失敗:", error.localizedDescription)
                    self.profile = nil
                    return
                }

                guard let data = snapshot?.data() else {
                    print("⚠️ member ドキュメントなし")
                    self.profile = nil
                    return
                }

                let name = data["name"] as? String ?? ""
                let status = data["status"] as? String ?? "pending"
                let baselineAt = (data["messageReadBaselineAt"] as? Timestamp)?.dateValue()

                if baselineAt == nil {
                    ref.setData([
                        "messageReadBaselineAt": FieldValue.serverTimestamp()
                    ], merge: true)
                }

                print("✅ member 読み込み:", name, status)

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
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = try await Auth.auth().signIn(
            withEmail: trimmedEmail,
            password: password
        )

        self.authUid = result.user.uid
        watchMemberIfPossible(uid: result.user.uid)
    }

    func signOut() {
        try? Auth.auth().signOut()

        authUid = nil
        profile = nil
        isLoading = false
        watchingMemberPath = ""

        memberListener?.remove()
        memberListener = nil
    }
}
