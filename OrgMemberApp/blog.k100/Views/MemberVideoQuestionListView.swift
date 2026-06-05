import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

struct MemberVideoQuestionListView: View {

    @EnvironmentObject private var memberStore: MemberStore
    @EnvironmentObject private var organizationStore: OrganizationStore

    @StateObject private var store = MemberVideoQuestionStore()

    var body: some View {

        List {

            if store.isLoading {

                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

            } else if store.questions.isEmpty {

                Section {
                    Text("動画質問はまだありません。")
                        .foregroundColor(.secondary)
                }

            } else {

                ForEach(store.questions) { question in

                    Section {
                        VStack(alignment: .leading, spacing: 10) {

                            HStack {
                                Text(question.isAnswered ? "回答済み" : "未回答")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(question.isAnswered ? Color.green : Color.orange)
                                    .clipShape(Capsule())

                                Spacer()
                            }

                            infoBlock(title: "動画タイトル", value: question.videoTitle)
                            infoBlock(title: "再生位置", value: formatSeconds(question.playbackSeconds))
                            infoBlock(title: "メモ内容", value: question.memoText)
                            infoBlock(title: "質問内容", value: question.questionText)

                            if question.isAnswered {
                                Divider()

                                infoBlock(
                                    title: "管理者からの回答",
                                    value: question.answerText
                                )
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("動画質問・回答")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.startListening(
                organizationId: organizationStore.organizationId,
                memberUid: memberStore.authUid ?? ""
            )
        }
        .onDisappear {
            store.stopListening()
        }
    }

    private func infoBlock(title: String, value: String) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value.isEmpty ? "未入力" : value)
                .font(.body)
                .foregroundColor(.primary)
        }
    }

    private func formatSeconds(_ seconds: Double) -> String {

        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60

        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct MemberVideoQuestionItem: Identifiable {

    let id: String
    let memberUid: String
    let videoTitle: String
    let playbackSeconds: Double
    let memoText: String
    let questionText: String
    let answerText: String
    let createdAt: Date

    var isAnswered: Bool {
        !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private final class MemberVideoQuestionStore: ObservableObject {

    @Published var questions: [MemberVideoQuestionItem] = []
    @Published var isLoading = false

    private var listener: ListenerRegistration?

    func startListening(
        organizationId: String,
        memberUid: String
    ) {

        let organizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let memberUid = memberUid.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty,
              !memberUid.isEmpty else {
            questions = []
            return
        }

        stopListening()
        isLoading = true

        listener = Firestore.firestore()
            .collection("organizations")
            .document(organizationId)
            .collection("videoQuestions")
            .whereField("memberUid", isEqualTo: memberUid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in

                DispatchQueue.main.async {
                    self?.isLoading = false

                    if let error {
                        print("動画質問取得エラー:", error.localizedDescription)
                        self?.questions = []
                        return
                    }

                    self?.questions = snapshot?.documents.map { document in

                        let data = document.data()

                        return MemberVideoQuestionItem(
                            id: document.documentID,
                            memberUid: data["memberUid"] as? String ?? "",
                            videoTitle: data["videoTitle"] as? String ?? "",
                            playbackSeconds: data["playbackSeconds"] as? Double ?? 0,
                            memoText: data["memoText"] as? String ?? "",
                            questionText: data["questionText"] as? String ?? "",
                            answerText: data["answerText"] as? String ?? "",
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    } ?? []
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
