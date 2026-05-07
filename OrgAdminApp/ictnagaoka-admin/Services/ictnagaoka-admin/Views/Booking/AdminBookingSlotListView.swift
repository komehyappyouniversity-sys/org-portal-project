//
//  AdminBookingSlotListView.swift
//  ictnagaoka-admin
//

import SwiftUI

struct AdminBookingSlotListView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @StateObject private var store = AdminBookingSlotStore()

    let event: AdminBookingEvent

    @State private var showEditor = false
    @State private var showBulkCreate = false
    @State private var selectedSlot: AdminBookingSlot?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title.isEmpty ? "無題の予約イベント" : event.title)
                        .font(.headline)

                    Text(event.eventDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("参加費：¥\(event.feeAmount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            if store.isLoading {
                ProgressView("読み込み中...")
            }

            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .foregroundColor(.red)
            }

            Section("時間枠") {
                if store.slots.isEmpty && !store.isLoading {
                    Text("時間枠がまだありません。右上の＋または一括作成から追加してください。")
                        .foregroundColor(.secondary)
                }

                ForEach(store.slots) { slot in
                    Button {
                        selectedSlot = slot
                        showEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(timeRangeText(slot))
                                    .font(.headline)

                                Spacer()

                                Text(slot.displayStatus)
                                    .font(.caption.bold())
                                    .foregroundColor(statusColor(slot))
                            }

                            HStack(spacing: 12) {
                                Text("定員 \(slot.capacity)")
                                Text("予約 \(slot.reservedCount)")
                                Text("決済 \(slot.paidCount)")
                                Text("残り \(slot.remainingCount)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("時間枠")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("一括") {
                    showBulkCreate = true
                }

                Button {
                    selectedSlot = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            guard let eventId = event.id else { return }

            store.startListening(
                organizationId: organizationStore.organizationId,
                eventId: eventId
            )
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                AdminBookingSlotEditorView(
                    event: event,
                    slot: selectedSlot
                )
                .environmentObject(organizationStore)
            }
        }
        .sheet(isPresented: $showBulkCreate) {
            NavigationStack {
                AdminBookingSlotBulkCreateView(event: event)
                    .environmentObject(organizationStore)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        guard let eventId = event.id else { return }

        for index in offsets {
            let slot = store.slots[index]
            guard let slotId = slot.id else { continue }

            Task {
                await store.deleteSlot(
                    organizationId: organizationStore.organizationId,
                    eventId: eventId,
                    slotId: slotId
                )
            }
        }
    }

    private func timeRangeText(_ slot: AdminBookingSlot) -> String {
        let start = slot.startAt.formatted(date: .omitted, time: .shortened)
        let end = slot.endAt.formatted(date: .omitted, time: .shortened)
        return "\(start)〜\(end)"
    }

    private func statusColor(_ slot: AdminBookingSlot) -> Color {
        if !slot.isOpen {
            return .gray
        }

        if slot.isFull {
            return .red
        }

        return .green
    }
}
