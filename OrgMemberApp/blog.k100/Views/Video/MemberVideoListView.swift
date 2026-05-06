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

    @State private var purchaseMessage: String = ""

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
        .onChange(of: store.videos) { videos in
            loadProducts(from: videos)
        }
    }

    // MARK: - 初期処理

    private func start() {
        store.startListening(
            organizationId: organizationStore.organization.id
        )

        Task {
            await purchaseStore.updatePurchasedProducts()
        }
    }

    private func loadProducts(from videos: [MemberVideoItem]) {
        let productIds = videos
            .map { $0.productId }
            .filter { !$0.isEmpty }

        Task {
            await purchaseStore.loadProducts(productIds: productIds)
        }
    }

    // MARK: - 行UI

    private func videoRow(_ video: MemberVideoItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .top, spacing: 12) {
                thumbnailView(video)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(video.title)
                            .font(.headline)
                            .lineLimit(2)

                        Spacer()

                        if video.isPremium && !video.displayPriceText.isEmpty {
                            Text(video.displayPriceText)
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        }
                    }

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

            actionButton(video)

            if !purchaseMessage.isEmpty {
                Text(purchaseMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - ボタン

    @ViewBuilder
    private func actionButton(_ video: MemberVideoItem) -> some View {
        if !video.isPremium {
            NavigationLink {
                MemberVideoPlayerView(video: video)
            } label: {
                playButtonLabel("再生する")
            }

        } else if purchaseStore.isPurchased(productId: video.productId) {
            NavigationLink {
                MemberVideoPlayerView(video: video)
            } label: {
                playButtonLabel("購入済み・再生する")
            }

        } else {
            Button {
                purchase(video)
            } label: {
                purchaseButtonLabel(video)
            }
        }
    }

    private func purchase(_ video: MemberVideoItem) {
        purchaseMessage = ""

        Task {
            if let product = purchaseStore.products.first(where: { $0.id == video.productId }) {
                await purchaseStore.purchase(product: product)
                await purchaseStore.updatePurchasedProducts()
            } else {
                purchaseMessage = "商品情報を取得できませんでした。App Store Connectの商品IDを確認してください。"
                print("❌ StoreKit商品が見つかりません:", video.productId)
                print("現在取得済み products:", purchaseStore.products.map { $0.id })
            }
        }
    }

    private func playButtonLabel(_ text: String) -> some View {
        HStack {
            Image(systemName: "play.fill")
            Text(text)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Color.blue)
        .cornerRadius(12)
    }

    private func purchaseButtonLabel(_ video: MemberVideoItem) -> some View {
        HStack {
            Image(systemName: "cart.fill")

            if !video.displayPriceText.isEmpty {
                Text("\(video.displayPriceText)で購入")
                    .fontWeight(.bold)
            } else {
                Text("購入する")
                    .fontWeight(.bold)
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Color.orange)
        .cornerRadius(12)
    }

    // MARK: - サムネイル

    private func thumbnailView(_ video: MemberVideoItem) -> some View {
        Group {
            if let url = URL(string: video.thumbnailUrl), !video.thumbnailUrl.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Color(.systemGray5)
                            ProgressView()
                        }

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
                .font(.title2)
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
        VStack(spacing: 12) {
            ProgressView()
            Text("動画を読み込み中...")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Text("動画を読み込めませんでした")
                .font(.headline)

            Text(store.errorMessage)
                .font(.footnote)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("公開中の動画はありません")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
