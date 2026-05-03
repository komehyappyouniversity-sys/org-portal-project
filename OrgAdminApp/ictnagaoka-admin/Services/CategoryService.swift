//
//  CategoryService.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/15.
//

import Foundation
import FirebaseFirestore

struct CategoryItem: Identifiable, Hashable {
    let id: String
    let organizationId: String
    let name: String
    let sortOrder: Int
    let isActive: Bool
}

struct CategoryPayload {
    let organizationId: String
    let name: String
    let sortOrder: Int
    let isActive: Bool
}

protocol CategoryServiceProtocol {
    func fetchCategories(organizationId: String) async throws -> [CategoryItem]
    func listenCategories(
        organizationId: String,
        onChange: @escaping (Result<[CategoryItem], Error>) -> Void
    ) -> ListenerRegistration
    func createCategory(_ payload: CategoryPayload) async throws
    func updateCategory(categoryId: String, payload: CategoryPayload) async throws
    func deleteCategory(categoryId: String) async throws
    func updateMemberCategories(memberUid: String, organizationId: String, categories: [String]) async throws
}

final class CategoryService: CategoryServiceProtocol {
    private let db = Firestore.firestore()

    func fetchCategories(organizationId: String) async throws -> [CategoryItem] {
        let snapshot = try await db.collection("categories")
            .whereField("organizationId", isEqualTo: organizationId)
            .order(by: "sortOrder", descending: false)
            .getDocuments()

        return snapshot.documents.map { document in
            let data = document.data()
            return CategoryItem(
                id: document.documentID,
                organizationId: data["organizationId"] as? String ?? "",
                name: data["name"] as? String ?? "",
                sortOrder: data["sortOrder"] as? Int ?? 0,
                isActive: data["isActive"] as? Bool ?? true
            )
        }
    }

    func listenCategories(
        organizationId: String,
        onChange: @escaping (Result<[CategoryItem], Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("categories")
            .whereField("organizationId", isEqualTo: organizationId)
            .order(by: "sortOrder", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                guard let snapshot else {
                    onChange(.success([]))
                    return
                }

                let items = snapshot.documents.map { document in
                    let data = document.data()
                    return CategoryItem(
                        id: document.documentID,
                        organizationId: data["organizationId"] as? String ?? "",
                        name: data["name"] as? String ?? "",
                        sortOrder: data["sortOrder"] as? Int ?? 0,
                        isActive: data["isActive"] as? Bool ?? true
                    )
                }

                onChange(.success(items))
            }
    }

    func createCategory(_ payload: CategoryPayload) async throws {
        let now = Timestamp(date: Date())

        let data: [String: Any] = [
            "organizationId": payload.organizationId,
            "name": payload.name,
            "sortOrder": payload.sortOrder,
            "isActive": payload.isActive,
            "createdAt": now,
            "updatedAt": now
        ]

        try await db.collection("categories").addDocument(data: data)
    }

    func updateCategory(categoryId: String, payload: CategoryPayload) async throws {
        let data: [String: Any] = [
            "organizationId": payload.organizationId,
            "name": payload.name,
            "sortOrder": payload.sortOrder,
            "isActive": payload.isActive,
            "updatedAt": Timestamp(date: Date())
        ]

        try await db.collection("categories").document(categoryId).updateData(data)
    }

    func deleteCategory(categoryId: String) async throws {
        try await db.collection("categories").document(categoryId).delete()
    }

    func updateMemberCategories(memberUid: String, organizationId: String, categories: [String]) async throws {
        try await db.collection("members").document(memberUid).updateData([
            "organizationId": organizationId,
            "categories": categories,
            "updatedAt": Timestamp(date: Date())
        ])
    }
}
