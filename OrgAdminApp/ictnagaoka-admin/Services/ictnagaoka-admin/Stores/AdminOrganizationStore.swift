import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class AdminOrganizationStore: ObservableObject {

    @Published var isLoading: Bool = false
    @Published var organization: OrganizationModel = AdminOrganizationStore.emptyOrganization()
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    var organizationCode: String {
        organization.organizationCode
    }

    var displayName: String {
        organization.displayName
    }

    var name: String {
        organization.displayName
    }

    var openingEnabled: Bool {
        organization.openingEnabled
    }

    var openingImageURL: String {
        organization.openingImageURL
    }

    var logoImageURL: String {
        organization.logoImageURL
    }

    var isActive: Bool {
        organization.isActive
    }

    func startListening(organizationId: String) {
        listener?.remove()

        let trimmedId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedId.isEmpty else {
            organization = Self.emptyOrganization()
            errorMessage = "organizationId が空です"
            return
        }

        isLoading = true
        errorMessage = nil

        listener = db
            .collection("organizations")
            .document(trimmedId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    self.isLoading = false

                    if let error {
                        self.organization = Self.emptyOrganization()
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    guard let snapshot, snapshot.exists else {
                        self.organization = Self.emptyOrganization()
                        self.errorMessage = "組織情報が見つかりません"
                        return
                    }

                    self.organization = Self.makeOrganization(from: snapshot)
                }
            }
    }

    func loadOrganization(organizationId: String) async {
        let trimmedId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedId.isEmpty else {
            organization = Self.emptyOrganization()
            errorMessage = "organizationId が空です"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db
                .collection("organizations")
                .document(trimmedId)
                .getDocument()

            isLoading = false

            guard snapshot.exists else {
                organization = Self.emptyOrganization()
                errorMessage = "組織情報が見つかりません"
                return
            }

            organization = Self.makeOrganization(from: snapshot)

        } catch {
            organization = Self.emptyOrganization()
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func reset() {
        listener?.remove()
        listener = nil
        organization = Self.emptyOrganization()
        errorMessage = nil
        isLoading = false
    }

    private static func emptyOrganization() -> OrganizationModel {
        OrganizationModel(
            id: "",
            organizationCode: "",
            displayName: "",
            openingEnabled: false,
            openingImageURL: "",
            logoImageURL: "",
            isActive: false
        )
    }

    private static func makeOrganization(from snapshot: DocumentSnapshot) -> OrganizationModel {
        let data = snapshot.data() ?? [:]

        return OrganizationModel(
            id: snapshot.documentID,
            organizationCode: data["organizationCode"] as? String ?? snapshot.documentID,
            displayName: data["displayName"] as? String
                ?? data["name"] as? String
                ?? snapshot.documentID,
            openingEnabled: data["openingEnabled"] as? Bool ?? false,
            openingImageURL: data["openingImageURL"] as? String ?? "",
            logoImageURL: data["logoImageURL"] as? String ?? "",
            isActive: data["isActive"] as? Bool ?? true
        )
    }
}
