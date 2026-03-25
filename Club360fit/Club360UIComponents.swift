import SwiftUI

// MARK: - Screen background (burgundy & cream gradient)

struct Club360ScreenBackground: View {
    var body: some View {
        Club360Theme.backgroundGradient
            .ignoresSafeArea()
    }
}

// MARK: - Glass card (elevated: cream base + material + visible border)

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 26

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Club360Theme.cardBaseFill)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.thinMaterial)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.black.opacity(0.14),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.25
                    )
            )
            .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func club360Glass(cornerRadius: CGFloat = 26) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    /// Gradient behind `Form` / `List` (iOS 16+ hides default scroll background).
    func club360FormScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(Club360Theme.backgroundGradient.ignoresSafeArea())
    }
}

// MARK: - Primary CTA (burgundy gradient)

struct Club360PrimaryGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                Club360Theme.primaryButtonGradient
                    .opacity(configuration.isPressed ? 0.88 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Club360Theme.burgundy.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Segmented week progress (multi-color bar)

struct Club360SegmentedProgressBar: View {
    let value: Double // 0...1
    var segments: Int = 4

    private var segmentColors: [Color] {
        [
            Club360Theme.creamWarm,
            Club360Theme.taupe,
            Club360Theme.burgundyLight,
            Club360Theme.burgundy,
        ]
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<segments, id: \.self) { i in
                let fill = segmentFill(index: i)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(segmentColors[i % segmentColors.count].opacity(0.25 + 0.75 * fill))
                    .frame(maxWidth: .infinity)
                    .frame(height: 12)
            }
        }
    }

    private func segmentFill(index: Int) -> Double {
        let n = Double(segments)
        let start = Double(index) / n
        let end = Double(index + 1) / n
        if value >= end { return 1 }
        if value <= start { return 0 }
        return (value - start) / (end - start)
    }
}

// MARK: - Home / hub tiles (glass cards — shared client + coach hubs)

struct Club360HomeTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accent: Color = Club360Theme.burgundy

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(accent)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Club360Theme.cardTitle)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Club360Theme.cardSubtitle)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .club360Glass(cornerRadius: 28)
    }
}
