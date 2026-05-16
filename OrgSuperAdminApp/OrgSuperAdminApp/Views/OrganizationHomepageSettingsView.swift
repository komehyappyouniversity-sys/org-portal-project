import SwiftUI
import FirebaseFirestore

struct OrganizationHomepageSettingsView: View {
    let organization: OrganizationItem

    @Environment(\.dismiss) private var dismiss

    @State private var homepageURL = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var showSavedAlert = false

    private let db = Firestore.firestore()

    var body: some View {
        Form {
            Section("ホームページURL") {
                TextField("https://example.com", text: $homepageURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("登録すると、会員アプリのトップ画面にホームページボタンが表示されます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    Task {
                        await save()
                    }
                } label: {
                    if isSaving {
                        ProgressView("保存中...")
                    } else {
                        Text("保存")
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("ホームページURL設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .alert("保存しました", isPresented: $showSavedAlert) {
            Button("OK") {
                dismiss()
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = ""

        do {
            let snapshot = try await db
                .collection("organizations")
                .document(organization.id)
                .getDocument()

            let data = snapshot.data() ?? [:]
            homepageURL = data["homepageURL"] as? String ?? ""

        } catch {
            errorMessage = "読み込みに失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func save() async {
        let trimmedURL = homepageURL
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedURL.isEmpty,
           URL(string: trimmedURL) == nil {
            errorMessage = "正しいURLを入力してください。"
            return
        }

        isSaving = true
        errorMessage = ""

        do {
            try await db
                .collection("organizations")
                .document(organization.id)
                .updateData([
                    "homepageURL": trimmedURL,
                    "updatedAt": FieldValue.serverTimestamp()
                ])

            showSavedAlert = true

        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }

        isSaving = false
    }
}
