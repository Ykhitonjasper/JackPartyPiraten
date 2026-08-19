import SwiftUI

struct DetailRow: View {
    let label: String
    let value: String
    var isProminent = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppMetrics.contentSpacing) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            Spacer(minLength: AppMetrics.tightSpacing)

            Text(value)
                .font(isProminent ? .headline : .subheadline.weight(.medium))
                .foregroundStyle(isProminent ? AppTheme.textPrimary : AppTheme.textMono)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NavigationRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var trailingText: String?
    var hint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppMetrics.contentSpacing) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: AppMetrics.iconColumn)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.leading)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    if let trailingText {
                        Text(trailingText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textMono)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .cardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(hint ?? "")
    }

    private var accessibilityText: String {
        [title, subtitle, trailingText]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

#Preview {
    ScreenScaffold {
        NavigationRow(
            title: "Cold brew batch",
            subtitle: "Steeped 14 hours, filtered twice.",
            systemImage: "drop",
            trailingText: "6 steps",
            hint: "Opens the batch detail"
        ) {}

        SectionCard(title: "Summary") {
            DetailRow(label: "Yield", value: "1.4 L", isProminent: true)
            DetailRow(label: "Grind", value: "Coarse")
        }
    }
}
