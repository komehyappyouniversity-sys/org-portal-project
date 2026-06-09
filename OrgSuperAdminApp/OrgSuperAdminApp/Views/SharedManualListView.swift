import SwiftUI

struct SharedManualListView: View {

    @StateObject private var store = SharedManualStore()

    @State private var showNewManual = false
    @State private var showImportConfirmation = false
    @State private var isImportingInitialData = false
    @State private var manualToDelete: SharedManualItem?

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
            }

            if !store.errorMessage.isEmpty {
                Section {
                    Text(store.errorMessage)
                        .foregroundColor(.red)
                }
            }

            if !store.importMessage.isEmpty {
                Section {
                    Text(store.importMessage)
                        .foregroundColor(.green)
                }
            }

            if store.manuals.isEmpty && !store.isLoading {
                Section {
                    Text("共通マニュアルはまだ登録されていません。")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button {
                    showImportConfirmation = true
                } label: {
                    Label(
                        isImportingInitialData ? "登録中..." : "初期データを一括登録",
                        systemImage: "square.and.arrow.down"
                    )
                }
                .disabled(isImportingInitialData)

                Text("同じ初期データIDのマニュアルがある場合は、内容を上書きします。画像は添付枠として登録されます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("初期データ")
            }

            Section("共通マニュアル") {
                ForEach(store.manuals) { manual in
                    NavigationLink {
                        SharedManualEditView(
                            store: store,
                            manual: manual
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {

                            HStack(alignment: .top) {
                                Text("\(manual.sortOrder). \(manual.title)")
                                    .font(.headline)

                                Spacer()

                                Text(manual.isPublished ? "公開中" : "非公開")
                                    .font(.caption)
                                    .foregroundColor(
                                        manual.isPublished ? .green : .secondary
                                    )
                            }

                            Text(manual.body)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)

                            if !manual.attachments.isEmpty {
                                HStack(spacing: 10) {
                                    Label(
                                        "\(manual.attachments.count)件の添付",
                                        systemImage: "paperclip"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.blue)

                                    ForEach(attachmentTypeSummaries(for: manual), id: \.self) { summary in
                                        Text(summary)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.gray.opacity(0.12))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        manualToDelete = store.manuals[index]
                    }
                }
            }
        }
        .navigationTitle("共通マニュアル管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewManual = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewManual) {
            NavigationStack {
                SharedManualEditView(
                    store: store,
                    manual: nil
                )
            }
        }
        .alert(
            "初期データを登録しますか？",
            isPresented: $showImportConfirmation
        ) {
            Button("キャンセル", role: .cancel) {}

            Button("登録") {
                importInitialData()
            }
        } message: {
            Text("共通マニュアル初期データ8件を保存します。同じIDのデータは上書きされます。")
        }
        .alert(
            "削除しますか？",
            isPresented: Binding(
                get: { manualToDelete != nil },
                set: { if !$0 { manualToDelete = nil } }
            )
        ) {
            Button("キャンセル", role: .cancel) {
                manualToDelete = nil
            }

            Button("削除", role: .destructive) {
                if let manual = manualToDelete {
                    Task {
                        await store.deleteManual(manual)
                        manualToDelete = nil
                    }
                }
            }
        } message: {
            Text("この共通マニュアルを削除します。")
        }
        .onAppear {
            store.startListening()
        }
        .onDisappear {
            store.stopListening()
        }
    }

    private func importInitialData() {
        isImportingInitialData = true

        Task {
            await store.importInitialManuals()
            isImportingInitialData = false
        }
    }

    private func attachmentTypeSummaries(
        for manual: SharedManualItem
    ) -> [String] {

        let imageCount = manual.attachments.filter {
            $0.type == "image"
        }.count

        let pdfCount = manual.attachments.filter {
            $0.type == "pdf"
        }.count

        let urlCount = manual.attachments.filter {
            $0.type == "url"
        }.count

        var summaries: [String] = []

        if imageCount > 0 {
            summaries.append("画像 \(imageCount)")
        }

        if pdfCount > 0 {
            summaries.append("PDF \(pdfCount)")
        }

        if urlCount > 0 {
            summaries.append("URL \(urlCount)")
        }

        return summaries
    }
}
