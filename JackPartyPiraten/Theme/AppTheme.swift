import SwiftUI

enum AppTheme {
    static let accent = Color("AccentColor")
    static let bgBase = Color("BgBase")
    static let bgElevated = Color("BgElevated")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textMono = Color("TextMono")
    static let danger = Color("Danger")
    static let hairline = Color("Hairline")

    static var displayName: String {
        let display = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let trimmed = (display ?? name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "App" : trimmed
    }
}
