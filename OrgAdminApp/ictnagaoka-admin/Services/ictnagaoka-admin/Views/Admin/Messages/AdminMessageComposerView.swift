//
//  AdminMessageComposerView.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/16.
//

import SwiftUI

struct AdminMessageComposerView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @StateObject private var store = AdminMessageComposerStore()

    @State private var showSuccessAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                targetSection
                titleSection
                bodySection
                statusSection
                sendButtonSection
            }
            .padding(20)
        }
        .navigationTitle("会員へメッセージ送信")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !organizationStore.organizationId
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty {
                Task {
                    await store.loadMembers(
                        organizationId: organizationStore.organizationId
                    )
                }
            }
        }
        .alert("送信完了", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("会員へメッセージを送信しました。")
        }
    }

    // MARK: - Sections

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("送信先")
                .font(.headline)

            Picker("送信方法", selection: $store.targetType) {
                ForEach(AdminMessageTargetType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)

            switch store.targetType {
            case .approvedMembersOnly:
                Text("承認済み会員全員に送信します。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

            case .categoryMembers:
                VStack(alignment: .leading, spacing: 8) {
                    Text("カテゴリを選択")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if store.availableCategories.isEmpty {
                        Text("カテゴリがまだありません。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(store.availableCategories, id: \.self) { category in
                            Button {
                                if store.selectedCategories.contains(category) {
                                    store.selectedCategories.remove(category)
                                } else {
                                    store.selectedCategories.insert(category)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: store.selectedCategories.contains(category) ? "checkmark.square.fill" : "square")
                                    Text(category)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

            case .individual:
                VStack(alignment: .leading, spacing: 8) {
                    Text("送信先会員を選択")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if store.isLoadingMembers {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("会員一覧を読み込み中...")
                                .foregroundColor(.secondary)
                        }
                    } else if store.members.isEmpty {
                        Text("送信対象会員がいません。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(store.members) { member in
                            Button {
                                if store.selectedMemberUIDs.contains(member.uid) {
                                    store.selectedMemberUIDs.remove(member.uid)
                                } else {
                                    store.selectedMemberUIDs.insert(member.uid)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: store.selectedMemberUIDs.contains(member.uid) ? "checkmark.square.fill" : "square")
                                    Text(member.name.isEmpty ? member.uid : member.name)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タイトル")
                .font(.headline)

            TextField("タイトルを入力", text: $store.title)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本文")
                .font(.headline)

            TextEditor(text: $store.body)
                .frame(minHeight: 220)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("organizationId: \(organizationStore.organizationId)")
                .font(.footnote)
                .foregroundColor(.secondary)

            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
            }

            if !store.successMessage.isEmpty {
                Text(store.successMessage)
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
    }

    private var sendButtonSection: some View {
        Button {
            Task {
                let didSend = await store.sendMessage(
                    organizationId: organizationStore.organizationId
                )
                if didSend {
                    showSuccessAlert = true
                }
            }
        } label: {
            HStack {
                Spacer()

                if store.isSending {
                    ProgressView()
                } else {
                    Text("送信する")
                        .font(.headline)
                }

                Spacer()
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .disabled(
            store.isSending ||
            organizationStore.organizationId
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        )
    }
}

#Preview {
    NavigationStack {
        AdminMessageComposerView()
            .environmentObject(OrganizationStore())
    }
}
