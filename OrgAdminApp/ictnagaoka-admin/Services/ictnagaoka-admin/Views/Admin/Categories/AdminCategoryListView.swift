import SwiftUI

struct AdminCategoryListView: View {
    @EnvironmentObject private var organizationStore: AdminOrganizationStore
    @StateObject private var store = AdminCategoryStore()

    private var currentOrganizationId: String {
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
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            List {
                ForEach(store.categories) { category in
                    HStack {
                        Text(category.name)
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let category = store.categories[index]
                        Task {
                            await store.deleteCategory(
                                organizationId: currentOrganizationId,
                                categoryId: category.id
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle("カテゴリ管理")
        .onAppear {
            store.startListening(
                organizationId: currentOrganizationId
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
                            organizationId: currentOrganizationId
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
                .foregroundStyle(.secondary)
        }
    }
}
