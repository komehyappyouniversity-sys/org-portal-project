//
//  AdminBookingEventEditorView.swift
//  ictnagaoka-admin
//

import SwiftUI

struct AdminBookingEventEditorView: View {
    @EnvironmentObject var organizationStore: AdminOrganizationStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var store = AdminBookingEventStore()

    let event: AdminBookingEvent?

    @State private var title: String
    @State private var description: String
    @State private var eventDate: Date
    @State private var feeAmountText: String
    @State private var appStoreProductId: String
    @State private var paymentRequired: Bool
    @State private var zoomURL: String
    @State private var isPublished: Bool

    @State private var isSaving = false
    @State private var errorMessage = ""

    private var organizationId: String {
        organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(event: AdminBookingEvent?) {
        self.event = event

        _title = State(initialValue: event?.title ?? "")
        _description = State(initialValue: event?.description ?? "")
        _eventDate = State(initialValue: event?.eventDate ?? Date())
        _feeAmountText = State(
            initialValue: event.map { String($0.feeAmount) } ?? ""
        )
        _appStoreProductId = State(
            initialValue: event?.appStoreProductId ?? ""
        )
        _paymentRequired = State(
            initialValue: event?.paymentRequired ?? true
        )
        _zoomURL = State(initialValue: event?.zoomURL ?? "")
        _isPublished = State(initialValue: event?.isPublished ?? false)
    }

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("イベント名", text: $title)

                TextField("説明", text: $description, axis: .vertical)
                    .lineLimit(3...6)

                DatePicker(
                    "開催日",
                    selection: $eventDate,
                    displayedComponents: [.date]
                )
            }

            Section("参加費・App内課金") {
                TextField("参加費 例：3000", text: $feeAmountText)
                    .keyboardType(.numberPad)

                TextField(
                    "App Store Product ID",
                    text: $appStoreProductId
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Toggle(
                    "参加費の決済を必要にする",
                    isOn: $paymentRequired
                )

                Text("例：zoom_lesson_3000")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Zoom") {
                TextField("Zoom URL", text: $zoomURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Text("決済完了後の会員だけに表示する予定です。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("公開設定") {
                Toggle("会員アプリに公開する", isOn: $isPublished)
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
        .navigationTitle(
            event == nil
                ? "予約イベント作成"
                : "予約イベント編集"
        )
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

        let trimmedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedProductId = appStoreProductId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedZoomURL = zoomURL
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = "イベント名を入力してください。"
            return
        }

        guard let feeAmount = Int(feeAmountText),
              feeAmount >= 0 else {
            errorMessage = "参加費は数字で入力してください。"
            return
        }

        if paymentRequired && trimmedProductId.isEmpty {
            errorMessage = "App Store Product ID を入力してください。"
            return
        }

        if trimmedZoomURL.isEmpty {
            errorMessage = "Zoom URL を入力してください。"
            return
        }

        isSaving = true
        defer { isSaving = false }

        let newEvent = AdminBookingEvent(
            id: event?.id,
            title: trimmedTitle,
            description: description
                .trimmingCharacters(in: .whitespacesAndNewlines),
            eventDate: eventDate,
            feeAmount: feeAmount,
            appStoreProductId: trimmedProductId,
            paymentRequired: paymentRequired,
            zoomURL: trimmedZoomURL,
            isPublished: isPublished,
            createdAt: event?.createdAt,
            updatedAt: event?.updatedAt
        )

        await store.saveEvent(
            organizationId: organizationId,
            event: newEvent
        )

        if store.errorMessage.isEmpty {
            dismiss()
        } else {
            errorMessage = store.errorMessage
        }
    }
}
