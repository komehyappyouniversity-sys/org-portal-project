import SwiftUI
import UIKit

struct OrganizationQRCodeView: View {
    let title: String
    let organizationName: String
    let organizationCode: String

    private var qrImage: UIImage {
        QRCodeGenerator.generate(from: organizationCode)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.title2.bold())

            Text(organizationName)
                .font(.headline)

            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 260)
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 8) {
                Text("登録コード")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(organizationCode)
                    .font(.title3.bold())
                    .textSelection(.enabled)
            }

            Button {
                UIPasteboard.general.string = organizationCode
            } label: {
                Label("コードをコピー", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("QRコード発行")
        .navigationBarTitleDisplayMode(.inline)
    }
}
