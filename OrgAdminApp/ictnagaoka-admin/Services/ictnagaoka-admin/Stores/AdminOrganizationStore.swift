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

        if let displayName, !displayName.isEmpty {
            self.name = displayName
        } else if let name, !name.isEmpty {
            self.name = name
        } else {
            self.name = id
        }

        self.isActive = data["isActive"] as? Bool ?? true
    }
}

@MainActor
final class AdminOrganizationStore: ObservableObject {

    @Published var isLoading = false
    @Published var availableOrganizations: [AdminOrganization] = []
    @Published var currentOrganization: AdminOrganization?
    @Published var currentOrganizationId = ""
    @Published var currentOrganizationName = ""
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?

    private let currentOrganizationIdKey = "admin_current_organization_id"

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
        currentOrganization = organization
        currentOrganizationId = organization.id
        currentOrganizationName = organization.name
        errorMessage = ""

        UserDefaults.standard.set(
            organization.id,
            forKey: currentOrganizationIdKey
        )

        print("✅ 管理アプリ 現在の組織: \(organization.id) / \(organization.name)")
    }

    func startListening(organizationId newOrganizationId: String) {
        if let organization = availableOrganizations.first(where: { $0.id == newOrganizationId }) {
            selectOrganization(organization)
            return
        }

        currentOrganization = nil
        currentOrganizationId = newOrganizationId
        currentOrganizationName = newOrganizationId
        errorMessage = ""

        UserDefaults.standard.set(
            newOrganizationId,
            forKey: currentOrganizationIdKey
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

            var results: [AdminOrganization] = []

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

                results.append(
                    AdminOrganization(
                        id: orgId,
                        data: document.data()
                    )
                )
            }

            results.sort {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }

            availableOrganizations = results
            restoreCurrentOrganization()

            if availableOrganizations.isEmpty {
                errorMessage = "管理できる組織がありません。"
                clearCurrentOrganizationOnly()
            }

        } catch {
            errorMessage = "組織の取得に失敗しました: \(error.localizedDescription)"
            print("❌ 管理アプリ 組織取得エラー:", error.localizedDescription)
        }

        isLoading = false
    }

    private func restoreCurrentOrganization() {
        let savedId = UserDefaults.standard.string(
            forKey: currentOrganizationIdKey
        )

        if let savedId,
           let savedOrganization = availableOrganizations.first(where: { $0.id == savedId }) {
            selectOrganization(savedOrganization)
            return
        }

        if let firstOrganization = availableOrganizations.first {
            selectOrganization(firstOrganization)
            return
        }

        clearCurrentOrganizationOnly()
    }

    private func clearCurrentOrganizationOnly() {
        currentOrganization = nil
        currentOrganizationId = ""
        currentOrganizationName = ""
    }

    private func clear() {
        isLoading = false
        availableOrganizations = []
        errorMessage = ""
        clearCurrentOrganizationOnly()
    }
}
