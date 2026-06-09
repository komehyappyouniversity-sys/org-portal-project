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
    @State private var selectedFeeAmount: Int
    @State private var zoomURL: String
    @State private var isPublished: Bool

    @State private var isSaving = false
    @State private var errorMessage = ""

    private let feeOptions: [Int] = [0, 500, 1000, 3000, 5000]

    private var organizationId: String {
        organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var paymentRequired: Bool {
        selectedFeeAmount > 0
    }

    private var appStoreProductId: String {
        switch selectedFeeAmount {
        case 500:
            return "booking500"
        case 1000:
            return "booking1000"
        case 3000:
            return "booking3000"
        case 5000:
            return "booking5000"
        default:
            return ""
        }
    }

    init(event: AdminBookingEvent?) {
        self.event = event

        _title = State(initialValue: event?.title ?? "")
        _description = State(initialValue: event?.description ?? "")
        _eventDate = State(initialValue: event?.eventDate ?? Date())

        let initialFee = event?.feeAmount ?? 0
        if [0, 500, 1000, 3000, 5000].contains(initialFee) {
            _selectedFeeAmount = State(initialValue: initialFee)
        } else {
            _selectedFeeAmount = State(initialValue: 0)
        }

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

            Section("参加費") {
                Picker("価格", selection: $selectedFeeAmount) {
                    Text("無料").tag(0)
                    Text("500円").tag(500)
                    Text("1,000円").tag(1000)
                    Text("3,000円").tag(3000)
                    Text("5,000円").tag(5000)
                }

                if paymentRequired {
                    HStack {
                        Text("App内課金商品")
                        Spacer()
                        Text(appStoreProductId)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("無料講座として保存されます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

        let trimmedZoomURL = zoomURL
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = "イベント名を入力してください。"
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
            feeAmount: selectedFeeAmount,
            appStoreProductId: appStoreProductId,
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
