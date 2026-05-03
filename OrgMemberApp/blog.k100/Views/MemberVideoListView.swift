import SwiftUI

struct MemberVideoListView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @StateObject private var store = VideoStore()

    var body: some View {
        List(store.videos) { video in
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.headline)

                Button("再生") {
                    if let url = URL(string: video.url) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("動画")
        .onAppear {
            store.startListening(
                organizationId: organizationStore.organization.id
            )
        }
    }
}
