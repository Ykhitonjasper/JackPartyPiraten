import SwiftUI

struct EmptyStateCard: View {
    let title: String
    let message: String
    var systemImage = "tray"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
            }
        }
        .foregroundStyle(AppTheme.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#Preview {
    ScreenScaffold {
        EmptyStateCard(
            title: "Nothing saved yet",
            message: "Run a tool and save the result to see it here.",
            systemImage: "square.stack",
            actionTitle: "Open tools"
        ) {}
    }
}
