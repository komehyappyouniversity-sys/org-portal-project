import SwiftUI
import Combine
import FirebaseFirestore

// MARK: - Login View

struct SuperAdminLoginView: View {
    @EnvironmentObject var authStore: SuperAdminAuthStore

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                Text("上位管理アプリ")
                    .font(.largeTitle.bold())

                Text("管理アプリを管理するためのログイン画面です")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                TextField("メールアドレス", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)

                SecureField("パスワード", text: $password)
                    .textFieldStyle(.roundedBorder)

                if !authStore.errorMessage.isEmpty {
                    Text(authStore.errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button {
                    Task {
                        await authStore.signIn(
                            email: email,
                            password: password
                        )
                    }
                } label: {
                    if authStore.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("ログイン")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    password.isEmpty ||
                    authStore.isLoading
                )

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Model

struct OrganizationItem: Identifiable {
    let id: String
    let name: String
    let isActive: Bool
}

// MARK: - Store

@MainActor
final class OrganizationListStore: ObservableObject {

    @Published var organizations: [OrganizationItem] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        if listener != nil {
            return
        }

        isLoading = true

        listener = db
            .collection("organizations")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    self.isLoading = false

                    if let error {
                        self.errorMessage = "組織一覧の取得に失敗しました。"
                        print("❌ organizations listen error:", error.localizedDescription)
                        return
                    }

                    // 成功した時点で、過去の赤エラーを消す
                    self.errorMessage = ""

                    self.organizations = snapshot?.documents.map { doc in
                        let data = doc.data()

                        return OrganizationItem(
                            id: doc.documentID,
                            name: data["name"] as? String ?? doc.documentID,
                            isActive: data["isActive"] as? Bool ?? false
                        )
                    } ?? []

                    print("✅ organizations realtime loaded:", self.organizations.count)
                }
            }
    }

    func refresh() {
        listener?.remove()
        listener = nil
        startListening()
    }

    func createOrganization(
        organizationId: String,
        name: String
    ) async -> Bool {

        errorMessage = ""
        successMessage = ""

        let trimmedId = organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let trimmedName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedId.isEmpty else {
            errorMessage = "組織IDを入力してください。"
            return false
        }

        guard !trimmedName.isEmpty else {
            errorMessage = "組織名を入力してください。"
            return false
        }

        do {
            let ref = db
                .collection("organizations")
                .document(trimmedId)

            let doc = try await ref.getDocument()

            if doc.exists {
                errorMessage = "この組織IDはすでに存在します。"
                return false
            }

            try await ref.setData([
                "name": trimmedName,
                "isActive": true,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])

            errorMessage = ""
            successMessage = "組織を作成しました。"

            print("✅ organization created:", trimmedId)

            refresh()

            return true

        } catch {
            errorMessage = "組織の作成に失敗しました。"
            print("❌ create organization error:", error.localizedDescription)
            return false
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

// MARK: - List View

struct OrganizationListView: View {

    @EnvironmentObject var authStore: SuperAdminAuthStore
    @StateObject private var store = OrganizationListStore()

    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
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

                ForEach(store.organizations) { org in
                    NavigationLink {
                        OrganizationDetailView(organization: org)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(org.name)
                                .font(.headline)

                            Text("organizationId: \(org.id)")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text(org.isActive ? "有効" : "停止中")
                                .font(.caption)
                                .foregroundColor(org.isActive ? .green : .red)
                        }
                        .padding(.vertical, 6)
                    }
                }

                if !store.isLoading && store.organizations.isEmpty {
                    Text("組織がまだ登録されていません")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("組織一覧")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("ログアウト") {
                        store.stopListening()
                        authStore.signOut()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateOrganizationView(store: store)
            }
            .onAppear {
                store.startListening()
            }
        }
    }
}

// MARK: - Create View

struct CreateOrganizationView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: OrganizationListStore

    @State private var organizationId = ""
    @State private var organizationName = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("組織情報") {
                    TextField("組織ID 例: nagaoka", text: $organizationId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("組織名 例: 長岡支部", text: $organizationName)
                }

                Section {
                    Text("組織IDはFirestoreのパスに使います。英数字・ハイフン・アンダーバー中心がおすすめです。")
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
            .navigationTitle("組織を作成")
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

                            let success = await store.createOrganization(
                                organizationId: organizationId,
                                name: organizationName
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
