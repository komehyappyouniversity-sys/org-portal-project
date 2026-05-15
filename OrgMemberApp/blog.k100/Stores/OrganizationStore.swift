import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class OrganizationStore: ObservableObject {

    @Published var isLoading: Bool = false
    @Published var organizationId: String = ""
    @Published var organizationName: String = ""
    @Published var organizationCode: String = ""
    @Published var openingEnabled: Bool = false
    @Published var openingImageURL: String = ""
    @Published var logoImageURL: String = ""
    @Published var homepageURL: String = ""
    @Published var isActive: Bool = true
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    deinit {
        listener?.remove()
    }

    var displayName: String {
        organizationName
    }

    var name: String {
        organizationName
    }

    func startListening(organizationId: String) {
        listener?.remove()

        guard !organizationId.isEmpty else {
            reset()
            errorMessage = "organizationId が空です"
            return
        }

        self.organizationId = organizationId
        isLoading = true
        errorMessage = nil

        listener = db
            .collection("organizations")
            .document(organizationId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        print("❌ OrganizationStore listen error:", error.localizedDescription)
                        return
                    }

                    guard let snapshot, snapshot.exists else {
                        self.errorMessage = "組織情報が見つかりません"
                        print("⚠️ OrganizationStore: organization not found:", organizationId)
                        return
                    }

                    self.applySnapshot(snapshot)
                    print("✅ Member OrganizationStore loaded:", self.organizationId, self.organizationName)
                }
            }
    }

    func loadOrganization(organizationId: String) async {
        guard !organizationId.isEmpty else {
            reset()
            errorMessage = "organizationId が空です"
            return
        }

        self.organizationId = organizationId
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db
                .collection("organizations")
                .document(organizationId)
                .getDocument()

            isLoading = false

            guard snapshot.exists else {
                errorMessage = "組織情報が見つかりません"
                return
            }

            applySnapshot(snapshot)

            print("✅ Member OrganizationStore loaded once:", self.organizationId, self.organizationName)

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("❌ Member OrganizationStore load error:", error.localizedDescription)
        }
    }

    func reset() {
        listener?.remove()
        listener = nil

        isLoading = false
        organizationId = ""
        organizationName = ""
        organizationCode = ""
        openingEnabled = false
        openingImageURL = ""
        logoImageURL = ""
        homepageURL = ""
        isActive = true
        errorMessage = nil
    }

    func findOrganization(byCode code: String) async {
        let trimmed = code
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "団体コードを入力してください"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db
                .collection("organizations")
                .whereField("organizationCode", isEqualTo: trimmed)
                .limit(to: 1)
                .getDocuments()

            isLoading = false

            guard let document = snapshot.documents.first else {
                errorMessage = "団体が見つかりません"
                return
            }

            let organizationId = document.documentID

            print("✅ findOrganization success:", organizationId)

            startListening(organizationId: organizationId)

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription

            print("❌ findOrganization error:", error.localizedDescription)
        }
    }

    private func applySnapshot(_ snapshot: DocumentSnapshot) {
        let data = snapshot.data() ?? [:]

        organizationId = snapshot.documentID

        organizationCode =
            data["organizationCode"] as? String
            ?? snapshot.documentID

        organizationName =
            data["displayName"] as? String
            ?? data["name"] as? String
            ?? snapshot.documentID

        openingEnabled =
            data["openingEnabled"] as? Bool
            ?? false

        openingImageURL =
            data["openingImageURL"] as? String
            ?? ""

        logoImageURL =
            data["logoImageURL"] as? String
            ?? ""

        homepageURL =
            data["homepageURL"] as? String
            ?? ""

        isActive =
            data["isActive"] as? Bool
            ?? true
    }
}
