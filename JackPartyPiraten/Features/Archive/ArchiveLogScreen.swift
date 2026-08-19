import SwiftData
import SwiftUI

enum ArchiveLogScreenViewState {
    case loaded
    case empty
}

struct ArchiveLogScreen: View {
    private let archive: any ArchiveRepository
    private let store: AppStore

    @State private var viewState: ArchiveLogScreenViewState = .loaded
    @State private var events: [UnlockEvent] = []
    @State private var family: OutcomeFamily?
    @State private var filterPulse = 0
    @State private var navigatePulse = 0

    init(dependencies: AppDependencies) {
        archive = dependencies.archive
        store = dependencies.appStore
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewState {
                case .loaded:
                    loadedBody
                case .empty:
                    emptyBody
                }
            }
        }
        .task {
            refresh()
        }
        .onChange(of: store.path.count) { _, _ in
            refresh()
        }
        .sensoryFeedback(.selection, trigger: filterPulse)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: navigatePulse)
    }

    private var loadedBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Archive",
                subtitle: "Opened, burned, and rehearsal outcomes stay on this device. Sealed cue text never appears here."
            )

            TileGrid {
                MetricTile(
                    title: "Opened",
                    value: "\(openedCount)",
                    caption: "Host and practice",
                    systemImage: "envelope.open.fill"
                )
                MetricTile(
                    title: "Burned",
                    value: "\(burnedCount)",
                    caption: "Window closed",
                    systemImage: "flame.fill"
                )
                MetricTile(
                    title: "Rehearsal",
                    value: "\(rehearsalCount)",
                    caption: "Practice only",
                    systemImage: "theatermasks"
                )
            }

            ChipRow {
                FilterChip(title: "All", isSelected: family == nil) {
                    secondaryAction(nil)
                }
                FilterChip(title: "Opened", isSelected: family == .opened) {
                    secondaryAction(.opened)
                }
                FilterChip(title: "Burned", isSelected: family == .burned) {
                    secondaryAction(.burned)
                }
                FilterChip(title: "Rehearsal", isSelected: family == .rehearsal) {
                    secondaryAction(.rehearsal)
                }
            }

            SectionCard(title: "Recorded outcomes", footnote: "Each row opens the immutable event. Cue text stays excluded.") {
                ForEach(visibleEvents, id: \.id) { event in
                    NavigationRow(
                        title: coverLabel(event.cardID),
                        subtitle: event.note,
                        systemImage: iconName(for: event.outcome),
                        trailingText: outcomeLabel(event.outcome),
                        hint: "Opens the archived outcome without sealed cue text."
                    ) {
                        primaryAction(event)
                    }
                }
            }

            CTAButton(
                title: "Build recap",
                systemImage: "doc.text",
                hint: "Builds an on-device recap from the visible archive rows."
            ) {
                launchRecap()
            }

            CTAButton(
                title: "Open practice board",
                systemImage: "theatermasks",
                emphasis: .secondary,
                hint: "Opens the three fixed rehearsal scenarios."
            ) {
                openRehearsalBoard()
            }
        }
    }

    private var emptyBody: some View {
        ScreenScaffold(scrolls: false) {
            ScreenHeader(
                title: "Archive",
                subtitle: "Opened, burned, and rehearsal outcomes appear after a cover is resolved."
            )

            EmptyStateCard(
                title: emptyTitle,
                message: emptyMessage,
                systemImage: "archivebox",
                actionTitle: emptyActionTitle,
                action: emptyAction
            )
        }
    }

    private var visibleEvents: [UnlockEvent] {
        events.filter { event in
            switch family {
            case .none:
                return true
            case .opened:
                return event.outcome == .opened || event.outcome == .rehearsalOpened
            case .burned:
                return event.outcome == .burned || event.outcome == .rehearsalBurned
            case .rehearsal:
                return event.wasRehearsal
            }
        }
    }

    private var openedCount: Int {
        events.filter { $0.outcome == .opened || $0.outcome == .rehearsalOpened }.count
    }

    private var burnedCount: Int {
        events.filter { $0.outcome == .burned || $0.outcome == .rehearsalBurned }.count
    }

    private var rehearsalCount: Int {
        events.filter(\.wasRehearsal).count
    }

    private var emptyTitle: String {
        events.isEmpty ? "No archive rows yet" : "No matching outcomes"
    }

    private var emptyMessage: String {
        if events.isEmpty {
            return "Resolve a cover from Fuses or run a practice walkthrough to record the first outcome."
        }
        return "Nothing in this filter. Show every opened, burned, and rehearsal row."
    }

    private var emptyActionTitle: String {
        events.isEmpty ? "Go to Fuses" : "Show all outcomes"
    }

    private func refresh() {
        events = archive.archiveEvents()
        viewState = visibleEvents.isEmpty ? .empty : .loaded
    }

    private func primaryAction(_ event: UnlockEvent) {
        let payload = ArchiveRoutePayload(
            id: "archive-\(event.id)",
            eventID: event.id,
            cardID: event.cardID,
            sourceTab: .archive
        )
        navigatePulse += 1
        store.path.append(.archiveDetail(payload))
    }

    private func secondaryAction(_ next: OutcomeFamily?) {
        family = next
        filterPulse += 1
        viewState = visibleEvents.isEmpty ? .empty : .loaded
    }

    private func returnAction() {
        family = nil
        filterPulse += 1
        viewState = events.isEmpty ? .empty : .loaded
    }

    private func emptyAction() {
        if events.isEmpty {
            store.selectedTab = .fuses
        } else {
            returnAction()
        }
    }

    private func launchRecap() {
        let ids = visibleEvents.map(\.id)
        guard !ids.isEmpty else { return }
        let payload = RecapRoutePayload(
            id: "recap-\(ids.joined(separator: "-"))",
            eventIDs: ids,
            sourceTab: .archive,
            generatedAt: Date()
        )
        navigatePulse += 1
        store.path.append(.eventRecap(payload))
    }

    private func openRehearsalBoard() {
        navigatePulse += 1
        store.path.append(
            .rehearsalBoard(
                RehearsalRoutePayload(
                    id: "archive-rehearsal-board",
                    sessionID: "",
                    cardID: "",
                    referenceNow: Date()
                )
            )
        )
    }

    private func coverLabel(_ cardID: String) -> String {
        let suffix = cardID.split(separator: "-").last.map(String.init) ?? cardID
        return "Cover \(suffix)"
    }

    private func outcomeLabel(_ outcome: ArchiveOutcome) -> String {
        switch outcome {
        case .opened: return "Opened"
        case .burned: return "Burned"
        case .rehearsalOpened: return "Practice opened"
        case .rehearsalBurned: return "Practice burned"
        }
    }

    private func iconName(for outcome: ArchiveOutcome) -> String {
        switch outcome {
        case .opened, .rehearsalOpened: return "envelope.open.fill"
        case .burned, .rehearsalBurned: return "flame.fill"
        }
    }

    private enum OutcomeFamily {
        case opened
        case burned
        case rehearsal
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
        ArchiveLogScreen(dependencies: .preview(modelContext: container.mainContext))
            .modelContainer(container)
    }
}
