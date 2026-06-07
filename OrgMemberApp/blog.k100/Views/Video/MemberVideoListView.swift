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

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var sortedVideos: [MemberVideoItem] {
        store.videos.sorted { first, second in
            let firstNumber = extractNumber(from: first.title)
            let secondNumber = extractNumber(from: second.title)

            switch (firstNumber, secondNumber) {
            case let (first?, second?):
                return first < second
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return first.title < second.title
            }
        }
    }

    var body: some View {
        Group {
            if store.isLoading {
                loadingView

            } else if !store.errorMessage.isEmpty {
                errorView

            } else if store.videos.isEmpty {
                emptyView

            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(sortedVideos) { video in
                            videoCard(video)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
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
            organizationId: organizationStore.organizationId
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

    // MARK: - カードUI

    private func videoCard(_ video: MemberVideoItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            thumbnailView(video)

            Text(video.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 66, alignment: .top)

            HStack(spacing: 6) {
                if video.isMembersOnly {
                    badge("会員限定", .blue)
                }

                if video.isPremium {
                    badge("有料", .orange)
                } else {
                    badge("無料", .green)
                }
            }

            if video.isPremium && !video.displayPriceText.isEmpty {
                Text(video.displayPriceText)
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
            }

            Spacer(minLength: 0)

            actionButton(video)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300, alignment: .top)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 6,
            x: 0,
            y: 3
        )
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
                playButtonLabel("購入済み・再生")
            }

        } else if let product = product(for: video) {

            Button {
                purchase(product)
            } label: {
                purchaseButtonLabel(video)
            }

        } else {

            preparingButtonLabel()
        }
    }

    private func product(for video: MemberVideoItem) -> Product? {
        purchaseStore.products.first {
            $0.id == video.productId
        }
    }

    private func purchase(_ product: Product) {
        Task {
            await purchaseStore.purchase(product: product)
            await purchaseStore.updatePurchasedProducts()
        }
    }

    private func playButtonLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "play.fill")

            Text(text)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(Color.blue)
        .cornerRadius(12)
    }

    private func purchaseButtonLabel(_ video: MemberVideoItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "cart.fill")

            if !video.displayPriceText.isEmpty {
                Text("\(video.displayPriceText)で購入")
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } else {
                Text("購入する")
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(Color.orange)
        .cornerRadius(12)
    }

    private func preparingButtonLabel() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")

            Text("購入準備中")
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(Color.gray.opacity(0.65))
        .cornerRadius(12)
    }

    // MARK: - サムネイル

    private func thumbnailView(_ video: MemberVideoItem) -> some View {
        ZStack {
            Color(.systemGray6)

            if let url = URL(string: video.thumbnailUrl),
               !video.thumbnailUrl.isEmpty {

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()

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
        .frame(maxWidth: .infinity)
        .frame(height: 115)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var placeholderThumbnail: some View {
        Image(systemName: "play.rectangle.fill")
            .font(.title2)
            .foregroundColor(.gray)
    }

    // MARK: - 並び順

    private func extractNumber(from title: String) -> Int? {
        let circledNumbers: [Character: Int] = [
            "①": 1,
            "②": 2,
            "③": 3,
            "④": 4,
            "⑤": 5,
            "⑥": 6,
            "⑦": 7,
            "⑧": 8,
            "⑨": 9,
            "⑩": 10,
            "⑪": 11,
            "⑫": 12,
            "⑬": 13,
            "⑭": 14,
            "⑮": 15,
            "⑯": 16,
            "⑰": 17,
            "⑱": 18,
            "⑲": 19,
            "⑳": 20
        ]

        for character in title {
            if let number = circledNumbers[character] {
                return number
            }
        }

        let numberText = title.prefix {
            $0.isNumber
        }

        return Int(numberText)
    }

    // MARK: - 共通UI

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
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
