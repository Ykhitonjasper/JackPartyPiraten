import SwiftUI

struct ResultLine: Identifiable {
    let id: String
    let label: String
    let value: String

    init(label: String, value: String) {
        id = label
        self.label = label
        self.value = value
    }
}

struct ResultCard: View {
    let title: String
    let value: String
    var unit: String?
    var lines: [ResultLine] = []
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            HStack(alignment: .lastTextBaseline, spacing: AppMetrics.tightSpacing) {
                Text(value)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if let unit {
                    Text(unit)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            if !lines.isEmpty {
                Divider()
                    .overlay(AppTheme.hairline)

                VStack(spacing: 8) {
                    ForEach(lines) { line in
                        DetailRow(label: line.label, value: line.value)
                    }
                }
            }

            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMono)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
    }
}

#Preview {
    ScreenScaffold {
        ResultCard(
            title: "Water needed",
            value: "1.4",
            unit: "L",
            lines: [
                ResultLine(label: "Grounds", value: "180 g"),
                ResultLine(label: "Ratio", value: "1:8")
            ],
            note: "Assumes coarse grind and a 14 hour steep."
        )
    }
}
