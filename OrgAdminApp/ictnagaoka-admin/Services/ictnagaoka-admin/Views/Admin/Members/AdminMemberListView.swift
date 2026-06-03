import SwiftUI
import FirebaseFirestore

struct AdminMemberItem: Identifiable {
    let id: String
    let name: String
    let status: String
    let email: String
    let phone: String
    let categories: [String]
    let isAdmin: Bool
}

struct AdminMemberListView: View {
    @EnvironmentObject var organizationStore: AdminOrganizationStore

    @State private var members: [AdminMemberItem] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var selectedMember: AdminMemberItem?
    @State private var showPromoteAlert = false

    private let db = Firestore.firestore()

    private var organizationId: String {
        organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            ForEach(members) { member in
                NavigationLink {
                    AdminMemberCategoryEditView(
                        organizationId: organizationId,
                        member: member
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(member.name.isEmpty ? "名称未設定" : member.name)
                                .font(.headline)

                            if member.isAdmin {
                                Text("管理者")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }

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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !member.isAdmin {
                        Button {
                            selectedMember = member
                            showPromoteAlert = true
                        } label: {
                            Label("管理者へ昇格", systemImage: "person.badge.key")
                        }
                        .tint(.blue)
                    }
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
        .alert("管理者へ昇格しますか？", isPresented: $showPromoteAlert) {
            Button("キャンセル", role: .cancel) {}

            Button("昇格する") {
                if let selectedMember {
                    promoteToAdmin(selectedMember)
                }
            }
        } message: {
            Text("\(selectedMember?.name.isEmpty == false ? selectedMember?.name ?? "" : "この会員") を管理者として登録します。")
        }
        .onAppear {
            print("👀 管理アプリ 会員一覧 organizationId:", organizationId)
            fetch()
        }
    }

    private func fetch() {
        let orgId = organizationId

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
                    print("🔥 members 取得エラー:", error.localizedDescription)

                    self.errorMessage = error.localizedDescription
                    self.isLoading = false

                    return
                }

                let docs = snapshot?.documents ?? []

                print("👥 members docs count:", docs.count)
                print("👥 members docIDs:", docs.map { $0.documentID })

                Task {
                    let loadedMembers: [AdminMemberItem] = await {
                        var result: [AdminMemberItem] = []

                        for doc in docs {
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

                            let adminDoc = try? await db
                                .collection("organizations")
                                .document(orgId)
                                .collection("admins")
                                .document(doc.documentID)
                                .getDocument()

                            let adminData = adminDoc?.data()
                            let isAdmin = adminData?["isActive"] as? Bool ?? false

                            result.append(
                                AdminMemberItem(
                                    id: doc.documentID,
                                    name: data["name"] as? String ?? "",
                                    status: data["status"] as? String ?? "",
                                    email: data["email"] as? String ?? "",
                                    phone: data["phone"] as? String ?? "",
                                    categories: categories,
                                    isAdmin: isAdmin
                                )
                            )
                        }

                        return result
                    }()

                    await MainActor.run {
                        self.members = loadedMembers
                        self.isLoading = false
                    }
                }
            }
    }

    private func promoteToAdmin(_ member: AdminMemberItem) {
        let orgId = organizationId

        guard !orgId.isEmpty else {
            errorMessage = "organizationId がありません"
            return
        }

        isLoading = true
        errorMessage = ""

        let batch = db.batch()

        let adminRef = db
            .collection("organizations")
            .document(orgId)
            .collection("admins")
            .document(member.id)

        batch.setData([
            "uid": member.id,
            "name": member.name,
            "email": member.email,
            "isActive": true,
            "role": "admin",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: adminRef, merge: true)

        let memberRef = db
            .collection("organizations")
            .document(orgId)
            .collection("members")
            .document(member.id)

        batch.setData([
            "isAdmin": true,
            "adminRole": "admin",
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: memberRef, merge: true)

        batch.commit { error in
            if let error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return
            }

            self.fetch()
        }
    }
}
