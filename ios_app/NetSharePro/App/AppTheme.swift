import SwiftUI

enum AppTheme {
    static let background = Color(hex: 0x0F172A)
    static let card = Color(hex: 0x1E293B)
    static let cardLine = Color(hex: 0x334155)
    static let accent = Color(hex: 0x3B82F6)
    static let accentLight = Color(hex: 0x60A5FA)
    static let teal = Color(hex: 0x10B981)
    static let tealLight = Color(hex: 0x2DD4BF)
    static let danger = Color(hex: 0xEF4444)
    static let warning = Color(hex: 0xF59E0B)
    static let primaryText = Color.white
    static let secondaryText = Color(hex: 0x94A3B8)

    static let accentGradient = LinearGradient(
        colors: [accent, accentLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dangerGradient = LinearGradient(
        colors: [danger, Color(hex: 0xDC2626)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.card)
        )
    }
}
