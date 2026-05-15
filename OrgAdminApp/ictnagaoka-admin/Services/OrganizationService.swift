import Foundation
import FirebaseFirestore

struct LocalOrganizationSelection: Codable {
    let organizationId: String
    let organizationCode: String
}

struct OrganizationModel: Equatable {
    let id: String
    let organizationCode: String
    let displayName: String
    let openingEnabled: Bool
    let openingImageURL: String
    let logoImageURL: String
    let isActive: Bool

    static let empty = OrganizationModel(
        id: "",
        organizationCode: "",
        displayName: "",
        openingEnabled: false,
        openingImageURL: "",
        logoImageURL: "",
        isActive: false
    )
}

protocol OrganizationServiceProtocol {
    func fetchOrganization(organizationId: String) async throws -> OrganizationModel
    func findOrganization(byCode code: String) async throws -> OrganizationModel?

    func listenOrganization(
        organizationId: String,
        onChange: @escaping (Result<OrganizationModel, Error>) -> Void
    ) -> ListenerRegistration

    func saveLocalOrganizationSelection(
        organizationId: String,
        organizationCode: String
    ) throws

    func loadLocalOrganizationSelection() throws -> LocalOrganizationSelection?
    func clearLocalOrganizationSelection() throws
}

final class OrganizationService: OrganizationServiceProtocol {

    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    private let localSelectionKey = "localOrganizationSelection"

    func fetchOrganization(organizationId: String) async throws -> OrganizationModel {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            throw Self.makeError("organizationId が空です。")
        }

        let snapshot = try await db
            .collection("organizations")
            .document(orgId)
            .getDocument()

        guard snapshot.exists, let data = snapshot.data() else {
            throw Self.makeError("組織情報が見つかりません。")
        }

        return Self.makeOrganizationModel(
            id: snapshot.documentID,
            data: data
        )
    }

    func findOrganization(byCode code: String) async throws -> OrganizationModel? {
        let orgCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !orgCode.isEmpty else {
            return nil
        }

        let snapshot = try await db
            .collection("organizations")
            .document(orgCode)
            .getDocument()

        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }

        return Self.makeOrganizationModel(
            id: snapshot.documentID,
            data: data
        )
    }

    func listenOrganization(
        organizationId: String,
        onChange: @escaping (Result<OrganizationModel, Error>) -> Void
    ) -> ListenerRegistration {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        return db
            .collection("organizations")
            .document(orgId)
            .addSnapshotListener { snapshot, error in

                if let error {
                    onChange(.failure(error))
                    return
                }

                guard
                    let snapshot,
                    snapshot.exists,
                    let data = snapshot.data()
                else {
                    onChange(.failure(Self.makeError("組織情報が取得できません。")))
                    return
                }

                let organization = Self.makeOrganizationModel(
                    id: snapshot.documentID,
                    data: data
                )

                onChange(.success(organization))
            }
    }

    func saveLocalOrganizationSelection(
        organizationId: String,
        organizationCode: String
    ) throws {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let orgCode = organizationCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            throw Self.makeError("保存する organizationId が空です。")
        }

        guard !orgCode.isEmpty else {
            throw Self.makeError("保存する organizationCode が空です。")
        }

        let selection = LocalOrganizationSelection(
            organizationId: orgId,
            organizationCode: orgCode
        )

        let data = try JSONEncoder().encode(selection)
        userDefaults.set(data, forKey: localSelectionKey)
    }

    func loadLocalOrganizationSelection() throws -> LocalOrganizationSelection? {
        guard let data = userDefaults.data(forKey: localSelectionKey) else {
            return nil
        }

        return try JSONDecoder().decode(
            LocalOrganizationSelection.self,
            from: data
        )
    }

    func clearLocalOrganizationSelection() throws {
        userDefaults.removeObject(forKey: localSelectionKey)
    }

    private static func makeOrganizationModel(
        id: String,
        data: [String: Any]
    ) -> OrganizationModel {
        let code = data["organizationCode"] as? String ?? id

        let displayName =
            data["displayName"] as? String ??
            data["name"] as? String ??
            id

        return OrganizationModel(
            id: id,
            organizationCode: code,
            displayName: displayName,
            openingEnabled: data["openingEnabled"] as? Bool ?? false,
            openingImageURL: data["openingImageURL"] as? String ?? "",
            logoImageURL: data["logoImageURL"] as? String ?? "",
            isActive: data["isActive"] as? Bool ?? true
        )
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(
            domain: "OrganizationService",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: message
            ]
        )
    }
}
