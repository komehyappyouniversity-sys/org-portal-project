import SwiftUI
import FirebaseFirestore

struct MemberRegistrationSettingsView: View {

    let organizationId: String

    @State private var showBirthDate = true
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var message = ""

    private let db = Firestore.firestore()

    var body: some View {
        List {

            Section {
                Toggle(
                    "生年月日の入力欄を表示する",
                    isOn: $showBirthDate
                )
                .disabled(isLoading || isSaving)

            } header: {
                Text("会員登録項目")
            } footer: {
                Text("OFFにすると、会員アプリの会員登録画面で生年月日の入力欄を表示しません。")
            }

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()

                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                                .fontWeight(.bold)
                        }

                        Spacer()
                    }
                }
                .disabled(isLoading || isSaving)
            }

            if !message.isEmpty {
                Section("結果") {
                    Text(message)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("会員登録項目設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            load()
        }
    }

    private func load() {
        isLoading = true
        message = ""

        db.collection("organizations")
            .document(organizationId)
            .collection("settings")
            .document("memberRegistration")
            .getDocument { snapshot, error in

                DispatchQueue.main.async {
                    isLoading = false

                    if let error {
                        message = "読み込みに失敗しました：\(error.localizedDescription)"
                        return
                    }

                    let data = snapshot?.data() ?? [:]

                    if let value = data["showBirthDate"] as? Bool {
                        showBirthDate = value
                    } else {
                        showBirthDate = true
                    }
                }
            }
    }

    private func save() {
        isSaving = true
        message = ""

        let data: [String: Any] = [
            "showBirthDate": showBirthDate,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection("organizations")
            .document(organizationId)
            .collection("settings")
            .document("memberRegistration")
            .setData(data, merge: true) { error in

                DispatchQueue.main.async {
                    isSaving = false

                    if let error {
                        message = "保存に失敗しました：\(error.localizedDescription)"
                    } else {
                        message = "保存しました"
                    }
                }
            }
    }
}
