import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class SuperAdminFeatureStore: ObservableObject {
    @Published var settings: AdminFeatureSettings = .default
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage = ""
    @Published var successMessage = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {
        listener?.remove()
        errorMessage = ""
        successMessage = ""

        guard !organizationId.isEmpty else {
            settings = .default
            errorMessage = "organizationId が空です。"
            return
        }

        isLoading = true

        let ref = db
            .collection("organizations")
            .document(organizationId)
            .collection("settings")
            .document("adminFeatures")

        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.settings = .default
                    return
                }

                guard let data = snapshot?.data() else {
                    self.settings = .default
                    return
                }

                self.settings = AdminFeatureSettings(data: data)
            }
        }
    }

    func save(organizationId: String) async {
        errorMessage = ""
        successMessage = ""

        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が空です。"
            return
        }

        isSaving = true

        let uid = Auth.auth().currentUser?.uid ?? ""

        var data = settings.asDictionary
        data["updatedAt"] = FieldValue.serverTimestamp()
        data["updatedBy"] = uid

        do {
            try await db
                .collection("organizations")
                .document(organizationId)
                .collection("settings")
                .document("adminFeatures")
                .setData(data, merge: true)

            successMessage = "機能設定を保存しました。"
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
