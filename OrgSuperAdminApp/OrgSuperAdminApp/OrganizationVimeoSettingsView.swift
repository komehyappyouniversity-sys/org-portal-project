import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFunctions

@MainActor
final class OrganizationVimeoSettingsStore: ObservableObject {
    @Published var accessToken = ""
    @Published var userId = ""
    @Published var query = ""

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    @Published var infoMessage = ""

    private lazy var functions = Functions.functions(region: "asia-northeast1")

    private func currentIdToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "Auth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Firebaseにログインしていません。"]
            )
        }
        return try await user.getIDToken(forcingRefresh: true)
    }

    // 🔵 読み込み
    func load(organizationId: String) async {
        isLoading = true
        errorMessage = ""
        successMessage = ""
        infoMessage = ""

        do {
            let idToken = try await currentIdToken()

            let result = try await functions
                .httpsCallable("getVimeoConfig")
                .call([
                    "organizationId": organizationId,
                    "idToken": idToken
                ])

            guard let data = result.data as? [String: Any] else {
                infoMessage = "Vimeo設定はまだ登録されていません。"
                isLoading = false
                return
            }

            accessToken = data["accessToken"] as? String ?? ""
            userId = data["userId"] as? String ?? ""
            query = data["query"] as? String ?? ""

            if accessToken.isEmpty && userId.isEmpty {
                infoMessage = "Vimeo設定はまだ登録されていません。"
            } else {
                infoMessage = "保存済みのVimeo設定を読み込みました。"
            }

            print("✅ Vimeo config loaded")

        } catch {
            print("❌ load error:", error.localizedDescription)
            infoMessage = "Vimeo設定はまだ登録されていません。"
        }

        isLoading = false
    }

    // 🔴 保存（ここが重要）
    func save(organizationId: String) async {
        errorMessage = ""
        successMessage = ""
        infoMessage = ""
        isSaving = true

        let trimmedAccessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAccessToken.isEmpty else {
            errorMessage = "Vimeoアクセストークンを入力してください。"
            isSaving = false
            return
        }

        guard !trimmedUserId.isEmpty else {
            errorMessage = "VimeoユーザーIDを入力してください。"
            isSaving = false
            return
        }

        do {
            let idToken = try await currentIdToken()

            let result = try await functions
                .httpsCallable("saveVimeoConfigHttp") // ← 修正済み
                .call([
                    "organizationId": organizationId,
                    "accessToken": trimmedAccessToken,
                    "userId": trimmedUserId,
                    "query": trimmedQuery,
                    "idToken": idToken
                ])

            print("✅ save result:", result.data)
            successMessage = "Vimeo設定を保存しました。"

        } catch {
            print("❌ save error:", error.localizedDescription)
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

struct OrganizationVimeoSettingsView: View {
    let organization: OrganizationItem

    @StateObject private var store = OrganizationVimeoSettingsStore()

    var body: some View {
        Form {
            Section("対象組織") {
                row(title: "組織名", value: organization.name)
                row(title: "organizationId", value: organization.id)
            }

            Section("Vimeo設定") {
                SecureField("Vimeoアクセストークン", text: $store.accessToken)
                TextField("VimeoユーザーID", text: $store.userId)
                TextField("動画取得条件", text: $store.query)
            }

            Section {
                Button {
                    Task {
                        await store.save(organizationId: organization.id)
                    }
                } label: {
                    if store.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Vimeo設定を保存")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(store.isSaving)
            }

            if store.isLoading {
                Section {
                    ProgressView("読み込み中...")
                }
            }

            if !store.infoMessage.isEmpty {
                Section {
                    Text(store.infoMessage)
                        .foregroundColor(.gray)
                }
            }

            if !store.errorMessage.isEmpty {
                Section {
                    Text(store.errorMessage)
                        .foregroundColor(.red)
                }
            }

            if !store.successMessage.isEmpty {
                Section {
                    Text(store.successMessage)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("Vimeo設定")
        .task {
            await store.load(organizationId: organization.id)
        }
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.gray)
        }
    }
}
