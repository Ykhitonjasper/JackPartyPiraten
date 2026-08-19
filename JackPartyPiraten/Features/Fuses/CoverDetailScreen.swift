import SwiftData
import SwiftUI

enum CoverDetailScreenViewState {
    case loaded
    case empty
}

struct CoverDetailScreen: View {
    private let dependencies: AppDependencies
    private let revealCards: any RevealCardRepository
    private let store: AppStore
    private let payload: CoverRoutePayload

    @State private var viewState: CoverDetailScreenViewState = .loaded
    @State private var card: CoverCard?
    @State private var glancePayload: CoverRoutePayload?
    @State private var navigatePulse = 0
    @State private var previewPulse = 0

    init(dependencies: AppDependencies, payload: CoverRoutePayload) {
        self.dependencies = dependencies
        revealCards = dependencies.revealCards
        store = dependencies.appStore
        self.payload = payload
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
        .navigationTitle("Cover")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $glancePayload) { destination in
            GlancePreviewScreen(dependencies: dependencies, payload: destination)
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
        .sensoryFeedback(.impact(flexibility: .soft), trigger: navigatePulse)
        .sensoryFeedback(.selection, trigger: previewPulse)
    }

    @ViewBuilder
    private var loadedBody: some View {
        if let card {
            ScreenScaffold {
                ScreenHeader(
                    title: card.coverLine.text,
                    subtitle: "Cover-safe status, lock summary, and the burn window. The hidden instruction stays off this screen."
                )

                ChipRow {
                    TagChip(title: phaseTitle(card.phase), systemImage: phaseIcon(card.phase))
                    TagChip(title: card.lockSummary, systemImage: lockIcon(card.lockKind))
                }

                ResultCard(
                    title: "Cover status",
                    value: phaseTitle(card.phase),
                    lines: [
                        ResultLine(label: "Lock", value: card.lockSummary),
                        ResultLine(label: "Prepared", value: card.coverLine.createdAt.formatted(date: .abbreviated, time: .shortened)),
                        ResultLine(label: "Window", value: card.burnAt.formatted(date: .abbreviated, time: .shortened))
                    ],
                    note: card.coverLine.safetyContext
                )

                SectionCard(title: "Cover face", footnote: "Shoulder-safe line only.") {
                    DetailRow(label: "Line", value: card.coverLine.text, isProminent: true)
                    DetailRow(label: "Context", value: card.coverLine.safetyContext)
                    DetailRow(label: "Lock", value: card.lockSummary)
                    DetailRow(label: "Phase", value: phaseTitle(card.phase))
                }

                SectionCard(title: "Status timeline") {
                    DetailRow(
                        label: "Prepared",
                        value: card.coverLine.createdAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    DetailRow(label: "Lock armed", value: card.lockSummary)
                    DetailRow(label: "Current", value: phaseTitle(card.phase), isProminent: true)
                    DetailRow(
                        label: card.phase == .burned ? "Closed" : "Closes",
                        value: card.burnAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                CTAButton(
                    title: gateTitle(for: card.phase),
                    systemImage: card.phase == .burned ? "flame" : "lock.open",
                    hint: gateHint(for: card)
                ) {
                    primaryAction(card)
                }

                CTAButton(
                    title: "Shoulder-safe glance",
                    systemImage: "theatermasks",
                    emphasis: .secondary,
                    hint: "Opens a cover-only preview"
                ) {
                    secondaryAction(card)
                }
            }
        } else {
            emptyBody
        }
    }

    private var emptyBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Cover",
                subtitle: "This card is no longer on the device."
            )
            EmptyStateCard(
                title: "Cover not found",
                message: "Return to the active list and pick another local cover.",
                systemImage: "rectangle.badge.xmark",
                actionTitle: "Back to covers",
                action: returnAction
            )
        }
    }

    private var now: Date {
        store.rehearsalNow ?? Date()
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

    private func lockIcon(_ kind: LockKind) -> String {
        switch kind {
        case .exactTime: return "clock"
        case .calendarDate: return "calendar"
        case .localCode: return "number"
        case .hostConfirmedArrival: return "figure.walk"
        }
    }

    private func gateTitle(for phase: RevealPhase) -> String {
        switch phase {
        case .burned: return "Review the closed window"
        case .unlockable: return "Open the gate"
        case .sealed: return "Review the gate"
        case .opened: return "Open the gate"
        }
    }

    private func gateHint(for card: CoverCard) -> String {
        if card.phase == .burned {
            return "Opens the closed-window gate for \(card.coverLine.text)"
        }
        return "Opens the unlock gate for \(card.coverLine.text)"
    }

    private func refresh() {
        card = revealCards.coverCard(
            id: payload.cardID,
            now: now,
            confirmations: confirmations(at: now)
        )
        viewState = card == nil ? .empty : .loaded
    }

    private func primaryAction(_ card: CoverCard) {
        let route = CoverRoutePayload(
            id: card.phase == .burned ? "burned-\(card.id)" : "gate-\(card.id)",
            cardID: card.id,
            sourceTab: payload.sourceTab,
            rehearsalSessionID: payload.rehearsalSessionID
        )
        navigatePulse += 1
        if card.phase == .burned {
            store.path.append(.burnedCue(route))
        } else {
            store.path.append(.unlockGate(route))
        }
    }

    private func secondaryAction(_ card: CoverCard) {
        previewPulse += 1
        glancePayload = CoverRoutePayload(
            id: "glance-\(card.id)",
            cardID: card.id,
            sourceTab: payload.sourceTab,
            rehearsalSessionID: payload.rehearsalSessionID
        )
    }

    private func returnAction() {
        popCoverStack()
    }

    private func popCoverStack() {
        store.path.removeAll { route in
            switch route {
            case .coverDetail(let item),
                 .unlockGate(let item),
                 .burnedCue(let item),
                 .revealedCue(let item),
                 .glancePreview(let item):
                return item.cardID == payload.cardID
            default:
                return false
            }
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
        NavigationStack {
            CoverDetailScreen(
                dependencies: .preview(modelContext: container.mainContext),
                payload: CoverRoutePayload(
                    id: "preview-detail",
                    cardID: "card-009",
                    sourceTab: .fuses,
                    rehearsalSessionID: nil
                )
            )
        }
        .modelContainer(container)
    }
}
