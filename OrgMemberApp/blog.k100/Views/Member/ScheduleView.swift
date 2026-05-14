//
//  ScheduleView.swift
//  blog.k100
//

import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @StateObject private var store = ScheduleStore()

    var body: some View {
        Group {
            if store.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("スケジュールを読み込んでいます...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let errorMessage = store.errorMessage, !errorMessage.isEmpty {
                VStack(spacing: 16) {
                    Text("スケジュール")
                        .font(.largeTitle.bold())

                    Text("読み込みに失敗しました")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("再読み込み") {
                        startListening()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if store.events.isEmpty {
                VStack(spacing: 16) {
                    Text("スケジュール")
                        .font(.largeTitle.bold())

                    Text("予定はまだ登録されていません。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                List {
                    ForEach(groupedDates, id: \.date) { section in
                        Section(section.dateText) {
                            ForEach(section.items) { event in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(event.title)
                                        .font(.headline)

                                    Text(timeText(for: event))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    if !event.locationName.isEmpty {
                                        Text("場所：\(event.locationName)")
                                            .font(.subheadline)
                                    }

                                    if !event.notes.isEmpty {
                                        Text(event.notes)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("スケジュール")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startListening()
        }
        .onChange(of: organizationStore.organizationId) { _, _ in
            startListening()
        }
        .onDisappear {
            store.stopListening()
        }
    }

    private func startListening() {
        let organizationId = organizationStore.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty else {
            print("⚠️ ScheduleView organizationId empty")
            return
        }

        print("📅 ScheduleView organizationId:", organizationId)

        store.startListening(
            organizationId: organizationId
        )
    }

    private var groupedDates: [(date: Date, dateText: String, items: [ScheduleEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.events) {
            calendar.startOfDay(for: $0.startAt)
        }

        return grouped.keys.sorted().map { day in
            let items = (grouped[day] ?? []).sorted { $0.startAt < $1.startAt }
            return (day, dateHeaderText(day), items)
        }
    }

    private func dateHeaderText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter.string(from: date)
    }

    private func timeText(for event: ScheduleEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"

        let start = formatter.string(from: event.startAt)

        if let endAt = event.endAt {
            return "\(start)〜\(formatter.string(from: endAt))"
        } else {
            return start
        }
    }
}
