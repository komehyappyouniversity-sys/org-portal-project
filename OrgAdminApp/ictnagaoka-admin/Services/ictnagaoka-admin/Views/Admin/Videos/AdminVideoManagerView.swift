//
//  AdminVideoManagerView.swift
//  ictnagaoka-admin
//

import SwiftUI

struct AdminVideoManagerView: View {
    @EnvironmentObject var organizationStore: OrganizationStore

    @StateObject private var store = AdminVideoStore()

    @State private var title: String = ""
    @State private var url: String = ""
    @State private var isPublished: Bool = true
    @State private var isPremium: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                formSection
                messageSection
                listSection
            }
            .padding(20)
        }
        .navigationTitle("動画管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.startListening(
                organizationId: organizationStore.organization.id
            )
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("動画を登録")
                .font(.title3.bold())

            TextField("動画タイトル", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Vimeo / YouTube / mp4 URL", text: $url)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Toggle("公開する", isOn: $isPublished)

            Toggle("有料動画にする", isOn: $isPremium)

            Button {
                Task {
                    await store.addVideo(
                        organizationId: organizationStore.organization.id,
                        title: title,
                        url: url,
                        isPublished: isPublished,
                        isPremium: isPremium
                    )

                    if store.errorMessage.isEmpty {
                        title = ""
                        url = ""
                        isPublished = true
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

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        }
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("登録済み動画")
                .font(.title3.bold())

            if store.videos.isEmpty {
                Text("まだ動画が登録されていません。")
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            } else {
                ForEach(store.videos) { video in
                    videoCard(video)
                }
            }
        }
    }

    private func videoCard(_ video: AdminVideoItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.headline)

                    if !video.url.isEmpty {
                        Text(video.url)
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .lineLimit(2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    statusBadge(
                        text: video.isPublished ? "公開" : "非公開",
                        color: video.isPublished ? .green : .gray
                    )

                    statusBadge(
                        text: video.isPremium ? "有料" : "無料",
                        color: video.isPremium ? .orange : .blue
                    )
                }
            }

            Divider()

            Toggle("公開する", isOn: Binding(
                get: { video.isPublished },
                set: { newValue in
                    Task {
                        await store.updatePublished(
                            organizationId: organizationStore.organization.id,
                            videoId: video.id,
                            isPublished: newValue
                        )
                    }
                }
            ))

            Toggle("有料動画にする", isOn: Binding(
                get: { video.isPremium },
                set: { newValue in
                    Task {
                        await store.updatePremium(
                            organizationId: organizationStore.organization.id,
                            videoId: video.id,
                            isPremium: newValue
                        )
                    }
                }
            ))

            HStack {
                Button {
                    openURL(video.url)
                } label: {
                    Label("確認", systemImage: "play.circle")
                }
                .buttonStyle(.bordered)
                .disabled(video.url.isEmpty)

                Spacer()

                Button(role: .destructive) {
                    Task {
                        await store.deleteVideo(
                            organizationId: organizationStore.organization.id,
                            videoId: video.id
                        )
                    }
                } label: {
                    Label("削除", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}
