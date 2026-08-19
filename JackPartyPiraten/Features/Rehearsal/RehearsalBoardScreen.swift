import SwiftData
import SwiftUI

enum RehearsalBoardScreenViewState {
    case loaded
    case empty
}

struct RehearsalBoardScreen: View {
    private let revealCards: any RevealCardRepository
    private let rehearsals: any RehearsalRepository
    private let clock: any RehearsalClockProviding
    private let fuseEngine: any FuseEvaluating
    private let store: AppStore
    private let payload: RehearsalRoutePayload

    @Environment(\.dismiss) private var dismiss

    @State private var viewState: RehearsalBoardScreenViewState = .loaded
    @State private var rows: [PracticeRow] = []
    @State private var selectedSessionID: String = ""
    @State private var runPulse = 0
    @State private var navigatePulse = 0

    init(dependencies: AppDependencies, payload: RehearsalRoutePayload) {
        revealCards = dependencies.revealCards
        rehearsals = dependencies.rehearsals
        clock = dependencies.rehearsalClock
        fuseEngine = dependencies.fuseEngine
        store = dependencies.appStore
        self.payload = payload
        _selectedSessionID = State(initialValue: payload.sessionID)
    }

    var body: some View {
        Group {
            switch viewState {
            case .loaded:
                loadedBody
            case .empty:
                emptyBody
            }
        }
        .task {
            refresh()
        }
        .onChange(of: store.hostArrivalConfirmations) { _, _ in
            refresh()
        }
        .onDisappear {
            store.rehearsalNow = nil
        }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: runPulse)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: navigatePulse)
    }

    private var loadedBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Practice board",
                subtitle: "Three fixed walkthroughs use the rehearsal clock and the shared fuse engine. Results stay marked as practice."
            )

            TileGrid {
                MetricTile(
                    title: "Scenarios",
                    value: "\(rows.count)",
                    caption: "Fixed set",
                    systemImage: "theatermasks"
                )
                MetricTile(
                    title: "Matches",
                    value: "\(rows.filter(\.matchesExpected).count)",
                    caption: "Clock vs expected",
                    systemImage: "checkmark.seal"
                )
                MetricTile(
                    title: "Practice",
                    value: "\(rows.filter { $0.resultNote != nil }.count)",
                    caption: "Runs this session",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }

            ForEach(rows, id: \.session.id) { row in
                scenarioCard(row)
            }

            CTAButton(
                title: "Back to covers",
                systemImage: "timer",
                emphasis: .secondary,
                hint: "Returns to the previous cover list."
            ) {
                returnAction()
            }
        }
    }

    private var emptyBody: some View {
        ScreenScaffold(scrolls: false) {
            ScreenHeader(
                title: "Practice board",
                subtitle: "The three fixed walkthroughs appear here when the rehearsal catalog is present."
            )

            EmptyStateCard(
                title: "No walkthroughs",
                message: "The rehearsal catalog is empty. Return to Fuses and open a live cover instead.",
                systemImage: "theatermasks",
                actionTitle: "Back to covers",
                action: returnAction
            )
        }
    }

    @ViewBuilder
    private func scenarioCard(_ row: PracticeRow) -> some View {
        let selected = selectedSessionID == row.session.id

        SectionCard(
            title: row.session.title,
            footnote: selected ? "Selected walkthrough" : "Fixed scenario"
        ) {
            ChipRow {
                TagChip(title: "Practice result", systemImage: "theatermasks")
                TagChip(
                    title: row.matchesExpected ? "Matches expected" : "Differs from expected",
                    systemImage: row.matchesExpected ? "checkmark.circle" : "circle.dashed"
                )
                if let card = row.card {
                    TagChip(title: card.lockKind.label, systemImage: "lock.fill")
                }
            }

            DetailRow(label: "Clock", value: row.now.formatted(date: .abbreviated, time: .shortened), isProminent: true)
            DetailRow(label: "Expected", value: phaseLabel(row.session.expectedPhase))
            DetailRow(label: "Engine", value: phaseLabel(row.phase))
            DetailRow(label: "Shoulder check", value: row.session.shoulderSafeCheck)

            if let card = row.card {
                DetailRow(label: "Cover", value: card.coverLine.text)
                DetailRow(label: "Lock summary", value: card.lockSummary)
            }

            if let resultNote = row.resultNote {
                Text(resultNote)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(resultNote)
            }

            CTAButton(
                title: "Run this walkthrough",
                systemImage: "play.fill",
                hint: "Runs the shared fuse engine at the rehearsal clock and marks the result as practice."
            ) {
                primaryAction(row.session)
            }

            CTAButton(
                title: "Open unlock gate",
                systemImage: "lock.open",
                emphasis: .secondary,
                hint: "Opens the contracted unlock flow for this practice cover."
            ) {
                openGate(row)
            }
        }
    }

    private func refresh() {
        let sessions = rehearsals.rehearsalSessions()
        rows = sessions.map { session in
            evaluate(session, previous: rows.first { $0.session.id == session.id })
        }
        if selectedSessionID.isEmpty {
            selectedSessionID = payload.sessionID.isEmpty ? (sessions.first?.id ?? "") : payload.sessionID
        }
        viewState = rows.isEmpty ? .empty : .loaded
    }

    private func evaluate(_ session: RehearsalSession, previous: PracticeRow?) -> PracticeRow {
        let now = clock.now(for: session)
        let confirmations = confirmations(for: session.cardID, at: now)
        let card = revealCards.coverCard(id: session.cardID, now: now, confirmations: confirmations)
        let phase: RevealPhase
        if let card {
            phase = enginePhase(card: card, session: session, now: now, confirmations: confirmations)
        } else {
            phase = session.expectedPhase
        }
        return PracticeRow(
            session: session,
            card: card,
            now: now,
            phase: phase,
            matchesExpected: phase == session.expectedPhase,
            resultNote: previous?.resultNote
        )
    }

    private func enginePhase(
        card: CoverCard,
        session: RehearsalSession,
        now: Date,
        confirmations: Set<UnlockConfirmation>
    ) -> RevealPhase {
        let persisted: RevealPhase
        switch card.phase {
        case .opened, .burned:
            persisted = card.phase
        case .sealed, .unlockable:
            persisted = .sealed
        }

        let snapshot = LockSnapshot(
            id: "practice-lock-\(card.id)",
            kind: card.lockKind,
            thresholdDate: session.referenceNow,
            expectedCode: nil,
            burnAt: card.burnAt
        )
        let input = FuseCardState(
            id: card.id,
            persistedPhase: persisted,
            lock: snapshot,
            recipeID: card.recipeID
        )
        return fuseEngine.state(card: input, now: now, confirmations: confirmations)
    }

    private func confirmations(for cardID: String, at now: Date) -> Set<UnlockConfirmation> {
        guard store.hostArrivalConfirmations.contains(cardID) else { return [] }
        return [
            UnlockConfirmation(
                id: "confirm-arrival-\(cardID)",
                cardID: cardID,
                kind: .hostConfirmedArrival,
                suppliedCode: nil,
                confirmedAt: now
            )
        ]
    }

    private func primaryAction(_ session: RehearsalSession) {
        secondaryAction(session)
        let now = clock.now(for: session)
        store.rehearsalNow = now

        guard let index = rows.firstIndex(where: { $0.session.id == session.id }) else { return }
        let card = rows[index].card
        if let card, card.lockKind == .hostConfirmedArrival {
            store.confirmHostArrival(for: card.id)
        }

        let attempt = unlockAttempt(for: card)
        let transition = revealCards.transition(
            cardID: session.cardID,
            attempt: attempt,
            now: now,
            isRehearsal: true
        )

        var next = evaluate(session, previous: rows[index])
        next.resultNote = practiceNote(transition)
        rows[index] = next
        runPulse += 1
        viewState = .loaded
    }

    private func secondaryAction(_ session: RehearsalSession) {
        selectedSessionID = session.id
        refresh()
    }

    private func returnAction() {
        store.rehearsalNow = nil
        dismiss()
    }

    private func openGate(_ row: PracticeRow) {
        store.rehearsalNow = row.now
        navigatePulse += 1
        store.path.append(
            .unlockGate(
                CoverRoutePayload(
                    id: "rehearsal-gate-\(row.session.id)",
                    cardID: row.session.cardID,
                    sourceTab: .fuses,
                    rehearsalSessionID: row.session.id
                )
            )
        )
    }

    private func unlockAttempt(for card: CoverCard?) -> UnlockAttempt {
        switch card?.lockKind {
        case .exactTime, .none:
            return .exactTime
        case .calendarDate:
            return .calendarDate
        case .localCode:
            return .localCode("")
        case .hostConfirmedArrival:
            return .hostArrivalConfirmed
        }
    }

    private func practiceNote(_ transition: RevealTransition) -> String {
        switch transition {
        case .sealed:
            return "Practice result: still sealed. Only the cover line is visible."
        case .opened:
            return "Practice result: opened. Cue text stays on the unlock gate, not on this board."
        case .burned:
            return "Practice result: burned. The reveal window closed during this walkthrough."
        case .unavailable:
            return "Practice result: this cover is not available for a walkthrough."
        }
    }

    private func phaseLabel(_ phase: RevealPhase) -> String {
        switch phase {
        case .sealed: return "Sealed"
        case .unlockable: return "Unlockable"
        case .opened: return "Opened"
        case .burned: return "Burned"
        }
    }

    private struct PracticeRow {
        let session: RehearsalSession
        let card: CoverCard?
        let now: Date
        var phase: RevealPhase
        var matchesExpected: Bool
        var resultNote: String?
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
        RehearsalBoardScreen(
            dependencies: .preview(modelContext: container.mainContext),
            payload: RehearsalRoutePayload(
                id: "rehearsal-001",
                sessionID: "rehearsal-001",
                cardID: "card-008",
                referenceNow: Date(timeIntervalSince1970: 1_787_075_100)
            )
        )
        .modelContainer(container)
    }
}
