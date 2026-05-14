import SwiftUI

struct MemberMessageListView: View {
    @EnvironmentObject private var organizationStore: OrganizationStore
    @StateObject private var store = MemberMessageStore()

    let titleText: String
    let visibility: String   // "public" or "member"

    var body: some View {
        List {
            if store.isLoading && store.items.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("読み込み中...")
                    Spacer()
                }
                .padding(.vertical, 24)
                .listRowSeparator(.hidden)

            } else if let errorMessage = store.errorMessage,
                      !errorMessage.isEmpty {
                VStack(spacing: 12) {
                    Text("お知らせを読み込めませんでした")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowSeparator(.hidden)

            } else if store.items.isEmpty {
                VStack(spacing: 12) {
                    Text("表示できるお知らせはありません")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("新しいお知らせが届くと、ここに表示されます。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowSeparator(.hidden)

            } else {
                ForEach(store.items, id: \.id) { item in
                    NavigationLink {
                        MemberMessageDetailView(
                            item: item,
                            organizationId: resolvedOrganizationId()
                        )
                        .environmentObject(store)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)

                                if !item.isRead {
                                    Text("未読")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .cornerRadius(8)
                                }
                            }

                            Text(item.body)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)

                            Text(formatDate(item.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startListening()
        }
        .onChange(of: organizationStore.organizationId) { _, _ in
            startListening()
        }
        .onDisappear {
            store.stopListening()
        }
    }

    private func startListening() {
        let organizationId = resolvedOrganizationId()

        guard !organizationId.isEmpty else {
            print("⚠️ MemberMessageListView organizationId empty")
            return
        }

        print("📩 MemberMessageListView organizationId:", organizationId)

        store.startListening(
            organizationId: organizationId,
            mode: visibility
        )
    }

    private func resolvedOrganizationId() -> String {
        let fromStore = organizationStore.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !fromStore.isEmpty {
            return fromStore
        }

        return organizationStore.organization.id
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
