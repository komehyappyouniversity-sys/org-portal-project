//
//  MemberVideoListView.swift
//  blog.k100
//

import SwiftUI
import StoreKit

struct MemberVideoListView: View {
    @EnvironmentObject var organizationStore: OrganizationStore

    @StateObject private var store = MemberVideoStore()
    @StateObject private var purchaseStore = VideoPurchaseStore()

    var body: some View {
        Group {
            if store.isLoading {
                loadingView

            } else if !store.errorMessage.isEmpty {
                errorView

            } else if store.videos.isEmpty {
                emptyView

            } else {
                List {
                    ForEach(store.videos) { video in
                        videoRow(video)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("動画コンテンツ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            start()
        }
    }

    // MARK: - 初期処理

    private func start() {
        store.startListening(
            organizationId: organizationStore.organization.id
        )

        Task {
            await purchaseStore.updatePurchasedProducts()

            let productIds = store.videos
                .map { $0.productId }
                .filter { !$0.isEmpty }

            await purchaseStore.loadProducts(productIds: productIds)
        }
    }

    // MARK: - 行UI

    private func videoRow(_ video: MemberVideoItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .top, spacing: 12) {

                thumbnailView(video)

                VStack(alignment: .leading, spacing: 8) {

                    // タイトル + 価格
                    HStack(alignment: .top) {
                        Text(video.title)
                            .font(.headline)
                            .lineLimit(2)

                        Spacer()

                        if video.isPremium && !video.displayPriceText.isEmpty {
                            Text(video.displayPriceText)
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                        }
                    }

                    // バッジ
                    HStack(spacing: 8) {
                        if video.isMembersOnly {
                            badge("会員限定", .blue)
                        }

                        if video.isPremium {
                            badge("有料", .orange)
                        } else {
                            badge("無料", .green)
                        }
                    }
                }

                Spacer()
            }

            // ボタン（ここが重要）
            actionButton(video)
        }
        .padding(.vertical, 8)
    }

    // MARK: - ボタン制御

    private func actionButton(_ video: MemberVideoItem) -> some View {

        // 無料動画
        if !video.isPremium {
            return AnyView(
                NavigationLink {
                    MemberVideoPlayerView(video: video)
                } label: {
                    Label("再生する", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            )
        }

        // 有料動画
        if purchaseStore.isPurchased(productId: video.productId) {
            return AnyView(
                NavigationLink {
                    MemberVideoPlayerView(video: video)
                } label: {
                    Label("再生する", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            )
        }

        // 未購入
        return AnyView(
            Button {
                Task {
                    if let product = purchaseStore.products.first(where: {
                        $0.id == video.productId
                    }) {
                        await purchaseStore.purchase(product: product)
                    }
                }
            } label: {
                Text("購入する")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        )
    }

    // MARK: - サムネイル

    private func thumbnailView(_ video: MemberVideoItem) -> some View {
        Group {
            if let url = URL(string: video.thumbnailUrl), !video.thumbnailUrl.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()

                    case .failure:
                        placeholderThumbnail

                    @unknown default:
                        placeholderThumbnail
                    }
                }
            } else {
                placeholderThumbnail
            }
        }
        .frame(width: 110, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholderThumbnail: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "play.rectangle.fill")
                .foregroundColor(.gray)
        }
    }

    // MARK: - 共通UI

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("動画を読み込み中...")
        }
    }

    private var errorView: some View {
        VStack {
            Text("読み込み失敗")
            Text(store.errorMessage)
        }
    }

    private var emptyView: some View {
        VStack {
            Image(systemName: "play.rectangle")
            Text("動画がありません")
        }
    }
}
