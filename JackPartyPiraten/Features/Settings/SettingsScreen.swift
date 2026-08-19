import SwiftData
import SwiftUI

enum SettingsScreenViewState {
    case loaded
}

struct SettingsScreen: View {
    private let resetter: any LocalResetting
    private let store: AppStore

    @Environment(\.openURL) private var openURL

    @State private var viewState: SettingsScreenViewState = .loaded
    @State private var confirmDelete = false
    @State private var deletePulse = 0

    init(dependencies: AppDependencies) {
        resetter = dependencies.resetter
        store = dependencies.appStore
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewState {
                case .loaded:
                    loadedBody
                }
            }
        }
        .sensoryFeedback(.warning, trigger: deletePulse)
        .confirmationDialog(
            "Delete All Data?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete All Data", role: .destructive) {
                primaryAction()
            }
            Button("Keep Records", role: .cancel) {
                returnAction()
            }
        } message: {
            Text("This removes every local cover, archive event, and preference, then returns you to onboarding.")
        }
    }

    private var loadedBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Settings",
                subtitle: "About this device-local host tool, legal pages, and a full record reset."
            )

            SectionCard(title: "About") {
                DetailRow(label: "App", value: AppTheme.displayName, isProminent: true)
                DetailRow(label: "Version", value: bundleVersion)
                DetailRow(label: "Storage", value: "On this device")
                DetailRow(label: "Orientation", value: store.onboardingComplete ? "Finished" : "In progress")
            }

            VStack(spacing: AppMetrics.contentSpacing) {
                NavigationRow(
                    title: "Privacy",
                    subtitle: "How this app treats information stored on this device",
                    systemImage: "doc.text",
                    hint: "Opens the privacy policy"
                ) {
                    secondaryAction()
                }

                NavigationRow(
                    title: "Terms",
                    subtitle: "The terms that apply to this local host tool",
                    systemImage: "doc.plaintext",
                    hint: "Opens the terms of use"
                ) {
                    openTerms()
                }
            }

            SectionCard(
                title: "Local records",
                footnote: "Deletion clears covers, locks, archive events, and the onboarding flag on this device."
            ) {
                CTAButton(
                    title: "Delete All Data",
                    systemImage: "trash",
                    emphasis: .secondary,
                    hint: "Asks for confirmation, then resets every local record and onboarding"
                ) {
                    confirmDelete = true
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bundleVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let trimmed = (version ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "1.0" : trimmed
    }

    private func primaryAction() {
        resetter.deleteAllRecords(at: Date())
        store.resetAfterDeletion()
        deletePulse += 1
    }

    private func secondaryAction() {
        if let url = Legal.privacy {
            openURL(url)
        }
    }

    private func returnAction() {
        confirmDelete = false
    }

    private func openTerms() {
        if let url = Legal.terms {
            openURL(url)
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(
        for: AppPreference.self,
        RevealCard.self,
        LockCondition.self,
        UnlockEvent.self,
        configurations: configuration
    ) {
        SettingsScreen(dependencies: .preview(modelContext: container.mainContext))
            .modelContainer(container)
    }
}
