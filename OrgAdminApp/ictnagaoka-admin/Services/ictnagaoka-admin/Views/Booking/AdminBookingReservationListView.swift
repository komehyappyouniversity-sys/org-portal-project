import SwiftUI

struct AdminBookingReservationListView: View {
    @EnvironmentObject private var organizationStore: AdminOrganizationStore

    let eventId: String
    let slotId: String
    let slotTitle: String

    @StateObject private var store = AdminBookingReservationStore()

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if store.isLoading {
                Spacer()
                ProgressView("予約者を読み込み中...")
                Spacer()

            } else if !store.errorMessage.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text(store.errorMessage)
                        .font(.body)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()

            } else if store.reservations.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundColor(.gray)

                    Text("まだ予約者はいません")
                        .font(.headline)

                    Text("この時間枠に予約が入ると、ここに表示されます。")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()

            } else {
                List {
                    ForEach(store.reservations) { reservation in
                        reservationRow(reservation)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("予約者一覧")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.startListening(
                organizationId: organizationStore.organization.id,
                eventId: eventId,
                slotId: slotId
            )
        }
        .onDisappear {
            store.stopListening()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(slotTitle)
                .font(.headline)

            Text("予約者数：\(store.reservations.count)名")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private func reservationRow(_ reservation: AdminBookingReservation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(reservation.memberName.isEmpty ? "名前未設定" : reservation.memberName)
                    .font(.headline)

                Spacer()

                Text("予約中")
                    .font(.caption.bold())
                    .foregroundColor(.red)
            }

            if !reservation.memberEmail.isEmpty {
                Text(reservation.memberEmail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !reservation.memberUid.isEmpty {
                Text("UID: \(reservation.memberUid)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 6)
    }
}
