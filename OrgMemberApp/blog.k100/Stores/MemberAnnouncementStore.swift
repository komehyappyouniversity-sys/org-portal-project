//
//  MemberAnnouncementStore.swift
//  ictnagaoka
//
//  Created by 根津浩 on 2026/04/19.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class MemberAnnouncementStore: ObservableObject {
    @Published var items: [MemberAnnouncementItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        print("========== MemberAnnouncementStore startListening START ==========")
        print("organizationId:", trimmedOrganizationId)

        guard !trimmedOrganizationId.isEmpty else {
            items = []
            errorMessage = "organizationId が空です。"
            print("❌ organizationId が空です。")
            print("========== MemberAnnouncementStore startListening END ==========")
            return
        }

        listener?.remove()
        isLoading = true
        errorMessage = ""

        listener = db.collection("organizations")
            .document(trimmedOrganizationId)
            .collection("announcements")
            .whereField("isPublished", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    Task { @MainActor in
                        self.items = []
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                        print("❌ announcements listen error:", error.localizedDescription)
                        print("========== MemberAnnouncementStore startListening END ==========")
                    }
                    return
                }

                let docs = snapshot?.documents ?? []

                let loaded = docs.compactMap { doc in
                    MemberAnnouncementItem(document: doc)
                }

                Task { @MainActor in
                    self.items = loaded
                    self.isLoading = false
                    self.errorMessage = ""

                    print("✅ announcements loaded count:", loaded.count)
                    for item in loaded {
                        print("announcement:", item.title)
                    }
                    print("========== MemberAnnouncementStore startListening END ==========")
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
