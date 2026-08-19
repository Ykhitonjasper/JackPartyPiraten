import SwiftData
import SwiftUI

enum ActiveCoversScreenViewState {
    case loaded
    case empty
}

struct ActiveCoversScreen: View {
    private let dependencies: AppDependencies
    private let revealCards: any RevealCardRepository
    private let rehearsals: any RehearsalRepository
    private let store: AppStore

    @State private var viewState: ActiveCoversScreenViewState = .loaded
    @State private var phaseFilter: RevealPhase?
    @State private var glancePayload: CoverRoutePayload?
    @State private var filterPulse = 0
    @State private var navigatePulse = 0

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        revealCards = dependencies.revealCards
        rehearsals = dependencies.rehearsals
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
        .sheet(item: $glancePayload) { payload in
            GlancePreviewScreen(dependencies: dependencies, payload: payload)
        }
        .task {
            refresh()
        }
        .onChange(of: store.rehearsalNow) { _, _ in
            refresh()
        }
        .onChange(of: store.hostArrivalConfirmations) { _, _ in
            refresh()
        }
        .onChange(of: store.path) { _, _ in
            refresh()
        }
        .sensoryFeedback(.selection, trigger: filterPulse)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: navigatePulse)
    }

    private var loadedBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Active covers",
                subtitle: "Group local covers by sealed, ready, opened, and burned. Only the cover line is visible here."
            )

            TileGrid {
                MetricTile(
                    title: "Sealed",
                    value: "\(count(.sealed))",
                    caption: "Cover only",
                    systemImage: "lock.fill"
                )
                MetricTile(
                    title: "Ready",
                    value: "\(count(.unlockable))",
                    caption: "Gate is available",
                    systemImage: "lock.open.fill"
                )
                MetricTile(
                    title: "Opened",
                    value: "\(count(.opened))",
                    caption: "Cue stays gated",
                    systemImage: "eye"
                )
                MetricTile(
                    title: "Burned",
                    value: "\(count(.burned))",
                    caption: "Window closed",
                    systemImage: "flame"
                )
            }

            ChipRow {
                FilterChip(title: "All", isSelected: phaseFilter == nil) {
                    secondaryAction(nil)
                }
                ForEach(RevealPhase.allCases, id: \.self) { phase in
                    FilterChip(title: phaseTitle(phase), isSelected: phaseFilter == phase) {
                        secondaryAction(phase)
                    }
                }
            }

            if visibleCards.isEmpty {
                EmptyStateCard(
                    title: "No covers in this group",
                    message: "Another phase still has covers on this device. Show every group to keep planning.",
                    systemImage: "line.3.horizontal.decrease.circle",
                    actionTitle: "Show every group",
                    action: returnAction
                )
            } else {
                if let ready = visibleCards.first(where: { $0.phase == .unlockable }) {
                    CTAButton(
                        title: "Open a ready cover",
                        systemImage: "lock.open",
                        hint: "Opens the unlock gate for \(ready.coverLine.text)"
                    ) {
                        openGate(ready)
                    }
                }

                if let opened = visibleCards.first(where: { $0.phase == .opened }) ?? visibleCards.first {
                    CTAButton(
                        title: "Shoulder-safe glance",
                        systemImage: "theatermasks",
                        emphasis: .secondary,
                        hint: "Opens a cover-only preview for \(opened.coverLine.text)"
                    ) {
                        openGlance(opened)
                    }
                }

                groupSection(title: "Sealed", phase: .sealed)
                groupSection(title: "Ready", phase: .unlockable)
                groupSection(title: "Opened", phase: .opened)
                groupSection(title: "Burned", phase: .burned)
            }

            rehearsalSection
        }
    }

    private var emptyBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Active covers",
                subtitle: "Local covers will group here by phase."
            )
            EmptyStateCard(
                title: "No covers yet",
                message: "Create a cover on this device to start grouping sealed, ready, opened, and burned cards.",
                systemImage: "timer",
                actionTitle: "Go to Create"
            ) {
                store.selectedTab = .create
            }
        }
    }

    @ViewBuilder
    private func groupSection(title: String, phase: RevealPhase) -> some View {
        let cards = visibleCards.filter { $0.phase == phase }
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
                SectionLabel(title: title, detail: "\(cards.count)")
                ForEach(cards) { card in
                    NavigationRow(
                        title: card.coverLine.text,
                        subtitle: "\(card.lockSummary) · \(phaseTitle(card.phase))",
                        systemImage: phaseIcon(card.phase),
                        trailingText: card.burnAt.formatted(date: .abbreviated, time: .omitted),
                        hint: "Opens the cover-safe detail"
                    ) {
                        primaryAction(card)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var rehearsalSection: some View {
        let sessions = rehearsals.rehearsalSessions()
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
                SectionLabel(title: "Rehearsals", detail: "\(sessions.count)")
                ForEach(sessions) { session in
                    NavigationRow(
                        title: session.title,
                        subtitle: session.shoulderSafeCheck,
                        systemImage: "list.clipboard",
                        trailingText: phaseTitle(session.expectedPhase),
                        hint: "Opens the rehearsal board"
                    ) {
                        openRehearsal(session)
                    }
                }
            }
        }
    }

    private var now: Date {
        store.rehearsalNow ?? Date()
    }

    private var allCards: [CoverCard] {
        revealCards.coverCards(now: now, confirmations: confirmations(at: now))
    }

    private var visibleCards: [CoverCard] {
        guard let phaseFilter else { return allCards }
        return allCards.filter { $0.phase == phaseFilter }
    }

    private func count(_ phase: RevealPhase) -> Int {
        allCards.filter { $0.phase == phase }.count
    }

    private func confirmations(at now: Date) -> Set<UnlockConfirmation> {
        Set(
            store.hostArrivalConfirmations.map { cardID in
                UnlockConfirmation(
                    id: "confirm-arrival-\(cardID)",
                    cardID: cardID,
                    kind: .hostConfirmedArrival,
                    suppliedCode: nil,
                    confirmedAt: now
                )
            }
        )
    }

    private func phaseTitle(_ phase: RevealPhase) -> String {
        switch phase {
        case .sealed: return "Sealed"
        case .unlockable: return "Ready"
        case .opened: return "Opened"
        case .burned: return "Burned"
        }
    }

    private func phaseIcon(_ phase: RevealPhase) -> String {
        switch phase {
        case .sealed: return "lock.fill"
        case .unlockable: return "lock.open.fill"
        case .opened: return "eye"
        case .burned: return "flame"
        }
    }

    private func refresh() {
        viewState = allCards.isEmpty ? .empty : .loaded
    }

    private func primaryAction(_ card: CoverCard) {
        let payload = CoverRoutePayload(
            id: "detail-\(card.id)",
            cardID: card.id,
            sourceTab: .fuses,
            rehearsalSessionID: nil
        )
        navigatePulse += 1
        store.path.append(.coverDetail(payload))
    }

    private func secondaryAction(_ phase: RevealPhase?) {
        phaseFilter = phase
        filterPulse += 1
    }

    private func returnAction() {
        phaseFilter = nil
        filterPulse += 1
    }

    private func openGate(_ card: CoverCard) {
        let payload = CoverRoutePayload(
            id: "gate-\(card.id)",
            cardID: card.id,
            sourceTab: .fuses,
            rehearsalSessionID: nil
        )
        navigatePulse += 1
        store.path.append(.unlockGate(payload))
    }

    private func openGlance(_ card: CoverCard) {
        navigatePulse += 1
        glancePayload = CoverRoutePayload(
            id: "glance-\(card.id)",
            cardID: card.id,
            sourceTab: .fuses,
            rehearsalSessionID: nil
        )
    }

    private func openRehearsal(_ session: RehearsalSession) {
        navigatePulse += 1
        store.path.append(
            .rehearsalBoard(
                RehearsalRoutePayload(
                    id: "rehearsal-\(session.id)",
                    sessionID: session.id,
                    cardID: session.cardID,
                    referenceNow: session.referenceNow
                )
            )
        )
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
        ActiveCoversScreen(dependencies: .preview(modelContext: container.mainContext))
            .modelContainer(container)
    }
}
