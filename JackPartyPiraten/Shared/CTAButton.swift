import SwiftUI

struct CTAButton: View {
    enum Emphasis {
        case primary
        case secondary
    }

    let title: String
    var systemImage: String?
    var emphasis: Emphasis = .primary
    var hint: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
    }

    private var label: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }

            Text(title)
        }
        .font(.headline)
        .foregroundStyle(emphasis == .primary ? AppTheme.bgBase : AppTheme.textPrimary)
        .padding(.vertical, 14)
        .padding(.horizontal, AppMetrics.cardPadding)
        .background(
            emphasis == .primary ? AppTheme.accent : AppTheme.bgElevated,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            if emphasis == .secondary {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: AppMetrics.hairlineWidth)
            }
        }
    }
}

#Preview {
    ScreenScaffold {
        CTAButton(title: "Save to project", systemImage: "tray.and.arrow.down") {}
        CTAButton(title: "Start over", emphasis: .secondary) {}
        CTAButton(title: "Export", isEnabled: false) {}
    }
}
