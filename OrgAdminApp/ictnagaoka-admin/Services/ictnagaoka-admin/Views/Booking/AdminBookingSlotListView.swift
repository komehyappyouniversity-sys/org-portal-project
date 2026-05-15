import SwiftUI

struct AdminBookingSlotListView: View {
    @EnvironmentObject private var organizationStore: AdminOrganizationStore

    let event: AdminBookingEvent

    @StateObject private var store = AdminBookingSlotStore()
    @State private var showEditor = false
    @State private var showBulkCreate = false

    private var organizationId: String {
        organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack {
            if store.isLoading {
                ProgressView("時間枠を読み込み中...")
                    .padding()

            } else if !store.errorMessage.isEmpty {
                errorView

            } else if store.slots.isEmpty {
                emptyView

            } else {
                List {
                    ForEach(store.slots) { slot in
                        slotRow(slot)
                    }
                    .onDelete { indexSet in
                        deleteSlots(indexSet)
                    }
                }
            }
        }
        .navigationTitle("時間枠")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showBulkCreate = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                }

                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            guard let eventId = event.id else {
                store.errorMessage = "イベントIDがありません"
                return
            }

            store.startListening(
                organizationId: organizationId,
                eventId: eventId
            )
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                AdminBookingSlotEditorView(
                    event: event,
                    slot: nil
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

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text(store.errorMessage)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.largeTitle)
                .foregroundColor(.gray)

            Text("時間枠がありません")
                .font(.headline)

            Text("右上の＋ボタン、または一括作成ボタンから時間枠を作成してください。")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showBulkCreate = true
            } label: {
                Label("時間枠を一括作成", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func slotRow(_ slot: AdminBookingSlot) -> some View {
        let slotTitle = "\(timeText(slot.startAt)) 〜 \(timeText(slot.endAt))"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(slotTitle)
                        .font(.headline)

                    Text("時間枠ID: \(slot.id ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("定員 \(slot.capacity)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("残り \(slot.remainingCount)")
                        .font(.caption.bold())
                        .foregroundColor(slot.remainingCount <= 0 ? .red : .blue)
                }
            }

            if let eventId = event.id, let slotId = slot.id {
                NavigationLink {
                    AdminBookingReservationListView(
                        eventId: eventId,
                        slotId: slotId,
                        slotTitle: slotTitle
                    )
                    .environmentObject(organizationStore)
                } label: {
                    Label("予約者一覧", systemImage: "person.3.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }

    private func deleteSlots(_ indexSet: IndexSet) {
        guard let eventId = event.id else {
            store.errorMessage = "イベントIDがありません"
            return
        }

        for index in indexSet {
            let slot = store.slots[index]

            guard let slotId = slot.id else {
                continue
            }

            Task {
                await store.deleteSlot(
                    organizationId: organizationId,
                    eventId: eventId,
                    slotId: slotId
                )
            }
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
