import SwiftUI
import FirebaseAuth

struct MemberDiaryListView: View {

    let organizationId: String

    @StateObject private var store = MemberDiaryStore()
    @State private var showEditor = false

    private var uid: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    var body: some View {
        List {
            if store.isLoading {
                ProgressView("読み込み中...")
            }

            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .foregroundColor(.red)
            }

            if store.diaries.isEmpty && !store.isLoading {
                VStack(alignment: .leading, spacing: 8) {
                    Text("まだ日記がありません")
                        .font(.headline)

                    Text("今日の出来事や体調を記録できます。写真は1件につき最大3枚までです。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            ForEach(store.diaries) { diary in
                NavigationLink {
                    MemberDiaryDetailView(
                        organizationId: organizationId,
                        uid: uid,
                        diary: diary,
                        store: store
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(diary.title.isEmpty ? "無題の日記" : diary.title)
                                .font(.headline)

                            Spacer()

                            Text(diary.mood)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(diary.body)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        Text(diary.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("日記")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                MemberDiaryEditorView(
                    organizationId: organizationId,
                    uid: uid,
                    existingDiary: nil,
                    store: store
                )
            }
        }
        .onAppear {
            store.startListening(organizationId: organizationId, uid: uid)
        }
        .onDisappear {
            store.stopListening()
        }
    }
}
