import SwiftUI

struct AdminCategorySettingsView: View {
    @EnvironmentObject private var organizationStore: AdminOrganizationStore
    @StateObject private var store = AdminCategoryStore()

    private var organizationId: String {
        organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 16) {
            inputSection

            if store.isLoading {
                ProgressView("読み込み中...")
            }

            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            List {
                ForEach(store.categories) { category in
                    Text(category.name)
                }
                .onDelete { indexSet in
                    deleteCategories(indexSet)
                }
            }
        }
        .padding()
        .navigationTitle("カテゴリ管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.startListening(
                organizationId: organizationId
            )
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カテゴリ追加")
                .font(.headline)

            HStack {
                TextField("例：役員、一般会員、講師", text: $store.newCategoryName)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task {
                        await store.addCategory(
                            organizationId: organizationId
                        )
                    }
                } label: {
                    Text("追加")
                        .fontWeight(.bold)
                }
                .buttonStyle(.borderedProminent)
            }

            Text("削除する場合は、一覧の項目を左にスワイプしてください。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func deleteCategories(_ indexSet: IndexSet) {
        for index in indexSet {
            let category = store.categories[index]

            Task {
                await store.deleteCategory(
                    organizationId: organizationId,
                    categoryId: category.id
                )
            }
        }
    }
}
