import SwiftUI

struct MemberDiaryDetailView: View {

    let organizationId: String
    let uid: String
    let diary: MemberDiary

    @ObservedObject var store: MemberDiaryStore

    @State private var showEditor = false
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 8) {
                    Text(diary.title.isEmpty ? "無題の日記" : diary.title)
                        .font(.title2.bold())

                    Text(diary.createdAt.formatted(date: .long, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("気分：\(diary.mood)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                Text(diary.body)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !diary.imageURLs.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("写真")
                            .font(.headline)

                        ForEach(diary.imageURLs, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                            .padding()

                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: 12))

                                    case .failure:
                                        Text("画像を読み込めませんでした")
                                            .foregroundColor(.secondary)

                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("日記詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("編集") {
                    showEditor = true
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                MemberDiaryEditorView(
                    organizationId: organizationId,
                    uid: uid,
                    existingDiary: diary,
                    store: store
                )
            }
        }
        .alert("日記を削除しますか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                Task {
                    await store.deleteDiary(
                        organizationId: organizationId,
                        uid: uid,
                        diary: diary
                    )
                }
            }

            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。")
        }
    }
}
