//
//  MemberBookingEventListView.swift
//  blog.k100
//

import SwiftUI

struct MemberBookingEventListView: View {
    @StateObject private var store = MemberBookingEventStore()

    let organizationId: String

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
                Text("現在、予約できるイベントはありません。")
                    .foregroundColor(.secondary)
            }

            ForEach(store.events) { event in
                NavigationLink {
                    MemberBookingSlotListView(
                        organizationId: organizationId,
                        event: event
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title.isEmpty ? "無題のイベント" : event.title)
                            .font(.headline)

                        Text(event.eventDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if !event.description.isEmpty {
                            Text(event.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        HStack {
                            Text("参加費")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("¥\(event.feeAmount)")
                                .font(.caption.bold())
                                .foregroundColor(.blue)

                            Spacer()

                            Text("予約する")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("講座予約")
        .onAppear {
            store.startListening(organizationId: organizationId)
        }
    }
}
