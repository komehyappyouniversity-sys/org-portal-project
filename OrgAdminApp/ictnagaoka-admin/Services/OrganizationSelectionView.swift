import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct OrganizationSelectionView: View {
    var onCompleted: (OrganizationModel) -> Void

    @State private var organizationCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    private let organizationService = OrganizationService()
    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Text("組織コードを入力")
                        .font(.title2.bold())

                    Text("統括アプリで作成した組織コードを入力してください。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("例：KOME-2026", text: $organizationCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if !successMessage.isEmpty {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        await connectOrganization()
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("この組織に接続")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || organizationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal)

                Spacer()

                Text("一度接続すると、次回から自動でこの組織の管理アプリとして起動します。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .navigationTitle("組織設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    private func connectOrganization() async {
        let code = organizationCode
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !code.isEmpty else {
            errorMessage = "組織コードを入力してください。"
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "ログイン情報が取得できません。再ログインしてください。"
            return
        }

        isLoading = true
        errorMessage = ""
        successMessage = ""

        do {
            guard let organization = try await organizationService.findOrganization(byCode: code) else {
                isLoading = false
                errorMessage = "この組織コードの組織が見つかりません。"
                return
            }

            guard organization.isActive else {
                isLoading = false
                errorMessage = "この組織は現在停止中です。"
                return
            }

            let adminSnapshot = try await db.collection("organizations")
                .document(organization.id)
                .collection("admins")
                .document(uid)
                .getDocument()

            let adminData = adminSnapshot.data() ?? [:]
            let isActiveAdmin = adminData["isActive"] as? Bool ?? false

            guard isActiveAdmin else {
                isLoading = false
                errorMessage = "この組織の管理者として登録されていません。"
                return
            }

            try organizationService.saveLocalOrganizationSelection(
                organizationId: organization.id,
                organizationCode: organization.organizationCode
            )

            successMessage = "\(organization.displayName) に接続しました。"
            isLoading = false

            onCompleted(organization)

        } catch {
            isLoading = false
            errorMessage = "組織への接続に失敗しました: \(error.localizedDescription)"
        }
    }
}
