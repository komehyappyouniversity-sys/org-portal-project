import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class MemberRegistrationSettingsStore: ObservableObject {

    @Published var birthDateRequired: Bool = true
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var listeningOrganizationId: String = ""

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {
        let trimmedOrganizationId = organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else {
            birthDateRequired = true
            errorMessage = "organizationId が空です。"
            return
        }

        if listeningOrganizationId == trimmedOrganizationId {
            return
        }

        listeningOrganizationId = trimmedOrganizationId
        listener?.remove()
        listener = nil
        isLoading = true
        errorMessage = ""

        let ref = db
            .collection("organizations")
            .document(trimmedOrganizationId)
            .collection("settings")
            .document("memberRegistration")

        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }

                self.isLoading = false

                if let error {
                    print("❌ memberRegistration settings 読み込み失敗:", error.localizedDescription)
                    self.birthDateRequired = true
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let snapshot, snapshot.exists else {
                    print("ℹ️ memberRegistration settings 未作成のため birthDateRequired=true")
                    self.birthDateRequired = true
                    return
                }

                let data = snapshot.data() ?? [:]
                self.birthDateRequired = data["birthDateRequired"] as? Bool ?? true

                print("✅ memberRegistration settings 読み込み:", self.birthDateRequired)
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        listeningOrganizationId = ""
        isLoading = false
    }
}
