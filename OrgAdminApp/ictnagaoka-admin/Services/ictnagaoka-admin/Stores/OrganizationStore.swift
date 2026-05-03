import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class OrganizationStore: ObservableObject {

    // 🔥 追加（これが今回の核心）
    @Published var organizationId: String = ""

    @Published var organization = OrganizationModel.empty
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {

        // 🔥 ここで保持する
        self.organizationId = organizationId

        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が空です"
            return
        }

        isLoading = true
        errorMessage = nil

        listener?.remove()

        listener = db.collection("organizations")
            .document(organizationId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let data = snapshot?.data() else {
                    self.errorMessage = "組織データが存在しません"
                    self.isLoading = false
                    return
                }

                self.organization = OrganizationModel(
                    id: snapshot?.documentID ?? "",
                    organizationCode: data["organizationCode"] as? String ?? "",
                    displayName: data["displayName"] as? String ?? "",
                    openingEnabled: data["openingEnabled"] as? Bool ?? false,
                    openingImageURL: data["openingImageURL"] as? String ?? "",
                    logoImageURL: data["logoImageURL"] as? String ?? "",
                    isActive: data["isActive"] as? Bool ?? true
                )

                self.isLoading = false
            }
    }
}
