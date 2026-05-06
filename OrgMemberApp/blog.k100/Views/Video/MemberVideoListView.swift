//
//  MemberVideoListView.swift
//  blog.k100
//

import SwiftUI

struct MemberVideoListView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @StateObject private var store = MemberVideoStore()

    var body: some View {
        Group {
            if store.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("動画を読み込み中...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if !store.errorMessage.isEmpty {
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

            } else if store.videos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("公開中の動画はありません")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            store.startListening(
                organizationId: organizationStore.organization.id
            )
        }
    }

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
                            badge(
                                text: "会員限定",
                                foreground: .blue,
                                background: Color.blue.opacity(0.15)
                            )
                        }

                        if video.isPremium {
                            badge(
                                text: "有料",
                                foreground: .orange,
                                background: Color.orange.opacity(0.15)
                            )
                        } else {
                            badge(
                                text: "無料",
                                foreground: .green,
                                background: Color.green.opacity(0.15)
                            )
                        }
                    }
                }

                Spacer()
            }

            if !video.isPremium {
                Button {
                    openVideo(urlString: video.playURL)
                } label: {
                    Label("再生する", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 8)
    }

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

    private func badge(
        text: String,
        foreground: Color,
        background: Color
    ) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .cornerRadius(8)
    }

    private func openVideo(urlString: String) {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            print("❌ 不正な動画URL:", urlString)
            return
        }

        UIApplication.shared.open(url)
    }
}
