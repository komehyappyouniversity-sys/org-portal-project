//
//  DiaryView.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/19.
//

import SwiftUI

struct DiaryView: View {
    @EnvironmentObject var memberStore: MemberStore
    @EnvironmentObject var organizationStore: OrganizationStore

    @StateObject private var store = DiaryStore()
    @State private var showCreateView = false

    var body: some View {
        Group {
            if store.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("日記を読み込んでいます...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let errorMessage = store.errorMessage, !errorMessage.isEmpty {
                VStack(spacing: 16) {
                    Text("日記")
                        .font(.largeTitle.bold())

                    Text("読み込みに失敗しました")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("再読み込み") {
                        reload()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if store.entries.isEmpty {
                VStack(spacing: 16) {
                    Text("日記")
                        .font(.largeTitle.bold())

                    Text("日記はまだ登録されていません。")
                        .foregroundStyle(.secondary)

                    Button {
                        showCreateView = true
                    } label: {
                        Text("日記を書く")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 180, height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.blue)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                List {
                    ForEach(store.entries) { entry in
                        NavigationLink {
                            DiaryDetailView(store: store, entry: entry)
                                .environmentObject(memberStore)
                                .environmentObject(organizationStore)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(dateText(entry.date))
                                    .font(.headline)

                                if !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(entry.title)
                                        .font(.title3.bold())
                                }

                                if !entry.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(entry.body)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(4)
                                }

                                DiaryImageRowView(imageUrls: entry.imageUrls)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(.systemGray6))
        .navigationTitle("日記")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateView = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showCreateView) {
            NavigationStack {
                DiaryCreateView(store: store)
                    .environmentObject(memberStore)
                    .environmentObject(organizationStore)
            }
        }
        .onAppear {
            reload()
        }
        .onDisappear {
            store.stopListening()
        }
    }

    private func reload() {
        guard let uid = memberStore.authUid, !uid.isEmpty else {
            store.errorMessage = "ユーザー情報を取得できませんでした。"
            store.entries = []
            store.isLoading = false
            return
        }

        let organizationId = organizationStore.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
            ? OrganizationConfig.organizationId
            : organizationStore.organizationId

        guard !organizationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            store.errorMessage = "organizationId を取得できませんでした。"
            store.entries = []
            store.isLoading = false
            return
        }

        store.startListening(
            organizationId: organizationId,
            uid: uid
        )
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter.string(from: date)
    }
}
