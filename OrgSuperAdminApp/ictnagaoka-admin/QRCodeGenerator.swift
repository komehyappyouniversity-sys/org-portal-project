import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    static func generate(from text: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }

        return UIImage(cgImage: cgImage)
    }
}
