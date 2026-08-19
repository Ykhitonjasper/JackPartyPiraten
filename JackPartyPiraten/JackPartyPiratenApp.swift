import SwiftData
import SwiftUI

@main
struct JackPartyPiratenApp: App {
    private let container: ModelContainer?

    init() {
        let schema = Schema([
            AppPreference.self,
            RevealCard.self,
            LockCondition.self,
            UnlockEvent.self
        ])
        let persistent = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: persistent) {
            self.container = container
            return
        }
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try? ModelContainer(for: schema, configurations: memory)
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                AppRootView(dependencies: .live(modelContext: container.mainContext))
                    .modelContainer(container)
            } else {
                ScreenScaffold {
                    EmptyStateCard(
                        title: "Local library unavailable",
                        message: "This device could not open the on-device cover library.",
                        systemImage: "externaldrive"
                    )
                }
            }
        }
    }
}
