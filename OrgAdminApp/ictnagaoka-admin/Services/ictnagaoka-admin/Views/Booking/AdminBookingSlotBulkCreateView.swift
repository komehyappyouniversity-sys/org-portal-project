//
//  AdminBookingSlotBulkCreateView.swift
//  ictnagaoka-admin
//

import SwiftUI

struct AdminBookingSlotBulkCreateView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var store = AdminBookingSlotStore()

    let event: AdminBookingEvent

    @State private var startAt: Date
    @State private var endAt: Date
    @State private var slotMinutesText = "60"
    @State private var capacityText = "1"
    @State private var isOpen = true

    @State private var isSaving = false
    @State private var errorMessage = ""

    init(event: AdminBookingEvent) {
        self.event = event

        let calendar = Calendar.current

        let defaultStart = calendar.date(
            bySettingHour: 10,
            minute: 0,
            second: 0,
            of: event.eventDate
        ) ?? event.eventDate

        let defaultEnd = calendar.date(
            bySettingHour: 17,
            minute: 0,
            second: 0,
            of: event.eventDate
        ) ?? event.eventDate.addingTimeInterval(7 * 60 * 60)

        _startAt = State(initialValue: defaultStart)
        _endAt = State(initialValue: defaultEnd)
    }

    var body: some View {
        Form {
            Section("一括作成する時間") {
                DatePicker(
                    "開始",
                    selection: $startAt,
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "終了",
                    selection: $endAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("時間枠設定") {
                TextField("1枠の分数 例：60", text: $slotMinutesText)
                    .keyboardType(.numberPad)

                TextField("各枠の定員 例：1", text: $capacityText)
                    .keyboardType(.numberPad)

                Toggle("作成した時間枠を受付中にする", isOn: $isOpen)
            }

            Section("作成例") {
                Text(exampleText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    Task {
                        await createSlots()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("時間枠を一括作成")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("時間枠一括作成")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
    }

    private var exampleText: String {
        guard let minutes = Int(slotMinutesText), minutes > 0 else {
            return "1枠の分数を入力してください。"
        }

        let firstEnd = startAt.addingTimeInterval(TimeInterval(minutes * 60))

        let start = startAt.formatted(date: .omitted, time: .shortened)
        let end = firstEnd.formatted(date: .omitted, time: .shortened)

        return "\(start)〜\(end) のような時間枠を終了時間まで自動作成します。"
    }

    private func createSlots() async {
        errorMessage = ""

        guard let eventId = event.id else {
            errorMessage = "eventId がありません。"
            return
        }

        guard let slotMinutes = Int(slotMinutesText), slotMinutes > 0 else {
            errorMessage = "1枠の分数は1以上の数字で入力してください。"
            return
        }

        guard let capacity = Int(capacityText), capacity > 0 else {
            errorMessage = "定員は1以上の数字で入力してください。"
            return
        }

        guard endAt > startAt else {
            errorMessage = "終了時間は開始時間より後にしてください。"
            return
        }

        let interval = TimeInterval(slotMinutes * 60)

        var currentStart = startAt
        var slotsToCreate: [AdminBookingSlot] = []

        while currentStart.addingTimeInterval(interval) <= endAt {
            let currentEnd = currentStart.addingTimeInterval(interval)

            let slot = AdminBookingSlot(
                startAt: currentStart,
                endAt: currentEnd,
                capacity: capacity,
                reservedCount: 0,
                paidCount: 0,
                isOpen: isOpen,
                createdAt: nil,
                updatedAt: nil
            )

            slotsToCreate.append(slot)
            currentStart = currentEnd
        }

        guard !slotsToCreate.isEmpty else {
            errorMessage = "作成できる時間枠がありません。時間を確認してください。"
            return
        }

        isSaving = true
        defer { isSaving = false }

        for slot in slotsToCreate {
            await store.saveSlot(
                organizationId: organizationStore.organizationId,
                eventId: eventId,
                slot: slot
            )

            if !store.errorMessage.isEmpty {
                errorMessage = store.errorMessage
                return
            }
        }

        print("✅ 時間枠一括作成完了:", slotsToCreate.count)
        dismiss()
    }
}
