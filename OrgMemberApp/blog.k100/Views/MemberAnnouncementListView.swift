//
//  MemberAnnouncementListView.swift
//  ictnagaoka
//
//  Created by 根津浩 on 2026/04/19.
//

import SwiftUI

struct MemberAnnouncementListView: View {
    @EnvironmentObject private var organizationStore: OrganizationStore
    @StateObject private var store = MemberAnnouncementStore()

    var body: some View {
        Group {
            if store.isLoading && store.items.isEmpty {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !store.errorMessage.isEmpty {
                VStack(spacing: 16) {
                    Text("読み込みに失敗しました")
                        .font(.headline)

                    Text(store.errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)

                    Button("再読み込み") {
                        store.startListening(
                            organizationId: organizationStore.organizationId
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.items.isEmpty {
                VStack(spacing: 16) {
                    Text("公開お知らせはまだありません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.items) { item in
                    NavigationLink {
                        MemberAnnouncementDetailView(item: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(item.body)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)

                            if let createdAt = item.createdAt {
                                Text(dateText(createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("公開お知らせ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.startListening(
                organizationId: organizationStore.organizationId
            )
        }
        .onDisappear {
            store.stopListening()
        }
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct MemberAnnouncementDetailView: View {
    let item: MemberAnnouncementItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.title2.bold())

                if let createdAt = item.createdAt {
                    Text(dateText(createdAt))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Divider()

                Text(item.body)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .navigationTitle("お知らせ詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
