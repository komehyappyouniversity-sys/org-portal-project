//
//  OrganizationService.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/15.
//

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
    func saveLocalOrganizationSelection(organizationId: String, organizationCode: String) throws
    func loadLocalOrganizationSelection() throws -> LocalOrganizationSelection?
    func clearLocalOrganizationSelection() throws
}

final class OrganizationService: OrganizationServiceProtocol {
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard

    private let localSelectionKey = "localOrganizationSelection"

    func fetchOrganization(organizationId: String) async throws -> OrganizationModel {
        let snapshot = try await db.collection("organizations").document(organizationId).getDocument()

        guard let data = snapshot.data() else {
            throw NSError(
                domain: "OrganizationService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "組織情報が見つかりません。"]
            )
        }

        return Self.makeOrganizationModel(id: snapshot.documentID, data: data)
    }

    func findOrganization(byCode code: String) async throws -> OrganizationModel? {
        let snapshot = try await db.collection("organizations")
            .whereField("organizationCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            return nil
        }

        return Self.makeOrganizationModel(id: document.documentID, data: document.data())
    }

    func listenOrganization(
        organizationId: String,
        onChange: @escaping (Result<OrganizationModel, Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("organizations").document(organizationId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                guard let snapshot, let data = snapshot.data() else {
                    onChange(.failure(NSError(
                        domain: "OrganizationService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "組織情報が取得できません。"]
                    )))
                    return
                }

                let model = Self.makeOrganizationModel(id: snapshot.documentID, data: data)
                onChange(.success(model))
            }
    }

    func saveLocalOrganizationSelection(organizationId: String, organizationCode: String) throws {
        let selection = LocalOrganizationSelection(
            organizationId: organizationId,
            organizationCode: organizationCode
        )

        let data = try JSONEncoder().encode(selection)
        userDefaults.set(data, forKey: localSelectionKey)
    }

    func loadLocalOrganizationSelection() throws -> LocalOrganizationSelection? {
        guard let data = userDefaults.data(forKey: localSelectionKey) else {
            return nil
        }

        return try JSONDecoder().decode(LocalOrganizationSelection.self, from: data)
    }

    func clearLocalOrganizationSelection() throws {
        userDefaults.removeObject(forKey: localSelectionKey)
    }

    private static func makeOrganizationModel(id: String, data: [String: Any]) -> OrganizationModel {
        OrganizationModel(
            id: id,
            organizationCode: data["organizationCode"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "",
            openingEnabled: data["openingEnabled"] as? Bool ?? false,
            openingImageURL: data["openingImageURL"] as? String ?? "",
            logoImageURL: data["logoImageURL"] as? String ?? "",
            isActive: data["isActive"] as? Bool ?? true
        )
    }
}
