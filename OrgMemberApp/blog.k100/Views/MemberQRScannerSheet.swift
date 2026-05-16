import SwiftUI

struct MemberQRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onCodeScanned: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                MemberQRCodeScannerView { code in
                    onCodeScanned(code)
                    dismiss()
                }

                VStack {
                    Text("QRコードを読み取ってください")
                        .font(.headline)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("QRコード読み取り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}
