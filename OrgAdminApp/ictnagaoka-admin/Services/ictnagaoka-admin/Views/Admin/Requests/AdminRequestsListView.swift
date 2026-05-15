import SwiftUI

struct AdminRequestsListView: View {
    @EnvironmentObject var organizationStore: AdminOrganizationStore
    @StateObject private var store = AdminRequestsStore()

    private var safeOrganizationId: String {
        organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack {
            if safeOrganizationId.isEmpty {
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
                ProgressView("読み込み中...")
                    .padding()

            } else if let errorMessage = store.errorMessage,
                      !errorMessage.isEmpty {

                VStack(spacing: 12) {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)

                    Button("再読み込み") {
                        store.startListening(
                            organizationId: safeOrganizationId
                        )
                    }
                    .buttonStyle(.bordered)
                }
                .padding()

            } else if store.requests.isEmpty {
                Text("申請はありません")
                    .foregroundColor(.gray)
                    .padding()

            } else {
                List(store.requests) { item in
                    NavigationLink {
                        AdminRequestsDetailView(
                            request: item,
                            store: store
                        )
                    } label: {
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
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("会員申請一覧")
        .onAppear {
            if safeOrganizationId.isEmpty {
                organizationStore.startListening(
                    organizationId: OrganizationConfig.organizationId
                )
            } else {
                store.startListening(
                    organizationId: safeOrganizationId
                )
            }
        }
        .onChange(of: safeOrganizationId) { _, newValue in
            let newOrganizationId = newValue
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !newOrganizationId.isEmpty else {
                return
            }

            store.startListening(
                organizationId: newOrganizationId
            )
        }
        .onDisappear {
            store.stopListening()
        }
    }
}
