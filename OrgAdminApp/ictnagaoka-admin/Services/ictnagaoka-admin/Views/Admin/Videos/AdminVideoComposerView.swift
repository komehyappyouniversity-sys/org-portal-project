import SwiftUI

struct AdminVideoComposerView: View {
    @EnvironmentObject var organizationStore: OrganizationStore

    @StateObject private var store = AdminVideoStore()

    @State private var title = ""
    @State private var url = ""
    @State private var isPremium = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                formSection
                registeredVideosSection
            }
            .padding(20)
        }
        .navigationTitle("動画登録")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.startListening(
                organizationId: organizationStore.organization.id
            )
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("動画コンテンツ登録")
                .font(.title3.bold())

            TextField("タイトル", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("動画URL（Vimeo / YouTube / mp4）", text: $url)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Toggle("会員限定動画にする", isOn: $isPremium)

            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            if !store.successMessage.isEmpty {
                Text(store.successMessage)
                    .foregroundColor(.green)
                    .font(.footnote)
            }

            Button {
                Task {
                    await store.addVideo(
                        organizationId: organizationStore.organization.id,
                        title: title,
                        url: url,
                        isPublished: true,
                        isPremium: isPremium
                    )

                    if store.errorMessage.isEmpty {
                        title = ""
                        url = ""
                        isPremium = false
                    }
                }
            } label: {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("動画を登録")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isLoading)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var registeredVideosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("登録済み動画")
                .font(.title3.bold())

            if store.videos.isEmpty {
                Text("まだ動画が登録されていません。")
                    .foregroundColor(.gray)
            } else {
                ForEach(store.videos) { video in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(video.title)
                                .font(.headline)

                            Spacer()

                            if video.isPremium {
                                Text("会員限定")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }

                        Text(video.url)
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .lineLimit(2)

                        Button(role: .destructive) {
                            Task {
                                await store.deleteVideo(
                                    organizationId: organizationStore.organization.id,
                                    videoId: video.id
                                )
                            }
                        } label: {
                            Text("削除")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
}
