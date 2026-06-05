//
//  MemberVideoPlayerView.swift
//  blog.k100
//

import SwiftUI
import WebKit
import Combine
import FirebaseAuth
import FirebaseFirestore

struct MemberVideoPlayerView: View {

    @EnvironmentObject private var organizationStore: OrganizationStore

    let video: MemberVideoItem

    @StateObject private var watchLogStore =
        MemberVideoWatchLogStore()

    @StateObject private var noteStore =
        MemberVideoNoteStore()

    @State private var currentSeconds: Double = 0
    @State private var durationSeconds: Double = 0
    @State private var seekSeconds: Double?
    @State private var showNoteSheet = false
    @State private var noteText = ""

    @State private var selectedQuestionNote: MemberVideoNote?
    @State private var showQuestionSheet = false
    @State private var questionText = ""
    @State private var questionMessage = ""

    private var organizationId: String {
        organizationStore.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {

        GeometryReader { geometry in

            let isLandscape =
                geometry.size.width > geometry.size.height

            Group {

                if !video.embedURL.isEmpty {

                    if isLandscape {

                        HStack(spacing: 0) {

                            playerView(height: geometry.size.height)
                                .frame(width: geometry.size.width * 0.68)

                            Divider()

                            noteArea
                                .frame(width: geometry.size.width * 0.32)
                        }

                    } else {

                        VStack(spacing: 0) {

                            playerView(height: 240)

                            noteArea
                        }
                    }

                } else {

                    VStack(spacing: 16) {

                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                            .foregroundColor(.orange)

                        Text("動画URLを開けません")
                            .font(.headline)

                        Text("Vimeo動画IDまたはURLを確認してください。")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                }
            }
        }
        .navigationTitle(video.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {

            guard !organizationId.isEmpty else {
                return
            }

            watchLogStore.recordVideoOpened(
                organizationId: organizationId,
                videoId: video.id,
                videoTitle: video.title
            )

            noteStore.startListening(
                organizationId: organizationId,
                videoId: video.id
            )
        }
        .onDisappear {
            noteStore.stopListening()
        }
        .sheet(isPresented: $showNoteSheet) {
            noteSheet
        }
        .sheet(isPresented: $showQuestionSheet) {
            questionSheet
        }
    }

    private func playerView(height: CGFloat) -> some View {

        VimeoPlayerWebView(
            embedURL: video.embedURL,
            seekSeconds: $seekSeconds,
            onPlayStarted: {

                guard !organizationId.isEmpty else {
                    return
                }

                watchLogStore.recordVideoPlayStarted(
                    organizationId: organizationId,
                    videoId: video.id,
                    videoTitle: video.title
                )
            },
            onProgress: { current, duration in

                currentSeconds = current
                durationSeconds = duration

                guard !organizationId.isEmpty else {
                    return
                }

                watchLogStore.updatePlaybackProgress(
                    organizationId: organizationId,
                    videoId: video.id,
                    videoTitle: video.title,
                    currentPositionSeconds: current,
                    durationSeconds: duration
                )
            },
            onCompleted: { duration in

                durationSeconds = duration

                guard !organizationId.isEmpty else {
                    return
                }

                watchLogStore.recordCompleted(
                    organizationId: organizationId,
                    videoId: video.id,
                    videoTitle: video.title,
                    durationSeconds: duration
                )
            }
        )
        .frame(height: height)
        .background(Color.black)
    }

    private var noteArea: some View {

        VStack(spacing: 12) {

            VStack(alignment: .leading, spacing: 10) {

                Text("現在位置：\(formatTime(currentSeconds))")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button {
                    noteText = ""
                    showNoteSheet = true

                } label: {
                    HStack(spacing: 8) {

                        Image(systemName: "square.and.pencil")

                        Text("この位置にメモを追加")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
                }

                if !questionMessage.isEmpty {

                    Text(questionMessage)
                        .font(.caption)
                        .foregroundColor(
                            questionMessage.contains("失敗")
                            ? .red
                            : .green
                        )
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Divider()

            if noteStore.notes.isEmpty {

                VStack(spacing: 8) {

                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)

                    Text("まだメモはありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("動画を再生しながら、気づいたところでメモを追加できます。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)
                .padding(.horizontal)

                Spacer()

            } else {

                List {

                    Section("動画メモ") {

                        ForEach(noteStore.notes) { note in

                            VStack(alignment: .leading, spacing: 8) {

                                HStack {

                                    Text(formatTime(note.seconds))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)

                                    Spacer()
                                }

                                Text(note.text)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)

                                Button {
                                    seekSeconds = note.seconds

                                } label: {
                                    HStack(spacing: 6) {

                                        Image(systemName: "play.circle.fill")

                                        Text("この位置から再生")
                                            .fontWeight(.bold)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                }

                                Button {
                                    selectedQuestionNote = note
                                    questionText = ""
                                    questionMessage = ""
                                    showQuestionSheet = true

                                } label: {
                                    HStack(spacing: 6) {

                                        Image(systemName: "questionmark.bubble.fill")

                                        Text("管理者へ質問")
                                            .fontWeight(.bold)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.orange)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                        }
                        .onDelete { indexSet in

                            for index in indexSet {

                                let note = noteStore.notes[index]

                                noteStore.deleteNote(
                                    organizationId: organizationId,
                                    noteId: note.id
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(.systemBackground))
    }

    private var noteSheet: some View {

        NavigationStack {

            VStack(alignment: .leading, spacing: 16) {

                Text("再生位置：\(formatTime(currentSeconds))")
                    .font(.headline)

                TextEditor(text: $noteText)
                    .tint(.blue)
                    .accentColor(.blue)
                    .foregroundColor(.primary)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                    .frame(minHeight: 180)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.35))
                    )

                Spacer()
            }
            .padding()
            .navigationTitle("動画メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showNoteSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {

                        noteStore.addNote(
                            organizationId: organizationId,
                            videoId: video.id,
                            videoTitle: video.title,
                            seconds: currentSeconds,
                            text: noteText
                        )

                        showNoteSheet = false
                    }
                    .disabled(
                        noteText.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
        }
    }

    private var questionSheet: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 14) {

                    Text("動画")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(video.title)
                        .font(.headline)

                    Text(
                        "再生位置：\(formatTime(selectedQuestionNote?.seconds ?? currentSeconds))"
                    )
                    .font(.subheadline)
                    .foregroundColor(.blue)

                    Text("メモ内容")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(
                        selectedQuestionNote?.text
                        ?? "メモを取得できませんでした"
                    )
                    .font(.body)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                    Text("質問内容")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ZStack(alignment: .topLeading) {

                        TextEditor(text: $questionText)
                            .tint(.blue)
                            .accentColor(.blue)
                            .foregroundColor(.black)
                            .scrollContentBackground(.hidden)
                            .background(Color.white)
                            .frame(minHeight: 180)
                            .padding(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                            )

                        if questionText.isEmpty {

                            Text("質問を入力してください")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color.white)
            .navigationTitle("管理者へ質問")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showQuestionSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("送信") {

                        let seconds =
                            selectedQuestionNote?.seconds
                            ?? currentSeconds

                        let memoText =
                            selectedQuestionNote?.text
                            ?? ""

                        noteStore.sendQuestionToAdmin(
                            organizationId: organizationId,
                            videoId: video.id,
                            videoTitle: video.title,
                            seconds: seconds,
                            noteText: memoText,
                            questionText: questionText
                        ) { success in

                            questionMessage = success
                                ? "質問を送信しました"
                                : "質問送信に失敗しました"

                            showQuestionSheet = false
                        }
                    }
                    .disabled(
                        questionText.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {

        let totalSeconds = max(Int(seconds), 0)

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

private struct MemberVideoNote: Identifiable {

    let id: String
    let videoId: String
    let videoTitle: String
    let seconds: Double
    let text: String
    let createdAt: Date

    init?(
        id: String,
        data: [String: Any]
    ) {

        guard
            let videoId = data["videoId"] as? String,
            let videoTitle = data["videoTitle"] as? String,
            let seconds = data["seconds"] as? Double,
            let text = data["text"] as? String
        else {
            return nil
        }

        self.id = id
        self.videoId = videoId
        self.videoTitle = videoTitle
        self.seconds = seconds
        self.text = text

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}

private final class MemberVideoNoteStore: ObservableObject {

    @Published var notes: [MemberVideoNote] = []

    private var listener: ListenerRegistration?

    func startListening(
        organizationId: String,
        videoId: String
    ) {

        guard
            let uid = Auth.auth().currentUser?.uid,
            !organizationId.isEmpty
        else {
            notes = []
            return
        }

        stopListening()

        listener = Firestore.firestore()
            .collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)
            .collection("videoNotes")
            .whereField("videoId", isEqualTo: videoId)
            .addSnapshotListener { [weak self] snapshot, error in

                guard let self else {
                    return
                }

                if let error {
                    print(
                        "❌ videoNotes 読み込み失敗:",
                        error.localizedDescription
                    )
                    self.notes = []
                    return
                }

                let loadedNotes =
                    snapshot?.documents.compactMap { document in

                        MemberVideoNote(
                            id: document.documentID,
                            data: document.data()
                        )

                    } ?? []

                self.notes = loadedNotes.sorted {
                    $0.seconds < $1.seconds
                }
            }
    }

    func stopListening() {

        listener?.remove()
        listener = nil
    }

    func addNote(
        organizationId: String,
        videoId: String,
        videoTitle: String,
        seconds: Double,
        text: String
    ) {

        guard
            let uid = Auth.auth().currentUser?.uid,
            !organizationId.isEmpty
        else {
            return
        }

        let trimmedText =
            text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return
        }

        let data: [String: Any] = [
            "videoId": videoId,
            "videoTitle": videoTitle,
            "seconds": seconds,
            "text": trimmedText,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        Firestore.firestore()
            .collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)
            .collection("videoNotes")
            .addDocument(data: data) { error in

                if let error {
                    print(
                        "❌ videoNote 保存失敗:",
                        error.localizedDescription
                    )
                } else {
                    print("✅ videoNote 保存成功")
                }
            }
    }

    func sendQuestionToAdmin(
        organizationId: String,
        videoId: String,
        videoTitle: String,
        seconds: Double,
        noteText: String,
        questionText: String,
        completion: @escaping (Bool) -> Void
    ) {

        guard
            let user = Auth.auth().currentUser,
            !organizationId.isEmpty
        else {
            completion(false)
            return
        }

        let trimmedQuestion =
            questionText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuestion.isEmpty else {
            completion(false)
            return
        }

        let db = Firestore.firestore()

        db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(user.uid)
            .getDocument { memberSnapshot, _ in

                let memberData = memberSnapshot?.data() ?? [:]

                let memberName =
                    memberData["name"] as? String
                    ?? UserDefaults.standard.string(forKey: "memberName")
                    ?? ""

                let data: [String: Any] = [
                    "memberUid": user.uid,
                    "memberName": memberName,
                    "memberEmail": user.email ?? "",
                    "videoId": videoId,
                    "videoTitle": videoTitle,
                    "seconds": seconds,
                    "noteText": noteText,
                    "questionText": trimmedQuestion,
                    "status": "open",
                    "answerText": "",
                    "answeredAt": NSNull(),
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]

                db.collection("organizations")
                    .document(organizationId)
                    .collection("videoQuestions")
                    .addDocument(data: data) { error in

                        if let error {
                            print(
                                "❌ videoQuestion 送信失敗:",
                                error.localizedDescription
                            )
                            completion(false)

                        } else {
                            print("✅ videoQuestion 送信成功")
                            completion(true)
                        }
                    }
            }
    }

    func deleteNote(
        organizationId: String,
        noteId: String
    ) {

        guard
            let uid = Auth.auth().currentUser?.uid,
            !organizationId.isEmpty
        else {
            return
        }

        Firestore.firestore()
            .collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)
            .collection("videoNotes")
            .document(noteId)
            .delete()
    }
}

private struct VimeoPlayerWebView: UIViewRepresentable {

    let embedURL: String

    @Binding var seekSeconds: Double?

    let onPlayStarted: () -> Void

    let onProgress:
    (_ currentSeconds: Double,
     _ durationSeconds: Double) -> Void

    let onCompleted:
    (_ durationSeconds: Double) -> Void

    func makeUIView(context: Context) -> WKWebView {

        let contentController = WKUserContentController()

        contentController.add(
            context.coordinator,
            name: "vimeoEvent"
        )

        let configuration = WKWebViewConfiguration()

        configuration.userContentController =
            contentController

        configuration.allowsInlineMediaPlayback = true

        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        context.coordinator.webView = webView

        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = false

        webView.loadHTMLString(
            makeHTML(embedURL: embedURL),
            baseURL: nil
        )

        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context
    ) {

        guard let seconds = seekSeconds else {
            return
        }

        let safeSeconds = max(seconds, 0)

        let script = """
        if (window.player) {
            window.player.setCurrentTime(\(safeSeconds)).then(function() {
                window.player.play();
            });
        }
        """

        webView.evaluateJavaScript(script)

        DispatchQueue.main.async {
            seekSeconds = nil
        }
    }

    func makeCoordinator() -> Coordinator {

        Coordinator(
            onPlayStarted: onPlayStarted,
            onProgress: onProgress,
            onCompleted: onCompleted
        )
    }

    private func makeHTML(embedURL: String) -> String {

        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              background: #000;
              height: 100%;
              width: 100%;
              overflow: hidden;
            }
            iframe {
              width: 100%;
              height: 100%;
              border: 0;
            }
          </style>
          <script src="https://player.vimeo.com/api/player.js"></script>
        </head>
        <body>
          <iframe
            id="vimeo-player"
            src="\(embedURL)"
            allow="autoplay; fullscreen; picture-in-picture"
            allowfullscreen>
          </iframe>

          <script>
            const iframe = document.getElementById('vimeo-player');
            window.player = new Vimeo.Player(iframe);

            let lastProgressSentAt = 0;

            function send(type, payload) {
              window.webkit.messageHandlers.vimeoEvent.postMessage({
                type: type,
                payload: payload || {}
              });
            }

            window.player.on('play', function() {
              send('play', {});
            });

            window.player.on('timeupdate', function(data) {

              send('currentTime', {
                seconds: data.seconds || 0,
                duration: data.duration || 0
              });

              const now = Date.now();

              if (now - lastProgressSentAt > 10000) {

                lastProgressSentAt = now;

                send('progress', {
                  seconds: data.seconds || 0,
                  duration: data.duration || 0
                });
              }
            });

            window.player.on('ended', function(data) {

              send('ended', {
                duration: data.duration || 0
              });
            });
          </script>
        </body>
        </html>
        """
    }

    final class Coordinator:
        NSObject,
        WKScriptMessageHandler {

        weak var webView: WKWebView?

        let onPlayStarted: () -> Void

        let onProgress:
        (_ currentSeconds: Double,
         _ durationSeconds: Double) -> Void

        let onCompleted:
        (_ durationSeconds: Double) -> Void

        private var didRecordPlayStarted = false

        init(
            onPlayStarted: @escaping () -> Void,
            onProgress: @escaping (
                _ currentSeconds: Double,
                _ durationSeconds: Double
            ) -> Void,
            onCompleted: @escaping (
                _ durationSeconds: Double
            ) -> Void
        ) {

            self.onPlayStarted = onPlayStarted
            self.onProgress = onProgress
            self.onCompleted = onCompleted
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {

            guard
                let body = message.body as? [String: Any],
                let type = body["type"] as? String
            else {
                return
            }

            let payload =
                body["payload"] as? [String: Any]
                ?? [:]

            switch type {

            case "play":

                if !didRecordPlayStarted {

                    didRecordPlayStarted = true
                    onPlayStarted()
                }

            case "currentTime":

                let seconds =
                    payload["seconds"] as? Double ?? 0

                let duration =
                    payload["duration"] as? Double ?? 0

                onProgress(seconds, duration)

            case "progress":

                let seconds =
                    payload["seconds"] as? Double ?? 0

                let duration =
                    payload["duration"] as? Double ?? 0

                onProgress(seconds, duration)

            case "ended":

                let duration =
                    payload["duration"] as? Double ?? 0

                onCompleted(duration)

            default:
                break
            }
        }
    }
}
