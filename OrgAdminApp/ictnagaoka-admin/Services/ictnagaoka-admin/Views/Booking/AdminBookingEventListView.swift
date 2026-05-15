import SwiftUI

struct AdminBookingEventListView: View {
    @EnvironmentObject var organizationStore: AdminOrganizationStore
    @StateObject private var store = AdminBookingEventStore()

    @State private var showEditor = false
    @State private var selectedEvent: AdminBookingEvent?

    private var organizationId: String {
        organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            if store.isLoading {
                ProgressView("読み込み中...")
            }

            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .foregroundColor(.red)
            }

            if store.events.isEmpty && !store.isLoading {
                Text("予約イベントがまだありません。右上の＋から追加してください。")
                    .foregroundColor(.secondary)
            }

            ForEach(store.events) { event in
                NavigationLink {
                    AdminBookingSlotListView(event: event)
                        .environmentObject(organizationStore)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(event.title.isEmpty ? "無題の予約イベント" : event.title)
                                .font(.headline)

                            Spacer()

                            Button {
                                selectedEvent = event
                                showEditor = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(
                            event.eventDate.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                        HStack {
                            Text(event.isPublished ? "公開中" : "非公開")
                                .font(.caption)
                                .foregroundColor(
                                    event.isPublished ? .green : .gray
                                )

                            Spacer()

                            Text("¥\(event.feeAmount)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("イベント予約管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedEvent = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            store.startListening(
                organizationId: organizationId
            )
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                AdminBookingEventEditorView(event: selectedEvent)
                    .environmentObject(organizationStore)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let event = store.events[index]

            guard let eventId = event.id else {
                continue
            }

            Task {
                await store.deleteEvent(
                    organizationId: organizationId,
                    eventId: eventId
                )
            }
        }
    }
}
