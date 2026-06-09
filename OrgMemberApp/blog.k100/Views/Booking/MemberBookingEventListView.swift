//
//  MemberBookingEventListView.swift
//  blog.k100
//

import SwiftUI
import StoreKit

struct MemberBookingEventListView: View {
    @StateObject private var store = MemberBookingEventStore()
    @StateObject private var purchaseStore = VideoPurchaseStore()

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
                eventSection(event)
            }
        }
        .navigationTitle("講座予約")
        .onAppear {
            store.startListening(organizationId: organizationId)

            Task {
                await purchaseStore.updatePurchasedProducts()
            }
        }
        .onReceive(store.$events) { events in
            let productIds = events
                .map { $0.appStoreProductId }
                .filter { !$0.isEmpty }

            Task {
                await purchaseStore.loadProducts(productIds: productIds)
            }
        }
    }

    @ViewBuilder
    private func eventSection(_ event: MemberBookingEvent) -> some View {
        let isPaid = event.paymentRequired && event.feeAmount > 0
        let isPurchased = purchaseStore.isPurchased(productId: event.appStoreProductId)

        VStack(alignment: .leading, spacing: 12) {
            if !isPaid || isPurchased {
                NavigationLink {
                    MemberBookingSlotListView(
                        organizationId: organizationId,
                        event: event
                    )
                } label: {
                    eventSummary(event, canReserve: true)
                }
            } else {
                eventSummary(event, canReserve: false)
            }

            if isPaid {
                if isPurchased {
                    Text("購入済みです。予約へ進めます。")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                } else {
                    NavigationLink {
                        MemberBookingPaymentView(
                            organizationId: organizationId,
                            event: event,
                            purchaseStore: purchaseStore
                        )
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
        }
        .padding(.vertical, 8)
    }

    private func eventSummary(
        _ event: MemberBookingEvent,
        canReserve: Bool
    ) -> some View {
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

                if event.paymentRequired && event.feeAmount > 0 {
                    Text("¥\(event.feeAmount)")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                } else {
                    Text("無料")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }

                Spacer()

                Text(canReserve ? "予約する" : "決済後に予約できます")
                    .font(.caption.bold())
                    .foregroundColor(canReserve ? .green : .orange)
            }
        }
    }
}

struct MemberBookingPaymentView: View {
    let organizationId: String
    let event: MemberBookingEvent

    @ObservedObject var purchaseStore: VideoPurchaseStore

    private var product: Product? {
        purchaseStore.products.first {
            $0.id == event.appStoreProductId
        }
    }

    private var isPurchased: Bool {
        purchaseStore.isPurchased(productId: event.appStoreProductId)
    }

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

                if !event.appStoreProductId.isEmpty {
                    HStack {
                        Text("商品ID")
                        Spacer()
                        Text(event.appStoreProductId)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }

            Section("お支払い") {
                if isPurchased {
                    Text("購入済みです")
                        .font(.headline)
                        .foregroundColor(.green)

                    NavigationLink {
                        MemberBookingSlotListView(
                            organizationId: organizationId,
                            event: event
                        )
                    } label: {
                        Text("予約へ進む")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }

                } else if let product {
                    Button {
                        Task {
                            await purchaseStore.purchase(product: product)
                            await purchaseStore.updatePurchasedProducts()
                        }
                    } label: {
                        Text("\(product.displayPrice)で支払う")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)

                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("購入準備中です")
                            .font(.headline)

                        Text("App Storeの商品情報を取得できませんでした。商品IDの設定を確認してください。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
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
