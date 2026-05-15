//
//  AdminBookingSlotEditorView.swift
//  ictnagaoka-admin
//

import SwiftUI

struct AdminBookingSlotEditorView: View {
    @EnvironmentObject var organizationStore: AdminOrganizationStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var store = AdminBookingSlotStore()

    let event: AdminBookingEvent
    let slot: AdminBookingSlot?

    @State private var startAt: Date
    @State private var endAt: Date
    @State private var capacityText: String
    @State private var isOpen: Bool

    @State private var isSaving = false
    @State private var errorMessage = ""

    init(
        event: AdminBookingEvent,
        slot: AdminBookingSlot?
    ) {
        self.event = event
        self.slot = slot

        let defaultStart = Calendar.current.date(
            bySettingHour: 10,
            minute: 0,
            second: 0,
            of: event.eventDate
        ) ?? event.eventDate

        _startAt = State(initialValue: slot?.startAt ?? defaultStart)
        _endAt = State(initialValue: slot?.endAt ?? defaultStart.addingTimeInterval(60 * 60))
        _capacityText = State(initialValue: slot.map { String($0.capacity) } ?? "1")
        _isOpen = State(initialValue: slot?.isOpen ?? true)
    }

    var body: some View {
        Form {
            Section("時間枠") {
                DatePicker(
                    "開始時間",
                    selection: $startAt,
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "終了時間",
                    selection: $endAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("定員") {
                TextField("定員 例：1", text: $capacityText)
                    .keyboardType(.numberPad)

                if let slot {
                    Text("現在の予約数：\(slot.reservedCount)")
                    Text("決済済み：\(slot.paidCount)")
                }
            }

            Section("受付設定") {
                Toggle("この時間枠を受付中にする", isOn: $isOpen)
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
                        await save()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle(slot == nil ? "時間枠追加" : "時間枠編集")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
    }

    private func save() async {
        errorMessage = ""

        guard let eventId = event.id else {
            errorMessage = "eventId がありません。イベントを保存してから時間枠を追加してください。"
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

        if let slot, capacity < slot.reservedCount {
            errorMessage = "定員は現在の予約数より少なくできません。"
            return
        }

        let organizationId = organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty else {
            errorMessage = "組織IDが取得できません。組織を選択してください。"
            return
        }

        isSaving = true
        defer { isSaving = false }

        let newSlot = AdminBookingSlot(
            id: slot?.id,
            startAt: startAt,
            endAt: endAt,
            capacity: capacity,
            reservedCount: slot?.reservedCount ?? 0,
            paidCount: slot?.paidCount ?? 0,
            isOpen: isOpen,
            createdAt: slot?.createdAt,
            updatedAt: slot?.updatedAt
        )

        await store.saveSlot(
            organizationId: organizationId,
            eventId: eventId,
            slot: newSlot
        )

        if store.errorMessage.isEmpty {
            dismiss()
        } else {
            errorMessage = store.errorMessage
        }
    }
}
