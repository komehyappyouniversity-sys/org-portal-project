import SwiftUI

struct SuperAdminFeatureSettingsView: View {
    let organizationId: String

    @StateObject private var store = SuperAdminFeatureStore()

    var body: some View {
        Form {
            Section("対象組織") {
                Text(organizationId)
                    .foregroundColor(.secondary)
            }

            Section("管理アプリで使用できる機能") {
                Toggle("予約機能", isOn: $store.settings.bookingEnabled)
                Toggle("動画管理", isOn: $store.settings.videoEnabled)
                Toggle("有料動画・課金設定", isOn: $store.settings.paidVideoEnabled)
                Toggle("会員へ一斉送信", isOn: $store.settings.messageEnabled)
                Toggle("公開お知らせ送信", isOn: $store.settings.announcementEnabled)
                Toggle("会員投稿一覧", isOn: $store.settings.memberPostEnabled)
                Toggle("カテゴリ管理", isOn: $store.settings.categoryEnabled)
                Toggle("スケジュール管理", isOn: $store.settings.scheduleEnabled)
            }

            Section {
                Button {
                    Task {
                        await store.save(organizationId: organizationId)
                    }
                } label: {
                    if store.isSaving {
                        ProgressView()
                    } else {
                        Text("保存")
                    }
                }
                .disabled(store.isSaving)
            }

            if !store.successMessage.isEmpty {
                Section {
                    Text(store.successMessage)
                        .foregroundColor(.green)
                }
            }

            if !store.errorMessage.isEmpty {
                Section {
                    Text(store.errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("管理機能設定")
        .onAppear {
            store.startListening(organizationId: organizationId)
        }
        .onDisappear {
            store.stopListening()
        }
    }
}
