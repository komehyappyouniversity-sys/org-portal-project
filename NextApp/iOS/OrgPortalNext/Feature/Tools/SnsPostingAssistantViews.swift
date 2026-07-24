import Model
import SwiftUI
import UIKit

public struct SnsPostingAssistantView: View {
    private enum ActiveSheet: Identifiable {
        case share
        case link(SnsCustomLink?)

        var id: String {
            switch self {
            case .share:
                "share"
            case let .link(link):
                "link-\(link?.id.uuidString ?? "new")"
            }
        }
    }

    @ObservedObject private var model: SnsPostingAssistantFeatureModel
    @State private var message = ""
    @State private var activeSheet: ActiveSheet?

    public init(model: SnsPostingAssistantFeatureModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 180)
                        .accessibilityLabel("投稿文章")

                    Button {
                        copyMessage()
                    } label: {
                        Label("文章をコピー", systemImage: "doc.on.doc")
                    }
                    .disabled(trimmedMessage.isEmpty)

                    Button {
                        activeSheet = .share
                    } label: {
                        Label("共有メニューを開く", systemImage: "square.and.arrow.up")
                    }
                    .disabled(trimmedMessage.isEmpty)
                } header: {
                    Text("投稿文章")
                } footer: {
                    Text("文章は自動投稿されません。移動先のSNSで内容を確認して投稿してください。")
                }

                Section("SNSを開く") {
                    destinationButton(
                        title: "Facebook",
                        systemImage: "person.2.fill",
                        appURL: URL(string: "fb://"),
                        webURL: URL(string: "https://www.facebook.com/")!
                    )
                    destinationButton(
                        title: "Instagram",
                        systemImage: "camera.fill",
                        appURL: URL(string: "instagram://app"),
                        webURL: URL(string: "https://www.instagram.com/")!
                    )
                    destinationButton(
                        title: "X",
                        systemImage: "bubble.left.and.bubble.right.fill",
                        appURL: xAppURL,
                        webURL: xWebURL
                    )
                }

                Section {
                    ForEach(model.customLinks) { link in
                        HStack {
                            Button {
                                copyAndOpen(
                                    appURL: nil,
                                    webURL: URL(string: link.url)
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(link.title)
                                    Text(link.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(trimmedMessage.isEmpty)

                            Spacer()

                            Button {
                                activeSheet = .link(link)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .accessibilityLabel("\(link.title)を編集")
                        }
                    }

                    if model.customLinks.count < 2 {
                        Button {
                            activeSheet = .link(nil)
                        } label: {
                            Label("独自リンクを追加", systemImage: "plus")
                        }
                    }
                } header: {
                    Text("独自リンク")
                } footer: {
                    Text("よく使う投稿先を2件まで登録できます。")
                }
            }
            .navigationTitle("SNS投稿補助")
            .task { await model.load() }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .share:
                    ActivityShareSheet(activityItems: [trimmedMessage])
                case let .link(link):
                    SnsCustomLinkEditor(
                        existing: link,
                        onSave: { title, url in
                            let didSave = await model.save(
                                existing: link,
                                title: title,
                                url: url
                            )
                            if didSave {
                                activeSheet = nil
                            }
                        },
                        onDelete: link.map { value in
                            {
                                await model.delete(value)
                                activeSheet = nil
                            }
                        }
                    )
                }
            }
            .alert(
                "お知らせ",
                isPresented: Binding(
                    get: { model.notice != nil },
                    set: { if !$0 { model.clearNotice() } }
                )
            ) {
                Button("閉じる") { model.clearNotice() }
            } message: {
                Text(model.notice ?? "")
            }
            .alert(
                "処理できませんでした",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.clearError() } }
                )
            ) {
                Button("閉じる") { model.clearError() }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var xAppURL: URL? {
        guard !trimmedMessage.isEmpty else {
            return URL(string: "twitter://")
        }
        var components = URLComponents(string: "twitter://post")
        components?.queryItems = [URLQueryItem(name: "message", value: trimmedMessage)]
        return components?.url
    }

    private var xWebURL: URL {
        var components = URLComponents(string: "https://x.com/intent/post")!
        if !trimmedMessage.isEmpty {
            components.queryItems = [URLQueryItem(name: "text", value: trimmedMessage)]
        }
        return components.url!
    }

    @ViewBuilder
    private func destinationButton(
        title: String,
        systemImage: String,
        appURL: URL?,
        webURL: URL
    ) -> some View {
        Button {
            copyAndOpen(appURL: appURL, webURL: webURL)
        } label: {
            Label("コピーして\(title)を開く", systemImage: systemImage)
        }
        .disabled(trimmedMessage.isEmpty)
    }

    private func copyMessage() {
        UIPasteboard.general.string = trimmedMessage
        model.showNotice("投稿文章をコピーしました。")
    }

    private func copyAndOpen(appURL: URL?, webURL: URL?) {
        guard let webURL else {
            model.showNotice("リンクを開けませんでした。")
            return
        }
        UIPasteboard.general.string = trimmedMessage
        if let appURL {
            UIApplication.shared.open(appURL) { success in
                if !success {
                    UIApplication.shared.open(webURL)
                }
            }
        } else {
            UIApplication.shared.open(webURL)
        }
    }
}

private struct SnsCustomLinkEditor: View {
    let existing: SnsCustomLink?
    let onSave: (String, String) async -> Void
    let onDelete: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var url: String
    @State private var isSaving = false
    @State private var confirmsDeletion = false

    init(
        existing: SnsCustomLink?,
        onSave: @escaping (String, String) async -> Void,
        onDelete: (() async -> Void)?
    ) {
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: existing?.title ?? "")
        _url = State(initialValue: existing?.url ?? "https://")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("リンク情報") {
                    TextField("リンク名", text: $title)
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if onDelete != nil {
                    Section {
                        Button("独自リンクを削除", role: .destructive) {
                            confirmsDeletion = true
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "独自リンクを追加" : "独自リンクを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        isSaving = true
                        Task {
                            await onSave(title, url)
                            isSaving = false
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .confirmationDialog(
                "この独自リンクを削除しますか？",
                isPresented: $confirmsDeletion,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    if let onDelete {
                        Task { await onDelete() }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}
