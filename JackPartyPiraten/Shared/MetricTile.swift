import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    var caption: String?
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.tightSpacing) {
            HStack(spacing: AppMetrics.tightSpacing) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMono)
                    .lineLimit(2)
            }
        }
        .cardSurface()
    }
}

struct TileGrid<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: AppMetrics.tileMinWidth), spacing: AppMetrics.contentSpacing)],
            spacing: AppMetrics.contentSpacing
        ) {
            content
        }
    }
}

#Preview {
    ScreenScaffold {
        TileGrid {
            MetricTile(title: "Batches", value: "12", caption: "This month", systemImage: "tray.full")
            MetricTile(title: "Average yield", value: "1.4 L", caption: "Per batch")
            MetricTile(title: "Longest steep", value: "18 h")
        }
    }
}
