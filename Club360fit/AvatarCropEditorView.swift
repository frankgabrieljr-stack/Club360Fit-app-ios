import SwiftUI
import UIKit

/// Circular avatar cropper with pinch-to-zoom and drag-to-position.
struct AvatarCropEditorView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onUse: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var cropError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Club360ScreenBackground()

                VStack(spacing: 16) {
                    GeometryReader { proxy in
                        let side = min(proxy.size.width, proxy.size.height)
                        let frame = CGSize(width: side, height: side)

                        ZStack {
                            Color.black.opacity(0.12)

                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: frame.width, height: frame.height)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(dragGesture(cropSide: side))
                                .simultaneousGesture(magnificationGesture(cropSide: side))

                            Circle()
                                .stroke(Color.white.opacity(0.95), lineWidth: 2.5)
                                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                        }
                        .frame(width: side, height: side)
                        .clipShape(Rectangle())
                        .overlay(alignment: .top) {
                            Text("Pinch to zoom, drag to reposition")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .foregroundStyle(Club360Theme.cardTitle)
                                .padding(.top, 10)
                        }
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    }
                    .frame(height: 360)

                    if let cropError {
                        Text(cropError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 12) {
                        Button("Cancel", role: .cancel) {
                            onCancel()
                        }
                        .buttonStyle(.bordered)
                        .tint(Club360Theme.burgundy)

                        Button("Use photo") {
                            guard let out = croppedAvatarImage(cropSide: 360) else {
                                cropError = "Could not crop this photo. Try another image."
                                return
                            }
                            onUse(out)
                        }
                        .buttonStyle(Club360PrimaryGradientButtonStyle())
                    }
                }
                .padding(18)
            }
            .navigationTitle("Edit photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }

    private func dragGesture(cropSide: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, cropSide: cropSide, scale: scale)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func magnificationGesture(cropSide: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = max(1, min(4, lastScale * value))
                scale = proposed
                offset = clampedOffset(offset, cropSide: cropSide, scale: proposed)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
            }
    }

    private func clampedOffset(_ proposed: CGSize, cropSide: CGFloat, scale: CGFloat) -> CGSize {
        let displayed = displayedImageSize(cropSide: cropSide, scale: scale)
        let maxX = max(0, (displayed.width - cropSide) / 2)
        let maxY = max(0, (displayed.height - cropSide) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func displayedImageSize(cropSide: CGFloat, scale: CGFloat) -> CGSize {
        let iw = image.size.width
        let ih = image.size.height
        guard iw > 0, ih > 0 else { return CGSize(width: cropSide, height: cropSide) }
        let base = max(cropSide / iw, cropSide / ih)
        return CGSize(width: iw * base * scale, height: ih * base * scale)
    }

    private func croppedAvatarImage(cropSide: CGFloat) -> UIImage? {
        guard let normalized = normalizedUIImage(image),
              let cg = normalized.cgImage else { return nil }

        let iw = normalized.size.width
        let ih = normalized.size.height
        guard iw > 0, ih > 0 else { return nil }

        let base = max(cropSide / iw, cropSide / ih)
        let total = base * scale
        let dispW = iw * total
        let dispH = ih * total
        let originX = (cropSide - dispW) / 2 + offset.width
        let originY = (cropSide - dispH) / 2 + offset.height

        let srcX = -originX / total
        let srcY = -originY / total
        let srcSize = cropSide / total
        var rect = CGRect(x: srcX, y: srcY, width: srcSize, height: srcSize)
        rect = rect.intersection(CGRect(origin: .zero, size: CGSize(width: iw, height: ih)))
        guard rect.width > 1, rect.height > 1 else { return nil }

        let pxRect = CGRect(
            x: rect.origin.x * normalized.scale,
            y: rect.origin.y * normalized.scale,
            width: rect.size.width * normalized.scale,
            height: rect.size.height * normalized.scale
        ).integral

        guard let cropped = cg.cropping(to: pxRect) else { return nil }
        return UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up)
    }

    private func normalizedUIImage(_ source: UIImage) -> UIImage? {
        if source.imageOrientation == .up { return source }
        UIGraphicsBeginImageContextWithOptions(source.size, false, source.scale)
        defer { UIGraphicsEndImageContext() }
        source.draw(in: CGRect(origin: .zero, size: source.size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
