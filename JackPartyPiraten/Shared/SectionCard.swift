import SwiftUI

struct SectionCard<Content: View>: View {
    private let title: String?
    private let footnote: String?
    private let content: Content

    init(title: String? = nil, footnote: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footnote = footnote
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            content

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
    }
}

struct SectionLabel: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppMetrics.tightSpacing) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer(minLength: 0)

            if let detail {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textMono)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScreenScaffold {
        SectionLabel(title: "Today", detail: "4 items")
        SectionCard(title: "Mix ratio", footnote: "Rounded to the nearest gram.") {
            Text("240 g water · 15 g grounds")
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}
