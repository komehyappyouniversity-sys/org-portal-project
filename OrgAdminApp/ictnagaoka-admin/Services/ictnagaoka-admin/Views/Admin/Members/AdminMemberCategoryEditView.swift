import SwiftUI
import FirebaseFirestore

struct AdminMemberCategoryEditView: View {
    let organizationId: String
    let member: AdminMemberItem

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategories: Set<String> = []
    @State private var customCategory: String = ""
    @State private var isSaving = false
    @State private var errorMessage = ""

    private let db = Firestore.firestore()

    private let presetCategories = [
        "役員",
        "指導員",
        "一般",
        "初心者",
        "上級者",
        "スタッフ"
    ]

    var body: some View {
        Form {
            Section("会員") {
                Text(member.name.isEmpty ? "名称未設定" : member.name)
                Text(member.email)
                    .foregroundColor(.gray)
            }

            Section("カテゴリ選択") {
                ForEach(presetCategories, id: \.self) { category in
                    Button {
                        toggle(category)
                    } label: {
                        HStack {
                            Text(category)
                            Spacer()
                            if selectedCategories.contains(category) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }

            Section("カテゴリ追加") {
                TextField("例：長岡教室", text: $customCategory)

                Button("追加") {
                    let value = customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty else { return }
                    selectedCategories.insert(value)
                    customCategory = ""
                }
            }

            Section("現在のカテゴリ") {
                if selectedCategories.isEmpty {
                    Text("カテゴリ未設定")
                        .foregroundColor(.gray)
                } else {
                    ForEach(Array(selectedCategories).sorted(), id: \.self) { category in
                        HStack {
                            Text(category)
                            Spacer()
                            Button("削除") {
                                selectedCategories.remove(category)
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    save()
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
        .navigationTitle("カテゴリ編集")
        .onAppear {
            selectedCategories = Set(member.categories)
        }
    }

    private func toggle(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    private func save() {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId がありません"
            return
        }

        isSaving = true
        errorMessage = ""

        let categories = Array(selectedCategories).sorted()

        db.collection("organizations")
            .document(orgId)
            .collection("members")
            .document(member.id)
            .setData([
                "categories": categories,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true) { error in
                isSaving = false

                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    dismiss()
                }
            }
    }
}
