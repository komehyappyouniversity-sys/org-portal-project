import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct AdminOrganization: Identifiable, Equatable {
    let id: String
    let name: String
    let isActive: Bool

    init(id: String, data: [String: Any]) {
        self.id = id

        let displayName = data["displayName"] as? String
        let name = data["name"] as? String

        self.name = displayName?.isEmpty == false
            ? displayName!
            : (name?.isEmpty == false ? name! : id)

        self.isActive = data["isActive"] as? Bool ?? true
    }
}

@MainActor
final class AdminOrganizationStore: ObservableObject {

    @Published var isLoading = false
    @Published var organizations: [AdminOrganization] = []
    @Published var selectedOrganization: AdminOrganization?
    @Published var errorMessage = ""

    @Published var organizationId: String = ""
    @Published var organizationName: String = ""

    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?

    private let selectedOrganizationIdKey = "admin_selected_organization_id"

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    func start() {
        if authHandle != nil {
            return
        }

        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }

                guard let user else {
                    self.clear()
                    return
                }

                await self.loadAvailableOrganizations(uid: user.uid)
            }
        }
    }

    func reload() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            clear()
            return
        }

        await loadAvailableOrganizations(uid: uid)
    }

    func selectOrganization(_ organization: AdminOrganization) {
        selectedOrganization = organization
        organizationId = organization.id
        organizationName = organization.name
        errorMessage = ""

        UserDefaults.standard.set(
            organization.id,
            forKey: selectedOrganizationIdKey
        )

        print("✅ 管理アプリ 組織切替: \(organization.id) / \(organization.name)")
    }
    func startListening(organizationId newOrganizationId: String) {
        if let organization = organizations.first(where: { $0.id == newOrganizationId }) {
            selectOrganization(organization)
            return
        }

        organizationId = newOrganizationId
        organizationName = newOrganizationId
        errorMessage = ""

        UserDefaults.standard.set(
            newOrganizationId,
            forKey: selectedOrganizationIdKey
        )

        print("✅ 管理アプリ 組織ID指定: \(newOrganizationId)")
    }

    private func loadAvailableOrganizations(uid: String) async {
        isLoading = true
        errorMessage = ""

        do {
            let snapshot = try await db.collection("organizations")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()

            var availableOrganizations: [AdminOrganization] = []

            for document in snapshot.documents {
                let orgId = document.documentID

                let adminDoc = try await db.collection("organizations")
                    .document(orgId)
                    .collection("admins")
                    .document(uid)
                    .getDocument()

                guard adminDoc.exists else {
                    continue
                }

                let adminData = adminDoc.data() ?? [:]
                let isAdminActive = adminData["isActive"] as? Bool ?? false

                guard isAdminActive else {
                    continue
                }

                let organization = AdminOrganization(
                    id: orgId,
                    data: document.data()
                )

                availableOrganizations.append(organization)
            }

            availableOrganizations.sort {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }

            organizations = availableOrganizations

            restoreSelectedOrganization()

            if organizations.isEmpty {
                errorMessage = "管理できる組織がありません。"
                organizationId = ""
                organizationName = ""
                selectedOrganization = nil
            }

        } catch {
            errorMessage = "組織の取得に失敗しました: \(error.localizedDescription)"
            print("❌ 管理アプリ 組織取得エラー:", error.localizedDescription)
        }

        isLoading = false
    }

    private func restoreSelectedOrganization() {
        let savedId = UserDefaults.standard.string(
            forKey: selectedOrganizationIdKey
        )

        if let savedId,
           let savedOrganization = organizations.first(where: { $0.id == savedId }) {
            selectOrganization(savedOrganization)
            return
        }

        if let firstOrganization = organizations.first {
            selectOrganization(firstOrganization)
            return
        }

        selectedOrganization = nil
        organizationId = ""
        organizationName = ""
    }

    private func clear() {
        isLoading = false
        organizations = []
        selectedOrganization = nil
        errorMessage = ""
        organizationId = ""
        organizationName = ""
    }
}
