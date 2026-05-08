//
//  MemberBookingSlotListView.swift
//  blog.k100
//

import SwiftUI

struct MemberBookingSlotListView: View {

    let organizationId: String
    let event: MemberBookingEvent

    @StateObject private var store = MemberBookingSlotStore()
    @State private var cancelTargetSlot: MemberBookingSlot?

    private var eventId: String {
        event.id ?? ""
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                eventCard

                if store.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if !store.errorMessage.isEmpty {
                    Text(store.errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(16)
                }

                if !store.successMessage.isEmpty {
                    Text(store.successMessage)
                        .foregroundColor(.green)
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(16)
                }

                Text("予約時間")
                    .font(.title2.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                if store.slots.isEmpty && !store.isLoading {
                    Text("現在、予約できる時間はありません。")
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(16)
                } else {
                    slotList
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("時間を選択")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.startListening(
                organizationId: organizationId,
                eventId: eventId
            )
        }
        .onDisappear {
            store.stopListening()
        }
        .alert("予約をキャンセルしますか？", isPresented: cancelAlertBinding) {
            Button("やめる", role: .cancel) {
                cancelTargetSlot = nil
            }

            Button("キャンセルする", role: .destructive) {
                if let slot = cancelTargetSlot {
                    store.cancelBooking(
                        organizationId: organizationId,
                        eventId: eventId,
                        slot: slot
                    )
                }

                cancelTargetSlot = nil
            }
        } message: {
            Text("この時間枠の予約を取り消します。")
        }
    }

    private var cancelAlertBinding: Binding<Bool> {
        Binding(
            get: {
                cancelTargetSlot != nil
            },
            set: { newValue in
                if !newValue {
                    cancelTargetSlot = nil
                }
            }
        )
    }

    private var eventCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.title)
                .font(.title3.bold())

            Text(dateFormatter.string(from: event.eventDate))
                .font(.headline)
                .foregroundColor(.secondary)

            if event.feeAmount > 0 {
                Text("参加費：¥\(event.feeAmount.formatted())")
                    .font(.headline.bold())
                    .foregroundColor(.blue)
            } else {
                Text("参加費：無料")
                    .font(.headline.bold())
                    .foregroundColor(.blue)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(24)
    }

    private var slotList: some View {
        VStack(spacing: 0) {
            ForEach(store.slots) { slot in
                slotRow(slot)

                if slot.id != store.slots.last?.id {
                    Divider()
                        .padding(.vertical, 18)
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(24)
    }

    private func slotRow(_ slot: MemberBookingSlot) -> some View {
        let slotId = slot.id ?? ""
        let isMyBooking = store.myBookedSlotIds.contains(slotId)
        let remaining = max(slot.capacity - slot.reservedCount, 0)
        let isFull = remaining <= 0
        let isProcessingThisSlot = store.processingSlotId == slotId

        let canBook = slot.isOpen && !isFull && !isProcessingThisSlot && !isMyBooking
        let canCancel = isMyBooking && !isProcessingThisSlot

        return VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("\(timeFormatter.string(from: slot.startAt)) 〜 \(timeFormatter.string(from: slot.endAt))")
                    .font(.title2.bold())

                Spacer()

                Text(
                    slotStatusText(
                        slot: slot,
                        remaining: remaining,
                        isMyBooking: isMyBooking
                    )
                )
                .font(.headline.bold())
                .foregroundColor(
                    slotStatusColor(
                        slot: slot,
                        remaining: remaining,
                        isMyBooking: isMyBooking
                    )
                )
            }

            Text("定員 \(slot.capacity)　残り \(remaining)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if isMyBooking {
                Button {
                    cancelTargetSlot = slot
                } label: {
                    Text(isProcessingThisSlot ? "キャンセル中..." : "予約をキャンセルする")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canCancel ? Color.red : Color.gray)
                        .cornerRadius(14)
                }
                .disabled(!canCancel)

            } else {
                Button {
                    store.book(
                        organizationId: organizationId,
                        eventId: eventId,
                        slot: slot
                    )
                } label: {
                    Text(
                        buttonTitle(
                            slot: slot,
                            remaining: remaining,
                            isProcessingThisSlot: isProcessingThisSlot
                        )
                    )
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(canBook ? Color.blue : Color.gray)
                    .cornerRadius(14)
                }
                .disabled(!canBook)
            }
        }
    }

    private func slotStatusText(
        slot: MemberBookingSlot,
        remaining: Int,
        isMyBooking: Bool
    ) -> String {
        if isMyBooking {
            return "予約済み"
        }

        if !slot.isOpen {
            return "受付停止"
        }

        if remaining <= 0 {
            return "満席"
        }

        return "受付中"
    }

    private func slotStatusColor(
        slot: MemberBookingSlot,
        remaining: Int,
        isMyBooking: Bool
    ) -> Color {
        if isMyBooking {
            return .blue
        }

        if !slot.isOpen {
            return .gray
        }

        if remaining <= 0 {
            return .red
        }

        return .green
    }

    private func buttonTitle(
        slot: MemberBookingSlot,
        remaining: Int,
        isProcessingThisSlot: Bool
    ) -> String {
        if isProcessingThisSlot {
            return "予約中..."
        }

        if !slot.isOpen {
            return "受付停止中"
        }

        if remaining <= 0 {
            return "満席です"
        }

        return "この時間を予約する"
    }
}
