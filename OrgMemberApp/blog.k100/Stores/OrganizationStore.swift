import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class OrganizationStore: ObservableObject {
    @Published var organization: OrganizationModel = .empty
    @Published var organizationId: String = ""
    @Published var organizationCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service: OrganizationServiceProtocol
    private var listener: ListenerRegistration?

    init(service: OrganizationServiceProtocol? = nil) {
        self.service = service ?? OrganizationService()
    }

    deinit {
        listener?.remove()
    }

    func restoreFromLocal() {
        isLoading = true
        errorMessage = nil

        do {
            guard let selection = try service.loadLocalOrganizationSelection() else {
                isLoading = false
                organization = .empty
                organizationId = ""
                organizationCode = ""
                return
            }

            organizationId = selection.organizationId
            organizationCode = selection.organizationCode

            startListening(organizationId: selection.organizationId)

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func setupOrganization(byCode code: String) async -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "団体コードを入力してください。"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            guard let found = try await service.findOrganization(byCode: trimmed) else {
                isLoading = false
                errorMessage = "団体コードが見つかりません。"
                return false
            }

            guard found.isActive else {
                isLoading = false
                errorMessage = "この団体は現在利用停止中です。"
                return false
            }

            try service.saveLocalOrganizationSelection(
                organizationId: found.id,
                organizationCode: found.organizationCode
            )

            organizationId = found.id
            organizationCode = found.organizationCode
            organization = found

            startListening(organizationId: found.id)
            return true

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    func startListening(organizationId: String) {
        listener?.remove()
        isLoading = true
        errorMessage = nil

        self.organizationId = organizationId

        listener = service.listenOrganization(organizationId: organizationId) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success(let organization):
                    self.organization = organization
                    self.organizationCode = organization.organizationCode
                    self.isLoading = false
                    self.errorMessage = nil

                case .failure(let error):
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clearSelection() {
        listener?.remove()
        listener = nil

        do {
            try service.clearLocalOrganizationSelection()
        } catch {
            errorMessage = error.localizedDescription
        }

        organization = .empty
        organizationId = ""
        organizationCode = ""
        isLoading = false
    }

    func reload() async {
        guard !organizationId.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await service.fetchOrganization(organizationId: organizationId)
            organization = fetched
            organizationCode = fetched.organizationCode
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    var hasSelection: Bool {
        !organizationId.isEmpty
    }

    var displayName: String {
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
}
