import SwiftUI

struct MemberMessageDetailView: View {
    @EnvironmentObject private var store: MemberMessageStore

    let item: MemberMessageItem
    let organizationId: String

    private var currentItem: MemberMessageItem {
        store.items.first(where: { $0.id == item.id }) ?? item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(currentItem.title)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(currentItem.body)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("お知らせ詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.markAsRead(item: currentItem, organizationId: organizationId)
        }
    }
}
