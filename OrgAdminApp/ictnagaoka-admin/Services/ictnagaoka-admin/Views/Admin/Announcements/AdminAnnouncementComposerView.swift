//
//  AdminAnnouncementComposerView.swift
//  ictnagaoka-admin
//

import SwiftUI

struct AdminAnnouncementComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var organizationStore: OrganizationStore
    @StateObject private var store = AdminAnnouncementStore()

    @State private var showSuccessAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                Text("タイトル")
                    .font(.headline)

                TextField("タイトルを入力", text: $store.title)
                    .textFieldStyle(.roundedBorder)

                Text("本文")
                    .font(.headline)

                TextEditor(text: $store.body)
                    .frame(minHeight: 220)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("保存先: organizations/\(organizationId)/messages")
                    Text("visibility: public")
                }
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

                Button {
                    Task {
                        let didSend = await store.sendAnnouncement(
                            organizationId: organizationId
                        )

                        if didSend {
                            showSuccessAlert = true
                        }
                    }
                } label: {
                    HStack {
                        Spacer()

                        if store.isSaving {
                            ProgressView()
                        } else {
                            Text("公開お知らせを送信")
                                .font(.headline)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    store.isSaving ||
                    organizationId.isEmpty ||
                    store.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    store.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            .padding(20)
        }
        .navigationTitle("公開お知らせ送信")
        .navigationBarTitleDisplayMode(.inline)
        .alert("送信しました", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("公開お知らせを messages に保存しました。")
        }
    }

    private var organizationId: String {
        organizationStore.organization.id
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
