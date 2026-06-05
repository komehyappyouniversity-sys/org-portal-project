import SwiftUI
import Combine
import FirebaseFirestore

struct AdminVideoQuestionItem: Identifiable {

    let id: String
    let memberUid: String
    let memberEmail: String
    let videoId: String
    let videoTitle: String
    let seconds: Double
    let noteText: String
    let questionText: String
    let answerText: String
    let status: String
    let createdAt: Date?
    let memberName: String

    init(id: String, data: [String: Any]) {

        self.id = id
        self.memberUid = data["memberUid"] as? String ?? ""
        self.memberName = data["memberName"] as? String ?? ""
        self.memberEmail = data["memberEmail"] as? String ?? ""
        self.videoId = data["videoId"] as? String ?? ""
        self.videoTitle = data["videoTitle"] as? String ?? ""
        self.seconds = data["seconds"] as? Double ?? 0
        self.noteText = data["noteText"] as? String ?? ""
        self.questionText = data["questionText"] as? String ?? ""
        self.answerText = data["answerText"] as? String ?? ""
        self.status = data["status"] as? String ?? "open"

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }
    }
}

@MainActor
final class AdminVideoQuestionStore: ObservableObject {

    @Published var questions: [AdminVideoQuestionItem] = []
    @Published var isLoading = false
    @Published var message = ""

    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {

        let orgId = organizationId.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !orgId.isEmpty else {
            questions = []
            message = "organizationId が空です"
            return
        }

        listener?.remove()
        isLoading = true
        message = ""

        listener = Firestore.firestore()
            .collection("organizations")
            .document(orgId)
            .collection("videoQuestions")
            .addSnapshotListener { [weak self] snapshot, error in

                guard let self else {
                    return
                }

                Task { @MainActor in

                    self.isLoading = false

                    if let error {
                        self.questions = []
                        self.message = "読み込み失敗: \(error.localizedDescription)"
                        return
                    }

                    let items = snapshot?.documents.map { document in
                        AdminVideoQuestionItem(
                            id: document.documentID,
                            data: document.data()
                        )
                    } ?? []

                    self.questions = items.sorted {
                        ($0.createdAt ?? Date.distantPast) >
                        ($1.createdAt ?? Date.distantPast)
                    }
                }
            }
    }

    func saveAnswer(
        organizationId: String,
        questionId: String,
        answerText: String
    ) {

        let orgId = organizationId.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let trimmedAnswer = answerText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !orgId.isEmpty, !trimmedAnswer.isEmpty else {
            message = "回答を入力してください"
            return
        }

        Firestore.firestore()
            .collection("organizations")
            .document(orgId)
            .collection("videoQuestions")
            .document(questionId)
            .updateData([
                "answerText": trimmedAnswer,
                "status": "answered",
                "answeredAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]) { [weak self] error in

                DispatchQueue.main.async {

                    if let error {
                        self?.message = "返信保存失敗: \(error.localizedDescription)"
                    } else {
                        self?.message = "返信を保存しました"
                    }
                }
            }
    }
}

struct AdminVideoQuestionListView: View {

    @EnvironmentObject var organizationStore: AdminOrganizationStore

    @StateObject private var store = AdminVideoQuestionStore()

    private var organizationId: String {
        organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {

        List {

            if store.isLoading {
                ProgressView("質問を読み込み中...")
            }

            if !store.message.isEmpty {
                Text(store.message)
                    .font(.footnote)
                    .foregroundColor(
                        store.message.contains("失敗") ? .red : .green
                    )
            }

            if store.questions.isEmpty && !store.isLoading {

                ContentUnavailableView(
                    "動画質問はありません",
                    systemImage: "questionmark.bubble"
                )

            } else {

                ForEach(store.questions) { question in

                    NavigationLink {
                        AdminVideoQuestionDetailView(
                            question: question,
                            organizationId: organizationId,
                            store: store
                        )

                    } label: {

                        VStack(alignment: .leading, spacing: 6) {

                            HStack {
                                Text(question.status == "answered" ? "回答済み" : "未回答")
                                    .font(.caption.bold())
                                    .foregroundColor(
                                        question.status == "answered"
                                        ? .green
                                        : .orange
                                    )

                                Spacer()

                                Text(formatTime(question.seconds))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }

                            Text(
                                question.memberName.isEmpty
                                ? "名前未設定"
                                : question.memberName
                            )
                            .font(.headline)
                            .foregroundColor(.blue)

                            Text(question.videoTitle)
                                .font(.headline)
                                .lineLimit(2)

                            Text(question.questionText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("動画質問一覧")
        .onAppear {
            store.startListening(organizationId: organizationId)
        }
    }

    private func formatTime(_ seconds: Double) -> String {

        let totalSeconds = max(Int(seconds), 0)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60

        return String(format: "%02d:%02d", minutes, secs)
    }
}

struct AdminVideoQuestionDetailView: View {

    let question: AdminVideoQuestionItem
    let organizationId: String

    @ObservedObject var store: AdminVideoQuestionStore

    @State private var answerText: String

    init(
        question: AdminVideoQuestionItem,
        organizationId: String,
        store: AdminVideoQuestionStore
    ) {
        self.question = question
        self.organizationId = organizationId
        self.store = store
        _answerText = State(initialValue: question.answerText)
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 16) {

                sectionTitle("動画")
                Text(question.videoTitle)
                    .font(.headline)

                sectionTitle("再生位置")
                Text(formatTime(question.seconds))
                    .foregroundColor(.blue)

                sectionTitle("会員")

                Text(
                    question.memberName.isEmpty
                    ? "名前未設定"
                    : question.memberName
                )
                .font(.headline)

                Text(
                    question.memberEmail.isEmpty
                    ? question.memberUid
                    : question.memberEmail
                )
                .foregroundColor(.secondary)

                sectionTitle("会員メモ")
                textBox(question.noteText)

                sectionTitle("質問内容")
                textBox(question.questionText)

                sectionTitle("管理者の返信")

                TextEditor(text: $answerText)
                    .tint(.blue)
                    .foregroundColor(.black)
                    .scrollContentBackground(.hidden)
                    .background(Color.white)
                    .frame(minHeight: 180)
                    .padding(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 2)
                    )

                Button {
                    store.saveAnswer(
                        organizationId: organizationId,
                        questionId: question.id,
                        answerText: answerText
                    )

                } label: {
                    Text("返信を保存")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("質問詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private func textBox(_ text: String) -> some View {
        Text(text.isEmpty ? "なし" : text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
    }

    private func formatTime(_ seconds: Double) -> String {

        let totalSeconds = max(Int(seconds), 0)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60

        return String(format: "%02d:%02d", minutes, secs)
    }
}
