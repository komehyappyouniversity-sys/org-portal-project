import SwiftUI

struct DiaryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var memberStore: MemberStore
    @EnvironmentObject var organizationStore: OrganizationStore
    @ObservedObject var store: DiaryStore

    let entry: DiaryEntry

    @State private var showEditView = false
    @State private var showDeleteAlert = false
    @State private var showErrorAlert = false
    @State private var errorText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(dateText(entry.date))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.title)
                            .font(.system(size: 30, weight: .bold))
                    }

                    if !entry.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.body)
                            .font(.body)
                            .lineSpacing(6)
                    }

                    DiaryImageRowView(imageUrls: entry.imageUrls)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.systemBackground))
                )

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text("この日記を削除")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.red)
                        )
                }
                .buttonStyle(.plain)
                .disabled(store.isSaving)
            }
            .padding(20)
        }
        .background(Color(.systemGray6))
        .navigationTitle("日記詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") {
                    showEditView = true
                }
                .disabled(store.isSaving)
            }
        }
        .sheet(isPresented: $showEditView) {
            NavigationStack {
                DiaryEditView(store: store, entry: entry)
                    .environmentObject(memberStore)
                    .environmentObject(organizationStore)
            }
        }
        .alert("この日記を削除しますか？", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("削除すると元に戻せません。")
        }
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorText)
        }
    }

    private func deleteEntry() {
        store.deleteEntry(
            organizationId: OrganizationConfig.organizationId,
            entry: entry
        ) { result in
            switch result {
            case .success:
                dismiss()

            case .failure(let error):
                errorText = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter.string(from: date)
    }
}
