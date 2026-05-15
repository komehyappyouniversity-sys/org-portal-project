import SwiftUI
import FirebaseFirestore

struct AdminMemberItem: Identifiable {
    let id: String
    let name: String
    let status: String
    let email: String
    let phone: String
    let categories: [String]
}

struct AdminMemberListView: View {
    @EnvironmentObject var organizationStore: AdminOrganizationStore

    @State private var members: [AdminMemberItem] = []
    @State private var isLoading = false
    @State private var errorMessage = ""

    private let db = Firestore.firestore()

    var body: some View {
        List {
            ForEach(members) { member in
                NavigationLink {
                    AdminMemberCategoryEditView(
                        organizationId: organizationStore.organization.id,
                        member: member
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(member.name.isEmpty ? "名称未設定" : member.name)
                            .font(.headline)

                        Text(member.email)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        if member.categories.isEmpty {
                            Text("カテゴリ未設定")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("カテゴリ: \(member.categories.joined(separator: "、"))")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }

                        Text(member.status)
                            .font(.caption)
                            .foregroundColor(member.status == "approved" ? .green : .orange)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("会員一覧")
        .overlay {
            if isLoading {
                ProgressView("読み込み中...")
            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else if members.isEmpty {
                Text("会員がいません")
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            fetch()
        }
    }

    private func fetch() {
        let orgId = organizationStore.organization.id.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId がありません"
            return
        }

        isLoading = true
        errorMessage = ""

        db.collection("organizations")
            .document(orgId)
            .collection("members")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                let docs = snapshot?.documents ?? []

                self.members = docs.map { doc in
                    let data = doc.data()

                    let arrayCategories = data["categories"] as? [String] ?? []

                    let legacyString = data["categories"] as? String ?? ""
                    let legacyCategories = legacyString
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    let categories = arrayCategories.isEmpty ? legacyCategories : arrayCategories

                    return AdminMemberItem(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "",
                        status: data["status"] as? String ?? "",
                        email: data["email"] as? String ?? "",
                        phone: data["phone"] as? String ?? "",
                        categories: categories
                    )
                }

                self.isLoading = false
            }
    }
}
