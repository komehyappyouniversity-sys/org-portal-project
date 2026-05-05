import SwiftUI
import FirebaseAuth

struct AdminVimeoSettingsView: View {

    @EnvironmentObject var organizationStore: OrganizationStore

    @State private var accessToken = ""
    @State private var userId = ""
    @State private var query = ""

    @State private var isLoading = false
    @State private var message = ""
    @State private var isError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                Text("Vimeo設定")
                    .font(.title.bold())

                Group {
                    Text("アクセストークン")
                        .font(.caption)
                        .foregroundColor(.gray)

                    SecureField("アクセストークンを入力", text: $accessToken)
                        .textFieldStyle(.roundedBorder)
                }

                Group {
                    Text("ユーザーID")
                        .font(.caption)
                        .foregroundColor(.gray)

                    TextField("例: user123456", text: $userId)
                        .textFieldStyle(.roundedBorder)
                }

                Group {
                    Text("検索条件（任意）")
                        .font(.caption)
                        .foregroundColor(.gray)

                    TextField("例: セミナー", text: $query)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("読み込み") {
                        loadSettings()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: {
                        saveSettingsHttp()
                    }) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("保存")
                                .bold()
                                .frame(minWidth: 120)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(isError ? .red : .green)
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadSettings()
        }
    }

    // MARK: - 保存
    private func saveSettingsHttp() {

        guard let user = Auth.auth().currentUser else {
            message = "ログインされていません"
            isError = true
            return
        }

        isLoading = true
        message = ""

        user.getIDToken { token, _ in

            guard let token = token else {
                DispatchQueue.main.async {
                    isLoading = false
                    isError = true
                    message = "トークン取得失敗"
                }
                return
            }

            let url = URL(string:
            "https://asia-northeast1-ictnagaoka-member.cloudfunctions.net/saveVimeoConfigHttp")!

            let body: [String: Any] = [
                "organizationId": organizationStore.organizationId,
                "accessToken": accessToken,
                "userId": userId,
                "query": query
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { data, res, _ in

                DispatchQueue.main.async {
                    isLoading = false
                }

                guard let http = res as? HTTPURLResponse else { return }

                if http.statusCode == 200 {
                    DispatchQueue.main.async {
                        isError = false
                        message = "保存しました"
                    }
                } else {
                    DispatchQueue.main.async {
                        isError = true
                        message = "保存失敗（\(http.statusCode)）"
                    }
                }

            }.resume()
        }
    }

    // MARK: - 読み込み
    private func loadSettings() {

        guard let user = Auth.auth().currentUser else { return }

        user.getIDToken { token, _ in

            guard let token = token else { return }

            let url = URL(string:
            "https://asia-northeast1-ictnagaoka-member.cloudfunctions.net/getVimeoConfigHttp")!

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "organizationId": organizationStore.organizationId
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { data, _, _ in

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return }

                DispatchQueue.main.async {
                    self.userId = json["userId"] as? String ?? ""
                    self.query = json["query"] as? String ?? ""
                }

            }.resume()
        }
    }
}
