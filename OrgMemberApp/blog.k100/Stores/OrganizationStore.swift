
import Foundation
import Combine
import FirebaseFirestore

struct MemberOrganization {
    let id: String
    let name: String
    let organizationCode: String
    let logoImageURL: String
    let logoDisplayHeight: Double
    let isActive: Bool

    static let empty = MemberOrganization(
        id: "",
        name: "",
        organizationCode: "",
        logoImageURL: "",
        logoDisplayHeight: 260,
        isActive: false
    )
}

@MainActor
final class OrganizationStore: ObservableObject {

    @Published var organization: MemberOrganization = .empty
    @Published var organizationId = ""
    @Published var organizationCode = ""
    @Published var displayName = ""
    @Published var logoImageURL = ""
    @Published var logoDisplayHeight: Double = 260
    @Published var isActive = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private let localOrganizationIdKey = "selectedOrganizationId"
    private let localOrganizationCodeKey = "selectedOrganizationCode"

    var hasSelection: Bool {
        !organizationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func restoreFromLocal() {
        let savedId = UserDefaults.standard.string(forKey: localOrganizationIdKey) ?? ""

        guard !savedId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        organizationId = savedId
        startListening(organizationId: savedId)
    }

    func startListening(organizationId: String) {
        stopListening()

        let trimmedId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedId.isEmpty else {
            errorMessage = "organizationId が空です。"
            return
        }

        self.organizationId = trimmedId
        isLoading = true
        errorMessage = nil

        listener = db.collection("organizations")
            .document(trimmedId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    self.isLoading = false

                    if let error {
                        self.errorMessage = "組織情報の取得に失敗しました。"
                        print("❌ organization listen error:", error.localizedDescription)
                        return
                    }

                    guard let snapshot,
                          snapshot.exists,
                          let data = snapshot.data() else {
                        self.errorMessage = "組織情報が見つかりません。"
                        self.organization = .empty
                        return
                    }

                    let name =
                        data["displayName"] as? String ??
                        data["name"] as? String ??
                        ""

                    let code =
                        data["organizationCode"] as? String ??
                        data["code"] as? String ??
                        trimmedId

                    let logoURL =
                        data["logoImageURL"] as? String ?? ""

                    let displayHeight =
                        data["logoDisplayHeight"] as? Double ?? 260

                    let active =
                        data["isActive"] as? Bool ?? true

                    self.organizationId = trimmedId
                    self.organizationCode = code
                    self.displayName = name
                    self.logoImageURL = logoURL
                    self.logoDisplayHeight = displayHeight
                    self.isActive = active

                    self.organization = MemberOrganization(
                        id: trimmedId,
                        name: name,
                        organizationCode: code,
                        logoImageURL: logoURL,
                        logoDisplayHeight: displayHeight,
                        isActive: active
                    )

                    self.errorMessage = nil

                    UserDefaults.standard.set(trimmedId, forKey: self.localOrganizationIdKey)
                    UserDefaults.standard.set(code, forKey: self.localOrganizationCodeKey)

                    print("✅ organization loaded:", trimmedId)
                    print("✅ organizationCode:", code)
                    print("✅ logoImageURL:", logoURL)
                    print("✅ logoDisplayHeight:", displayHeight)
                }
            }
    }

    func setupOrganization(byCode code: String) async -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCode.isEmpty else {
            errorMessage = "団体コードを入力してください。"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("organizations")
                .whereField("organizationCode", isEqualTo: trimmedCode)
                .limit(to: 1)
                .getDocuments()

            guard let document = snapshot.documents.first else {
                isLoading = false
                errorMessage = "団体コードが見つかりません。"
                return false
            }

            let foundId = document.documentID

            UserDefaults.standard.set(foundId, forKey: localOrganizationIdKey)
            UserDefaults.standard.set(trimmedCode, forKey: localOrganizationCodeKey)

            self.organizationId = foundId
            self.organizationCode = trimmedCode

            startListening(organizationId: foundId)

            isLoading = false
            return true

        } catch {
            isLoading = false
            errorMessage = "団体情報の確認に失敗しました。"
            print("❌ setup organization error:", error.localizedDescription)
            return false
        }
    }

    func clearSelection() {
        stopListening()

        UserDefaults.standard.removeObject(forKey: localOrganizationIdKey)
        UserDefaults.standard.removeObject(forKey: localOrganizationCodeKey)

        organization = .empty
        organizationId = ""
        organizationCode = ""
        displayName = ""
        logoImageURL = ""
        logoDisplayHeight = 260
        isActive = false
        isLoading = false
        errorMessage = nil
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }
}
