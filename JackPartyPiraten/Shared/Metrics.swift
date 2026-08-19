import SwiftUI

enum AppMetrics {
    static let screenPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 16
    static let contentSpacing: CGFloat = 12
    static let tightSpacing: CGFloat = 6
    static let hairlineWidth: CGFloat = 1
    static let iconColumn: CGFloat = 28
    static let tileMinWidth: CGFloat = 150
}

extension View {
    func cardSurface(
        padding: CGFloat = AppMetrics.cardPadding,
        radius: CGFloat = AppMetrics.cardRadius
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.bgElevated, in: shape)
            .overlay {
                shape.stroke(AppTheme.hairline, lineWidth: AppMetrics.hairlineWidth)
            }
    }

    func pillSurface() -> some View {
        self
            .padding(.horizontal, AppMetrics.contentSpacing)
            .padding(.vertical, 8)
            .background(AppTheme.bgElevated, in: Capsule())
            .overlay {
                Capsule().stroke(AppTheme.hairline, lineWidth: AppMetrics.hairlineWidth)
            }
    }
}

#Preview {
    VStack(spacing: AppMetrics.sectionSpacing) {
        Text("Elevated block")
            .foregroundStyle(AppTheme.textPrimary)
            .cardSurface()
        Text("Compact tag")
            .font(.subheadline)
            .foregroundStyle(AppTheme.textPrimary)
            .pillSurface()
    }
    .padding(AppMetrics.screenPadding)
    .background(AppBackground())
}
