import SwiftUI
import FirebaseAuth
import FirebaseFunctions

struct AdminVimeoSettingsView: View {
    @EnvironmentObject var organizationStore: AdminOrganizationStore

    @State private var accessToken = ""
    @State private var userId = "user111104433"
    @State private var query = ""

    @State private var isLoading = false
    @State private var message = ""
    @State private var isError = false

    @State private var isConnectionTestCompleted = false
    @State private var isSaveCompleted = false

    private var organizationId: String {
        let current = organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return current.isEmpty ? OrganizationConfig.organizationId : current
    }

    var body: some View {
        Form {
            Section("Vimeo連携設定") {
                SecureField("Vimeoアクセストークン", text: $accessToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: accessToken) {
                        isConnectionTestCompleted = false
                        isSaveCompleted = false
                    }

                TextField("VimeoユーザーID", text: $userId)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: userId) {
                        isConnectionTestCompleted = false
                        isSaveCompleted = false
                    }

                TextField("動画取得条件（任意）", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: query) {
                        isSaveCompleted = false
                    }
            }

            Section {
                Button {
                    testConnection()
                } label: {
                    Label(
                        isConnectionTestCompleted ? "接続テスト完了" : "接続テスト",
                        systemImage: isConnectionTestCompleted
                            ? "checkmark.circle.fill"
                            : "network"
                    )
                }
                .foregroundColor(isConnectionTestCompleted ? .green : .blue)
                .disabled(isLoading || accessToken.isEmpty || userId.isEmpty)

                Button {
                    saveSettingsHttp()
                } label: {
                    Label(
                        isSaveCompleted ? "保存完了" : "保存",
                        systemImage: isSaveCompleted
                            ? "checkmark.circle.fill"
                            : "tray.and.arrow.down"
                    )
                }
                .foregroundColor(isSaveCompleted ? .green : .blue)
                .disabled(isLoading || accessToken.isEmpty || userId.isEmpty)
            }

            Section {
                NavigationLink("Vimeo動画一覧を取得") {
                    AdminVimeoVideoListView()
                        .environmentObject(organizationStore)
                }
            }
        }
        .navigationTitle("Vimeo連携設定")
        .onAppear {
            if organizationId.isEmpty {
                organizationStore.startListening(
                    organizationId: OrganizationConfig.organizationId
                )
            }
        }
    }

    private func testConnection() {
        guard validateLogin() else { return }

        isLoading = true
        message = ""
        isError = false
        isConnectionTestCompleted = false
        isSaveCompleted = false

        let data: [String: Any] = [
            "organizationId": organizationId,
            "accessToken": accessToken.trimmingCharacters(in: .whitespacesAndNewlines),
            "userId": userId.trimmingCharacters(in: .whitespacesAndNewlines)
        ]

        let functions = Functions.functions(region: "asia-northeast1")

        functions.httpsCallable("testVimeoConnection").call(data) { _, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error {
                    isError = true
                    isConnectionTestCompleted = false
                    message = "接続テスト失敗: \(error.localizedDescription)"
                    return
                }

                isError = false
                isConnectionTestCompleted = true
                message = "接続テスト完了"
            }
        }
    }

    private func saveSettingsHttp() {
        guard validateLogin() else { return }

        isLoading = true
        message = ""
        isError = false
        isSaveCompleted = false

        guard let user = Auth.auth().currentUser else {
            isLoading = false
            isError = true
            message = "保存失敗: 管理者ログインが確認できません。"
            return
        }

        user.getIDTokenForcingRefresh(true) { token, error in
            if let error {
                DispatchQueue.main.async {
                    isLoading = false
                    isError = true
                    message = "保存失敗: 認証更新エラー \(error.localizedDescription)"
                }
                return
            }

            guard let token else {
                DispatchQueue.main.async {
                    isLoading = false
                    isError = true
                    message = "保存失敗: IDトークンを取得できませんでした。"
                }
                return
            }

            guard let url = URL(
                string: "https://asia-northeast1-ictnagaoka-member.cloudfunctions.net/saveVimeoConfigHttp"
            ) else {
                DispatchQueue.main.async {
                    isLoading = false
                    isError = true
                    message = "保存失敗: URLが不正です。"
                }
                return
            }

            let body: [String: Any] = [
                "organizationId": organizationId,
                "accessToken": accessToken.trimmingCharacters(in: .whitespacesAndNewlines),
                "userId": userId.trimmingCharacters(in: .whitespacesAndNewlines),
                "query": query.trimmingCharacters(in: .whitespacesAndNewlines)
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    isLoading = false

                    if let error {
                        isError = true
                        message = "保存失敗: \(error.localizedDescription)"
                        return
                    }

                    let statusCode =
                        (response as? HTTPURLResponse)?.statusCode ?? 0

                    let responseText =
                        data.flatMap {
                            String(data: $0, encoding: .utf8)
                        } ?? ""

                    guard (200...299).contains(statusCode) else {
                        isError = true
                        message = "保存失敗: HTTP \(statusCode) \(responseText)"
                        return
                    }

                    isError = false
                    isConnectionTestCompleted = true
                    isSaveCompleted = true
                    message = "保存完了"
                }
            }
            .resume()
        }
    }

    private func validateLogin() -> Bool {
        guard !organizationId.isEmpty else {
            isError = true
            message = "organizationId がありません。"
            return false
        }

        guard Auth.auth().currentUser != nil else {
            isError = true
            message = "管理者ログインが確認できません。ログアウト後、再ログインしてください。"
            return false
        }

        return true
    }
}
