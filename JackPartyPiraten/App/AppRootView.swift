import SwiftData
import SwiftUI

struct AppRootView: View {
    private let dependencies: AppDependencies
    private let store: AppStore

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var glancePayload: CoverRoutePayload?
    @State private var recipePayload: RecipeRoutePayload?
    @State private var recapPayload: RecapRoutePayload?
    @State private var tabPulse = 0

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.appStore
    }

    var body: some View {
        Group {
            if store.onboardingComplete {
                signedInRoot
            } else {
                OnboardingScreen(dependencies: dependencies)
            }
        }
        .onChange(of: store.path) { _, newPath in
            presentSheets(from: newPath)
        }
        .onChange(of: store.onboardingComplete) { _, isComplete in
            hasCompletedOnboarding = isComplete
        }
        .task {
            hasCompletedOnboarding = store.onboardingComplete
        }
        .sensoryFeedback(.selection, trigger: tabPulse)
    }

    private var signedInRoot: some View {
        NavigationStack(path: pathBinding) {
            tabChrome
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self) { route in
                    destination(route)
                }
        }
        .sheet(item: $glancePayload) { payload in
            GlancePreviewScreen(dependencies: dependencies, payload: payload)
        }
        .sheet(item: $recipePayload) { payload in
            SituationRecipesScreen(dependencies: dependencies, payload: payload)
        }
        .sheet(item: $recapPayload) { payload in
            ArchiveEventDetailScreen(dependencies: dependencies, recapPayload: payload)
        }
    }

    private var tabChrome: some View {
        TabView(selection: tabBinding) {
            ActiveCoversScreen(dependencies: dependencies)
                .tabItem {
                    Label("Fuses", systemImage: "timer")
                }
                .tag(FuseTab.fuses)

            CreateCoverScreen(dependencies: dependencies)
                .tabItem {
                    Label("Create", systemImage: "plus.square")
                }
                .tag(FuseTab.create)

            ArchiveLogScreen(dependencies: dependencies)
                .tabItem {
                    Label("Archive", systemImage: "archivebox")
                }
                .tag(FuseTab.archive)

            SettingsScreen(dependencies: dependencies)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(FuseTab.settings)
        }
        .tint(AppTheme.accent)
    }

    private var pathBinding: Binding<[AppRoute]> {
        Binding(
            get: { store.path },
            set: { store.path = $0 }
        )
    }

    private var tabBinding: Binding<FuseTab> {
        Binding(
            get: { store.selectedTab },
            set: { next in
                store.selectedTab = next
                tabPulse += 1
            }
        )
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .coverDetail(let payload):
            CoverDetailScreen(dependencies: dependencies, payload: payload)
        case .glancePreview(let payload):
            GlancePreviewScreen(dependencies: dependencies, payload: payload)
        case .situationRecipes(let payload):
            SituationRecipesScreen(dependencies: dependencies, payload: payload)
        case .unlockGate(let payload), .burnedCue(let payload):
            UnlockGateScreen(dependencies: dependencies, payload: payload)
        case .revealedCue(let payload):
            RevealedCueScreen(dependencies: dependencies, payload: payload)
        case .archiveDetail(let payload):
            ArchiveEventDetailScreen(dependencies: dependencies, payload: payload)
        case .rehearsalBoard(let payload):
            RehearsalBoardScreen(dependencies: dependencies, payload: payload)
        case .eventRecap(let payload):
            ArchiveEventDetailScreen(dependencies: dependencies, recapPayload: payload)
        }
    }

    private func presentSheets(from path: [AppRoute]) {
        guard let last = path.last else { return }
        switch last {
        case .glancePreview(let payload):
            glancePayload = payload
            store.path.removeLast()
        case .situationRecipes(let payload):
            recipePayload = payload
            store.path.removeLast()
        case .eventRecap(let payload):
            recapPayload = payload
            store.path.removeLast()
        default:
            break
        }
    }
}

#Preview {
    previewRoot()
}

@MainActor
@ViewBuilder
private func previewRoot() -> some View {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(
        for: AppPreference.self,
        RevealCard.self,
        LockCondition.self,
        UnlockEvent.self,
        configurations: configuration
    ) {
        let dependencies = AppDependencies.preview(modelContext: container.mainContext)
        let _ = { dependencies.appStore.onboardingComplete = true }()
        AppRootView(dependencies: dependencies)
            .modelContainer(container)
    }
}
