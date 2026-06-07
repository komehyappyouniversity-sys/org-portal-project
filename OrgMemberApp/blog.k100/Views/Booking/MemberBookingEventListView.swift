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
                VStack(alignment: .leading, spacing: 12) {

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

                                if event.paymentRequired {
                                    Text("¥\(event.feeAmount)")
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)
                                } else {
                                    Text("無料")
                                        .font(.caption.bold())
                                        .foregroundColor(.green)
                                }

                                Spacer()

                                Text("予約する")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    if event.paymentRequired {
                        NavigationLink {
                            MemberBookingPaymentView(event: event)
                        } label: {
                            Text("アプリで決済する")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("講座予約")
        .onAppear {
            store.startListening(organizationId: organizationId)
        }
    }
}

struct MemberBookingPaymentView: View {
    let event: MemberBookingEvent

    var body: some View {
        List {
            Section("講座") {
                Text(event.title.isEmpty ? "無題のイベント" : event.title)

                HStack {
                    Text("参加費")
                    Spacer()
                    Text("¥\(event.feeAmount)")
                        .foregroundColor(.blue)
                }
            }

            Section("お支払い") {
                Button {
                    // App内課金の処理は次の段階で実装します
                } label: {
                    Text("App内課金で支払う")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }

            Section {
                Text("この講座の参加費は、AppleのApp内課金を通じてお支払いできます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("決済")
    }
}
