import SwiftUI

struct MemberOrganizationSelectionView: View {

    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var featureStore: MemberFeatureStore

    @State private var organizationCode: String = ""
    @State private var isConnecting = false
    @State private var showQRScanner = false

    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                Spacer(minLength: 40)

                Image("CommunityLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                VStack(spacing: 8) {

                    Text("コミュニティ設定")
                        .font(.title.bold())

                    Text("コードを入力")
                        .font(.title2.bold())

                    Text("""
管理者から案内されたコミュニティコードを入力、
またはQRコードを読み取ってください。
""")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                }

                TextField(
                    "コミュニティコード",
                    text: $organizationCode
                )
                .foregroundColor(.black)
                .tint(.blue)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isCodeFieldFocused)
                .padding()
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isCodeFieldFocused ? Color.blue : Color.gray.opacity(0.3),
                            lineWidth: isCodeFieldFocused ? 2 : 1
                        )
                )
                .cornerRadius(12)
                .onTapGesture {
                    isCodeFieldFocused = true
                }
                .padding(.horizontal, 24)

                Button {
                    showQRScanner = true
                } label: {
                    Label("QRコードを読み取る", systemImage: "qrcode.viewfinder")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
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
                            : "このコミュニティに接続"
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

                Text("""
一度接続すると、次回から自動でこのコミュニティの
会員アプリとして起動します。
""")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)

                Spacer(minLength: 40)
            }
            .padding(.vertical, 24)
        }
        .sheet(isPresented: $showQRScanner) {
            MemberQRScannerSheet { scannedCode in
                organizationCode = scannedCode
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                connectOrganization()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCodeFieldFocused = true
            }
        }
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
