import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

enum AdminMessageTargetType: String, CaseIterable, Identifiable {
    case approvedMembersOnly = "承認済み会員全員"
    case categoryMembers = "カテゴリ対象"
    case individual = "個別送信"

    var id: String { rawValue }
}

struct AdminMemberTarget: Identifiable, Hashable {
    let id: String
    let uid: String
    let name: String
    let categories: [String]

    init(uid: String, name: String, categories: [String]) {
        self.id = uid
        self.uid = uid
        self.name = name
        self.categories = categories
    }
}

@MainActor
final class AdminMessageComposerStore: ObservableObject {
    @Published var title: String = ""
    @Published var body: String = ""

    @Published var targetType: AdminMessageTargetType = .approvedMembersOnly
    @Published var selectedCategories: Set<String> = []
    @Published var selectedMemberUIDs: Set<String> = []

    @Published var members: [AdminMemberTarget] = []
    @Published var isLoadingMembers: Bool = false

    @Published var isSending: Bool = false
    @Published var errorMessage: String = ""
    @Published var successMessage: String = ""

    private let db = Firestore.firestore()

    func loadMembers(organizationId: String) async {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else {
            errorMessage = "organizationId が空です。"
            members = []
            return
        }

        isLoadingMembers = true
        errorMessage = ""

        do {
            let snapshot = try await db.collection("organizations")
                .document(trimmedOrganizationId)
                .collection("members")
                .getDocuments()

            let loaded: [AdminMemberTarget] = snapshot.documents.compactMap { doc in
                let data = doc.data()

                let status = (data["status"] as? String) ?? ""
                guard status == "approved" else { return nil }

                let name =
                    (data["name"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                let categories = data["categories"] as? [String] ?? []

                return AdminMemberTarget(
                    uid: doc.documentID,
                    name: name.isEmpty ? "名称未設定" : name,
                    categories: categories
                )
            }
            .sorted { $0.name < $1.name }

            members = loaded
            isLoadingMembers = false
        } catch {
            members = []
            isLoadingMembers = false
            errorMessage = error.localizedDescription
        }
    }

    var availableCategories: [String] {
        let all = members.flatMap { $0.categories }
        return Array(Set(all)).sorted()
    }

    func sendMessage(organizationId: String) async -> Bool {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else {
            errorMessage = "organizationId が空です。"
            successMessage = ""
            return false
        }

        guard !trimmedTitle.isEmpty else {
            errorMessage = "タイトルを入力してください。"
            successMessage = ""
            return false
        }

        guard !trimmedBody.isEmpty else {
            errorMessage = "本文を入力してください。"
            successMessage = ""
            return false
        }

        let selectedCategoryArray = Array(selectedCategories).sorted()
        let selectedUIDArray = Array(selectedMemberUIDs).sorted()

        switch targetType {
        case .approvedMembersOnly:
            break

        case .categoryMembers:
            guard !selectedCategoryArray.isEmpty else {
                errorMessage = "カテゴリを1つ以上選択してください。"
                successMessage = ""
                return false
            }

        case .individual:
            guard !selectedUIDArray.isEmpty else {
                errorMessage = "送信先会員を1人以上選択してください。"
                successMessage = ""
                return false
            }
        }

        isSending = true
        errorMessage = ""
        successMessage = ""

        let createdBy = Auth.auth().currentUser?.uid ?? ""

        var data: [String: Any] = [
            "organizationId": trimmedOrganizationId,
            "title": trimmedTitle,
            "body": trimmedBody,
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isReadBy": [],
            "notificationStatus": "pending",
            "notifiedCount": 0
        ]

        switch targetType {
        case .approvedMembersOnly:
            data["isBroadcast"] = true
            data["deliveryType"] = "承認済み会員全員"
            data["categoryTargets"] = []

        case .categoryMembers:
            data["isBroadcast"] = true
            data["deliveryType"] = "カテゴリ対象"
            data["categoryTargets"] = selectedCategoryArray

        case .individual:
            data["isBroadcast"] = false
            data["deliveryType"] = "個別送信"
            data["toUids"] = selectedUIDArray
            if selectedUIDArray.count == 1 {
                data["toUid"] = selectedUIDArray.first ?? ""
            }
        }

        do {
            try await db.collection("organizations")
                .document(trimmedOrganizationId)
                .collection("messages")
                .addDocument(data: data)

            title = ""
            body = ""
            selectedCategories.removeAll()
            selectedMemberUIDs.removeAll()

            isSending = false
            errorMessage = ""
            successMessage = "会員メッセージを送信しました。"
            return true
        } catch {
            isSending = false
            errorMessage = error.localizedDescription
            successMessage = ""
            return false
        }
    }
}
