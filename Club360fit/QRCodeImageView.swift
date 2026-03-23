import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Renders a QR code for a string (e.g. Venmo URL, Zelle email).
enum QRCodeGenerator {
    static func uiImage(from string: String, scale: CGFloat = 8) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct QRCodeImageView: View {
    let content: String
    var body: some View {
        Group {
            if let img = QRCodeGenerator.uiImage(from: content) {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
