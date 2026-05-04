import Foundation
import Combine
import FirebaseFirestore

struct AdminCategoryItem: Identifiable, Equatable {
    let id: String
    let name: String
}

@MainActor
final class AdminCategoryStore: ObservableObject {
    @Published var categories: [AdminCategoryItem] = []
    @Published var newCategoryName: String = ""
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId が取得できません。"
            return
        }

        listener?.remove()
        isLoading = true
        errorMessage = ""

        listener = db
            .collection("organizations")
            .document(orgId)
            .collection("categories")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    self.categories = snapshot?.documents.compactMap { doc in
                        let data = doc.data()
                        guard let name = data["name"] as? String else { return nil }
                        return AdminCategoryItem(id: doc.documentID, name: name)
                    } ?? []
                }
            }
    }

    func addCategory(organizationId: String) async {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId が取得できません。"
            return
        }

        guard !name.isEmpty else {
            errorMessage = "カテゴリ名を入力してください。"
            return
        }

        do {
            try await db
                .collection("organizations")
                .document(orgId)
                .collection("categories")
                .addDocument(data: [
                    "name": name,
                    "createdAt": FieldValue.serverTimestamp()
                ])

            newCategoryName = ""
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCategory(organizationId: String, categoryId: String) async {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId が取得できません。"
            return
        }

        do {
            try await db
                .collection("organizations")
                .document(orgId)
                .collection("categories")
                .document(categoryId)
                .delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
