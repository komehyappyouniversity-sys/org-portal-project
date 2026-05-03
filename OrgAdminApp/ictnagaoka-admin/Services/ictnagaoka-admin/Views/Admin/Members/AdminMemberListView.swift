//
//  AdminMemberListView.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/15.
//

import SwiftUI
import FirebaseFirestore

struct AdminMemberItem: Identifiable {
    let id: String
    let name: String
    let status: String
    let email: String
    let phone: String
}

struct AdminMemberListView: View {
    @EnvironmentObject var organizationStore: OrganizationStore

    @State private var members: [AdminMemberItem] = []
    @State private var isLoading = false
    @State private var errorMessage = ""

    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 0) {
            if organizationStore.organizationId.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)

                    Text("organizationId がありません")
                        .font(.headline)

                    Text("組織情報を取得できていないため、会員一覧を表示できません。")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()

            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView("読み込み中...")
                    Text("organizationId: \(organizationStore.organizationId)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()

            } else if !errorMessage.isEmpty {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)

                    Text("organizationId: \(organizationStore.organizationId)")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button("再読み込み") {
                        fetch()
                    }
                }
                .padding()

            } else if members.isEmpty {
                VStack(spacing: 12) {
                    Text("会員がいません")
                        .foregroundColor(.gray)

                    Text("organizationId: \(organizationStore.organizationId)")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button("再読み込み") {
                        fetch()
                    }
                }
                .padding()

            } else {
                List(members) { member in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(member.name.isEmpty ? "名称未設定" : member.name)
                            .font(.headline)

                        if !member.email.isEmpty {
                            Text(member.email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        if !member.phone.isEmpty {
                            Text(member.phone)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Text(member.status)
                            .font(.caption)
                            .foregroundColor(member.status == "approved" ? .green : .orange)
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("会員一覧")
        .onAppear {
            print("📌 AdminMemberListView organizationId:", organizationStore.organizationId)
            fetch()
        }
    }

    private func fetch() {
        let safeOrganizationId = organizationStore.organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeOrganizationId.isEmpty else {
            members = []
            errorMessage = "organizationId がありません"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = ""

        print("📘 members fetch path: organizations/\(safeOrganizationId)/members")

        db.collection("organizations")
            .document(safeOrganizationId)
            .collection("members")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error {
                    print("❌ members fetch error:", error.localizedDescription)
                    errorMessage = error.localizedDescription
                    isLoading = false
                    return
                }

                let docs = snapshot?.documents ?? []

                print("✅ members count:", docs.count)

                self.members = docs.map { doc in
                    AdminMemberItem(
                        id: doc.documentID,
                        name: doc["name"] as? String ?? "",
                        status: doc["status"] as? String ?? "",
                        email: doc["email"] as? String ?? "",
                        phone: doc["phone"] as? String ?? ""
                    )
                }

                isLoading = false
            }
    }
}
