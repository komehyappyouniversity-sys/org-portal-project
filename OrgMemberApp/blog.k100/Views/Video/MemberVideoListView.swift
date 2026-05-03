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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(video.title)
                    .font(.headline)

                Spacer()

                if video.isPremium {
                    Text("有料")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)
                } else {
                    Text("無料")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                }
            }

            if video.isPremium {
                Text("有料会員のみ再生できます")
                    .font(.footnote)
                    .foregroundColor(.gray)
            } else {
                Button {
                    openVideo(urlString: video.url)
                } label: {
                    Label("再生する", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 8)
    }

    private func openVideo(urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ 不正な動画URL:", urlString)
            return
        }

        UIApplication.shared.open(url)
    }
}
