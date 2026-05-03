//
//  AdminVimeoVideoListView.swift
//  ictnagaoka-admin
//

import SwiftUI

enum AdminVideoCategory: String, CaseIterable, Identifiable {
    case basic = "基本"
    case practice = "実技"
    case lecture = "講義"
    case other = "その他"

    var id: String { rawValue }
}

struct AdminVimeoVideoListView: View {
    @EnvironmentObject private var organizationStore: OrganizationStore
    @StateObject private var store = AdminVimeoVideoStore()

    @State private var showResultAlert = false
    @State private var resultMessage = ""

    @State private var selectedFilterCategory = "すべて"
    @State private var selectedPublishFilter = "すべて"
    @State private var searchText = ""

    private var organizationId: String {
        let fromStore = organizationStore.organization.id
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !fromStore.isEmpty {
            return fromStore
        }

        return OrganizationConfig.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filterCategories: [String] {
        ["すべて"] + AdminVideoCategory.allCases.map(\.rawValue)
    }

    private var publishFilters: [String] {
        ["すべて", "公開中", "非公開", "未登録"]
    }

    private var filteredVideos: [AdminVimeoVideo] {
        store.videos.filter { video in
            let registered = store.registeredVideo(for: video)

            let matchesCategory: Bool = {
                if selectedFilterCategory == "すべて" {
                    return true
                }
                return registered?.category == selectedFilterCategory
            }()

            let matchesPublish: Bool = {
                switch selectedPublishFilter {
                case "すべて":
                    return true
                case "公開中":
                    return registered?.isPublished == true
                case "非公開":
                    return registered?.isPublished == false && registered != nil
                case "未登録":
                    return registered == nil
                default:
                    return true
                }
            }()

            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return matchesCategory && matchesPublish
            }

            let keyword = trimmed.lowercased()
            let matchesSearch =
                video.name.lowercased().contains(keyword) ||
                video.description.lowercased().contains(keyword) ||
                video.vimeoVideoId.lowercased().contains(keyword)

            return matchesCategory && matchesPublish && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if organizationId.isEmpty {
                    VStack(spacing: 12) {
                        Text("organizationId が取得できません")
                            .font(.headline)
                            .foregroundStyle(.red)

                        Text("OrganizationStore または OrganizationConfig を確認してください。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                } else if store.isLoading {
                    ProgressView("Vimeo動画を読み込み中...")

                } else if let errorMessage = store.errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)

                        Button("再試行") {
                            store.loadVideos(organizationId: organizationId)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()

                } else if store.videos.isEmpty {
                    VStack(spacing: 10) {
                        Text("動画が見つかりません")
                            .font(.headline)

                        Text("Vimeoに動画があるか、Cloud Functionsの取得結果を確認してください。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("再読込") {
                            store.loadVideos(organizationId: organizationId)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()

                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            filterSection

                            if filteredVideos.isEmpty {
                                VStack(spacing: 10) {
                                    Text("該当する動画がありません")
                                        .font(.headline)

                                    Text("絞り込み条件を変更するか、検索文字を見直してください。")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)

                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(filteredVideos) { video in
                                        AdminVimeoVideoRowView(
                                            video: video,
                                            registeredVideo: store.registeredVideo(for: video),
                                            isSaving: store.savingVideoIds.contains(video.id),
                                            onRegister: { category, isPremium, isPublished in
                                                store.registerToFirestore(
                                                    organizationId: organizationId,
                                                    video: video,
                                                    category: category,
                                                    isPremium: isPremium,
                                                    isPublished: isPublished
                                                ) { result in
                                                    switch result {
                                                    case .success:
                                                        resultMessage = "「\(video.name)」を登録しました。"
                                                        showResultAlert = true

                                                    case .failure(let error):
                                                        resultMessage = "登録に失敗しました: \(error.localizedDescription)"
                                                        showResultAlert = true
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Vimeo動画一覧")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("再読込") {
                        store.loadVideos(organizationId: organizationId)
                    }
                    .disabled(organizationId.isEmpty)
                }
            }
            .onAppear {
                if store.videos.isEmpty && !organizationId.isEmpty {
                    store.loadVideos(organizationId: organizationId)
                }
            }
            .alert("結果", isPresented: $showResultAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(resultMessage)
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("保存先: organizations/\(organizationId)/videos")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("絞り込み")
                .font(.headline)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("タイトル・説明・Vimeo IDで検索", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 8) {
                Text("カテゴリ")
                    .font(.subheadline.weight(.semibold))

                Picker("カテゴリ", selection: $selectedFilterCategory) {
                    ForEach(filterCategories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("公開状態")
                    .font(.subheadline.weight(.semibold))

                Picker("公開状態", selection: $selectedPublishFilter) {
                    ForEach(publishFilters, id: \.self) { filter in
                        Text(filter).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }

            Text("表示件数: \(filteredVideos.count)件")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct AdminVimeoVideoRowView: View {
    let video: AdminVimeoVideo
    let registeredVideo: AdminRegisteredVideo?
    let isSaving: Bool
    let onRegister: (_ category: String, _ isPremium: Bool, _ isPublished: Bool) -> Void

    @State private var selectedCategory: String
    @State private var isPremium: Bool
    @State private var isPublished: Bool

    init(
        video: AdminVimeoVideo,
        registeredVideo: AdminRegisteredVideo?,
        isSaving: Bool,
        onRegister: @escaping (_ category: String, _ isPremium: Bool, _ isPublished: Bool) -> Void
    ) {
        self.video = video
        self.registeredVideo = registeredVideo
        self.isSaving = isSaving
        self.onRegister = onRegister

        _selectedCategory = State(initialValue: registeredVideo?.category ?? AdminVideoCategory.basic.rawValue)
        _isPremium = State(initialValue: registeredVideo?.isPremium ?? false)
        _isPublished = State(initialValue: registeredVideo?.isPublished ?? true)
    }

    private var categories: [String] {
        AdminVideoCategory.allCases.map(\.rawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(video.name)
                .font(.headline)

            if !video.description.isEmpty {
                Text(video.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack {
                Text("Vimeo ID")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(video.vimeoVideoId.isEmpty ? "未取得" : video.vimeoVideoId)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            if let registeredVideo {
                Text("登録済み：\(registeredVideo.category) / \(registeredVideo.isPublished ? "公開中" : "非公開")")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("未登録")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Picker("カテゴリ", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)

            Toggle("有料動画", isOn: $isPremium)
            Toggle("公開する", isOn: $isPublished)

            Button {
                onRegister(selectedCategory, isPremium, isPublished)
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(registeredVideo == nil ? "Firestoreに登録" : "設定を更新")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
