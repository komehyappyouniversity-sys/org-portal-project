import SwiftUI
import AVFoundation

struct MemberQRCodeScannerView: UIViewControllerRepresentable {

    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> MemberScannerViewController {
        let controller = MemberScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(
        _ uiViewController: MemberScannerViewController,
        context: Context
    ) {
    }
}

final class MemberScannerViewController:
    UIViewController,
    AVCaptureMetadataOutputObjectsDelegate {

    var onCodeScanned: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScanner()
    }

    private func setupScanner() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()

        if session.canAddOutput(output) {
            session.addOutput(output)

            output.setMetadataObjectsDelegate(
                self,
                queue: DispatchQueue.main
            )

            output.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill

        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else {
            return
        }

        didScan = true
        session.stopRunning()
        onCodeScanned?(value)
    }
}
