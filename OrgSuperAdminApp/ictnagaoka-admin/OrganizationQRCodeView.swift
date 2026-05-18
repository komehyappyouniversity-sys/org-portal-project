import SwiftUI
import UIKit

struct OrganizationQRCodeView: View {
    let title: String
    let organizationName: String
    let organizationId: String

    private var qrImage: UIImage {
        QRCodeGenerator.generate(from: organizationId)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.title2.bold())

            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 260)
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 8) {
                Text("組織名")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(organizationName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("QRコード発行")
        .navigationBarTitleDisplayMode(.inline)
    }
}
