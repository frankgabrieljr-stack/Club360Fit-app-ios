import Foundation

/// Matches Android `Int.toPounds()` on **whole kg** (`weightKg.toInt()` then × 2.20462).
enum Club360Units {
    static func displayPoundsFromKg(_ kg: Double?) -> String? {
        guard let kg else { return nil }
        let wholeKg = Int(kg.rounded(.towardZero))
        let lbs = Int((Double(wholeKg) * 2.20462).rounded())
        return "\(lbs) lbs"
    }
}
