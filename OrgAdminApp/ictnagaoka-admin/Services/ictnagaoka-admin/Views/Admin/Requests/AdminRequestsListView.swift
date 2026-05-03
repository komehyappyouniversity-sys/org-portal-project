import SwiftUI

struct AdminRequestsListView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @StateObject private var store = AdminRequestsStore()

    var body: some View {
        VStack {
            if organizationStore.organizationId.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)

                    Text("organizationId がありません")
                        .font(.headline)

                    Text("組織情報を取得できていないため、会員申請一覧を表示できません。")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    Button("再読み込み") {
                        organizationStore.startListening(
                            organizationId: OrganizationConfig.organizationId
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

            } else if store.isLoading {
                VStack(spacing: 12) {
                    ProgressView("読み込み中...")
                    Text("organizationId: \(organizationStore.organizationId)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()

            } else if !store.errorMessage.isEmpty {
                VStack(spacing: 12) {
                    Text(store.errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)

                    Text("organizationId: \(organizationStore.organizationId)")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button("再読み込み") {
                        store.startListening(
                            organizationId: organizationStore.organizationId
                        )
                    }
                    .buttonStyle(.bordered)
                }
                .padding()

            } else if store.requests.isEmpty {
                VStack(spacing: 12) {
                    Text("申請はありません")
                        .foregroundColor(.gray)

                    Text("organizationId: \(organizationStore.organizationId)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()

            } else {
                List(store.requests) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.headline)

                        if !item.email.isEmpty {
                            Text(item.email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        if !item.phone.isEmpty {
                            Text(item.phone)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("会員申請一覧")
        .onAppear {
            print("📌 AdminRequestsListView organizationId:", organizationStore.organizationId)

            if organizationStore.organizationId.isEmpty {
                organizationStore.startListening(
                    organizationId: OrganizationConfig.organizationId
                )
            }

            if !organizationStore.organizationId.isEmpty {
                store.startListening(
                    organizationId: organizationStore.organizationId
                )
            }
        }
        .onChange(of: organizationStore.organizationId) { _, newValue in
            let safeId = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !safeId.isEmpty else { return }

            print("📌 organizationId changed:", safeId)
            store.startListening(organizationId: safeId)
        }
        .onDisappear {
            store.stopListening()
        }
    }
}
