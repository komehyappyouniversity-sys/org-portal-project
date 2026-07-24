import AVFAudio
import DesignSystem
import Model
import QuickLook
import SwiftUI
import UIKit

public struct MeetingMinutesRootView: View {
    @ObservedObject private var model: MeetingMinutesFeatureModel
    @State private var isShowingRecorder = false
    @State private var selected: MeetingMinutes?

    public init(model: MeetingMinutesFeatureModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.minutes.isEmpty {
                    EmptyState(
                        "会議録音はまだありません",
                        systemImage: "mic"
                    )
                } else {
                    List(model.minutes) { value in
                        Button {
                            selected = value
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(value.title).font(.headline)
                                Text(value.recordingStartAt.formatted())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Label(
                                    Self.duration(value.recordingDurationSeconds),
                                    systemImage: "waveform"
                                )
                                .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("会議録音・議事録")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingRecorder = true
                    } label: {
                        Label("録音", systemImage: "mic.circle.fill")
                    }
                }
            }
            .task { await model.load() }
            .alert(
                "未保存の録音があります",
                isPresented: Binding(
                    get: { model.draft != nil && !isShowingRecorder },
                    set: { _ in }
                )
            ) {
                Button("復旧する") { isShowingRecorder = true }
                Button("削除", role: .destructive) { model.discardDraft() }
            } message: {
                Text("前回中断された録音を再生し、名前を付けて保存できます。")
            }
        }
        .sheet(isPresented: $isShowingRecorder) {
            MeetingRecorderView(model: model)
        }
        .sheet(item: $selected) { value in
            MeetingMinutesDetailView(model: model, minutes: value)
        }
    }

    nonisolated static func duration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct MeetingRecorderView: View {
    @ObservedObject var model: MeetingMinutesFeatureModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var transcript = ""
    @State private var showPermissionExplanation = false
    @State private var isSaving = false
    @State private var player: AVAudioPlayer?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Circle()
                            .fill(model.isRecording ? .red : .secondary)
                            .frame(width: 12, height: 12)
                        Text(model.isRecording ? "録音中" : "停止中")
                            .font(.headline)
                        Spacer()
                        Text(MeetingMinutesRootView.duration(model.elapsedSeconds))
                            .monospacedDigit()
                    }
                    if model.isRecording {
                        Button("録音を停止", role: .destructive) {
                            model.stopRecording()
                            transcript = model.liveTranscript
                        }
                    } else if model.draft == nil {
                        Button("録音を開始") {
                            showPermissionExplanation = true
                        }
                    }
                }

                if model.draft != nil {
                    Section("保存内容") {
                        if !model.isRecording, let draft = model.draft {
                            Button(player?.isPlaying == true ? "停止" : "未保存の録音を再生") {
                                if player?.isPlaying == true {
                                    player?.stop()
                                } else {
                                    player = try? AVAudioPlayer(
                                        contentsOf: URL(
                                            fileURLWithPath: draft.audioFileLocalPath
                                        )
                                    )
                                    player?.play()
                                }
                            }
                        }
                        TextField("会議名（必須）", text: $title)
                        TextEditor(text: $transcript)
                            .frame(minHeight: 180)
                        Text("文字起こしには誤りが含まれる場合があります。保存前に確認・編集してください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let notice = model.notice {
                            Text(notice).font(.caption).foregroundStyle(.orange)
                        }
                        Button("名前を付けて保存") {
                            Task {
                                isSaving = true
                                defer { isSaving = false }
                                do {
                                    try await model.saveDraft(
                                        title: title,
                                        transcript: transcript
                                    )
                                    dismiss()
                                } catch {
                                    model.report(error)
                                }
                            }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  model.isRecording || isSaving)
                        Button("未保存の録音を削除", role: .destructive) {
                            model.discardDraft()
                            dismiss()
                        }
                        .disabled(model.isRecording)
                    }
                }
            }
            .navigationTitle("録音")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }.disabled(model.isRecording)
                }
            }
            .onAppear {
                transcript = model.draft?.transcriptText ?? model.liveTranscript
            }
            .onDisappear { player?.stop() }
            .onChange(of: model.liveTranscript) { _, value in
                if model.isRecording { transcript = value }
            }
            .alert("マイクを使用します", isPresented: $showPermissionExplanation) {
                Button("続ける") {
                    Task {
                        if await model.startRecording() {
                            transcript = ""
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("会議音声を端末内へ保存し、対応端末では端末内だけで文字起こしします。外部へ送信しません。")
            }
            .alert(
                "録音できません",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.clearError() } }
                )
            ) {
                Button("OK") { model.clearError() }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }
}

