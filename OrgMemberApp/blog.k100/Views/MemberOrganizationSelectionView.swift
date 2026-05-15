import SwiftUI

struct MemberOrganizationSelectionView: View {

    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var featureStore: MemberFeatureStore

    @State private var organizationCode: String = ""
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 24) {

            Spacer()

            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue)

            VStack(spacing: 8) {

                Text("団体設定")
                    .font(.title.bold())

                Text("団体コードを入力")
                    .font(.title2.bold())

                Text("管理者から案内された団体コードを入力してください。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("例：k100u", text: $organizationCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)

            if let errorMessage = organizationStore.errorMessage,
               !errorMessage.isEmpty {

                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button {
                connectOrganization()

            } label: {

                HStack {

                    if isConnecting {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(
                        isConnecting
                        ? "接続中..."
                        : "この団体に接続"
                    )
                    .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.blue)
                .cornerRadius(16)
                .padding(.horizontal, 24)
            }
            .disabled(
                isConnecting
                || organizationCode
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
            )

            Text("一度接続すると、次回から自動でこの団体の会員アプリとして起動します。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.vertical, 24)
    }

    private func connectOrganization() {

        let code = organizationCode
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !code.isEmpty else {
            return
        }

        isConnecting = true

        Task {

            await organizationStore.findOrganization(byCode: code)

            if !organizationStore.organizationId.isEmpty {

                featureStore.startListening(
                    organizationId: organizationStore.organizationId
                )
            }

            isConnecting = false
        }
    }
}
