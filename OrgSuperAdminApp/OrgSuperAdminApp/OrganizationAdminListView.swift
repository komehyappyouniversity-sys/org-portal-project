import SwiftUI
import Combine
import FirebaseFirestore

struct OrganizationAdminItem: Identifiable {
    let id: String
    let email: String
    let isActive: Bool
    let role: String
}

@MainActor
final class OrganizationAdminListStore: ObservableObject {
    @Published var admins: [OrganizationAdminItem] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening(organizationId: String) {
        isLoading = true
        errorMessage = ""
        successMessage = ""

        listener?.remove()

        db.collection("organizations")
            .document(organizationId)
            .collection("admins")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    self.isLoading = false

                    if let error {
                        self.errorMessage = "管理者一覧の取得に失敗しました。"
                        print("❌ admins listen error:", error.localizedDescription)
                        return
                    }

                    self.admins = snapshot?.documents.map { doc in
                        let data = doc.data()

                        return OrganizationAdminItem(
                            id: doc.documentID,
                            email: data["email"] as? String ?? "",
                            isActive: data["isActive"] as? Bool ?? false,
                            role: data["role"] as? String ?? "admin"
                        )
                    } ?? []

                    print("✅ admins loaded:", self.admins.count)
                }
            }
    }

    func addAdmin(
        organizationId: String,
        uid: String,
        email: String
    ) async -> Bool {
        errorMessage = ""
        successMessage = ""

        let trimmedUid = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUid.isEmpty else {
            errorMessage = "管理者UIDを入力してください。"
            return false
        }

        guard !trimmedEmail.isEmpty else {
            errorMessage = "メールアドレスを入力してください。"
            return false
        }

        do {
            let ref = db.collection("organizations")
                .document(organizationId)
                .collection("admins")
                .document(trimmedUid)

            try await ref.setData([
                "email": trimmedEmail,
                "isActive": true,
                "role": "admin",
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            successMessage = "管理者を追加しました。"
            print("✅ admin added:", trimmedUid)
            return true

        } catch {
            errorMessage = "管理者の追加に失敗しました。"
            print("❌ add admin error:", error.localizedDescription)
            return false
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

struct OrganizationAdminListView: View {
    let organization: OrganizationItem

    @StateObject private var store = OrganizationAdminListStore()
    @State private var showAddSheet = false

    var body: some View {
        List {
            if store.isLoading {
                ProgressView("読み込み中...")
            }

            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .foregroundColor(.red)
            }

            if !store.successMessage.isEmpty {
                Text(store.successMessage)
                    .foregroundColor(.green)
            }

            Section("管理者") {
                ForEach(store.admins) { admin in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(admin.email.isEmpty ? "メール未設定" : admin.email)
                            .font(.headline)

                        Text("UID: \(admin.id)")
                            .font(.caption)
                            .foregroundColor(.gray)

                        HStack {
                            Text(admin.role)
                                .font(.caption)

                            Text(admin.isActive ? "有効" : "停止中")
                                .font(.caption)
                                .foregroundColor(admin.isActive ? .green : .red)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if !store.isLoading && store.admins.isEmpty {
                    Text("管理者がまだ登録されていません")
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("管理者一覧")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddOrganizationAdminView(
                organization: organization,
                store: store
            )
        }
        .onAppear {
            store.startListening(organizationId: organization.id)
        }
        .onDisappear {
            store.stopListening()
        }
    }
}

struct AddOrganizationAdminView: View {
    let organization: OrganizationItem

    @ObservedObject var store: OrganizationAdminListStore
    @Environment(\.dismiss) private var dismiss

    @State private var uid = ""
    @State private var email = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("追加する管理者") {
                    TextField("管理者UID", text: $uid)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("メールアドレス", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                Section {
                    Text("Firebase Authentication に存在するユーザーのUIDを入力してください。")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }

                if !store.errorMessage.isEmpty {
                    Section {
                        Text(store.errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("管理者追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true

                            let success = await store.addAdmin(
                                organizationId: organization.id,
                                uid: uid,
                                email: email
                            )

                            isSaving = false

                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}