private struct MeetingMinutesDetailView: View {
    @ObservedObject var model: MeetingMinutesFeatureModel
    @Environment(\.dismiss) private var dismiss
    @State var minutes: MeetingMinutes
    @State private var player: AVAudioPlayer?
    @State private var shareItems: [Any]?
    @State private var previewURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("会議") {
                    TextField("会議名", text: $minutes.title)
                    LabeledContent("録音日時", value: minutes.recordingStartAt.formatted())
                    LabeledContent(
                        "録音時間",
                        value: MeetingMinutesRootView.duration(minutes.recordingDurationSeconds)
                    )
                    Button(player?.isPlaying == true ? "停止" : "録音を再生") {
                        togglePlayback()
                    }
                }
                Section("議事録") {
                    TextEditor(text: $minutes.transcriptText).frame(minHeight: 240)
                    Text("文字起こしには誤りが含まれる場合があります。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("共有") {
                    Button("議事録テキストを共有") {
                        shareItems = [minutes.transcriptText]
                    }
                    Button("PDFをプレビュー") {
                        do {
                            let url = try createPDF()
                            previewURL = url
                        } catch {
                            model.report(error)
                        }
                    }
                    Button("PDFを作成して共有") {
                        do {
                            let url = try createPDF()
                            shareItems = [url]
                        } catch {
                            model.report(error)
                        }
                    }
                }
                Section {
                    Button("削除", role: .destructive) {
                        Task {
                            await model.delete(minutes)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("議事録")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            try? await model.update(minutes)
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { shareItems != nil },
                set: { if !$0 { shareItems = nil } }
            )
        ) {
            ActivityShareSheet(activityItems: shareItems ?? [])
        }
        .sheet(
            isPresented: Binding(
                get: { previewURL != nil },
                set: { if !$0 { previewURL = nil } }
            )
        ) {
            if let previewURL {
                MeetingMinutesPDFPreview(url: previewURL)
            }
        }
    }

    private func togglePlayback() {
        if player?.isPlaying == true {
            player?.stop()
            return
        }
        player = try? AVAudioPlayer(
            contentsOf: URL(fileURLWithPath: minutes.audioFileLocalPath)
        )
        player?.play()
    }

    private func createPDF() throws -> URL {
        let url = try MeetingMinutesPDFExporter.export(minutes)
        minutes.pdfFileLocalPath = url.path
        let updated = minutes
        Task {
            try? await model.update(updated)
        }
        return url
    }
}

private struct MeetingMinutesPDFPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: QLPreviewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            url as NSURL
        }
    }
}

enum MeetingMinutesPDFExporter {
    static func export(_ minutes: MeetingMinutes) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        let text = """
        \(minutes.title)

        録音日時: \(formatter.string(from: minutes.recordingStartAt))
        録音時間: \(MeetingMinutesRootView.duration(minutes.recordingDurationSeconds))

        議事録
        \(minutes.transcriptText)

        ※文字起こしには誤りが含まれる場合があります。
        """
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
            .appendingPathComponent("MeetingMinutesPDFs", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent(
            "議事録-\(minutes.id.uuidString).pdf"
        )
        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.black
            ]
        )
        let renderer = MeetingMinutesPrintRenderer()
        renderer.addPrintFormatter(
            UISimpleTextPrintFormatter(attributedText: attributedText),
            startingAtPageAt: 0
        )
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, renderer.paperRect, nil)
        for pageIndex in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: pageIndex, in: renderer.paperRect)
        }
        UIGraphicsEndPDFContext()
        try data.write(to: url, options: .atomic)
        return url
    }
}

private final class MeetingMinutesPrintRenderer: UIPrintPageRenderer {
    private let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)

    override var paperRect: CGRect { pageBounds }

    override var printableRect: CGRect {
        pageBounds.insetBy(dx: 44, dy: 44)
    }
}
