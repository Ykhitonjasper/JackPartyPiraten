import SwiftData
import SwiftUI

enum UnlockGateScreenViewState {
    case loaded
    case empty
}

struct UnlockGateScreen: View {
    private let dependencies: AppDependencies
    private let revealCards: any RevealCardRepository
    private let store: AppStore
    private let payload: CoverRoutePayload

    @State private var viewState: UnlockGateScreenViewState = .loaded
    @State private var card: CoverCard?
    @State private var openedReveal: OpenedReveal?
    @State private var burnedReveal: BurnedReveal?
    @State private var gateNote: String?
    @State private var localCode = ""
    @State private var recordedConfirmations: Set<UnlockConfirmation> = []
    @State private var revealedPayload: CoverRoutePayload?
    @State private var attemptPulse = 0
    @State private var openedPulse = 0
    @State private var burnedPulse = 0
    @State private var navigatePulse = 0

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
        .navigationTitle("Unlock gate")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $revealedPayload) { destination in
            RevealedCueScreen(dependencies: dependencies, payload: destination)
        }
        .task {
            refresh()
        }
        .onChange(of: store.rehearsalNow) { _, _ in
            refresh()
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: attemptPulse)
        .sensoryFeedback(.success, trigger: openedPulse)
        .sensoryFeedback(.warning, trigger: burnedPulse)
        .sensoryFeedback(.selection, trigger: navigatePulse)
    }

    @ViewBuilder
    private var loadedBody: some View {
        if let burnedReveal {
            burnedBody(burnedReveal)
        } else if let openedReveal {
            openedBody(openedReveal)
        } else if let card {
            sealedBody(card)
        } else {
            emptyBody
        }
    }

    private var emptyBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Unlock gate",
                subtitle: "This cover is not available on the device."
            )
            EmptyStateCard(
                title: "Cover not found",
                message: "Return to the active list and pick another local cover.",
                systemImage: "lock.slash",
                actionTitle: "Back to covers",
                action: returnAction
            )
        }
    }

    private func sealedBody(_ card: CoverCard) -> some View {
        ScreenScaffold {
            ScreenHeader(
                title: card.coverLine.text,
                subtitle: "Clear the local lock. The prepared cue stays off this screen until the transition opens it."
            )

            ChipRow {
                TagChip(title: phaseTitle(card.phase), systemImage: phaseIcon(card.phase))
                TagChip(title: card.lockSummary, systemImage: lockIcon(card.lockKind))
            }

            ResultCard(
                title: "Gate",
                value: phaseTitle(card.phase),
                lines: [
                    ResultLine(label: "Lock", value: card.lockSummary),
                    ResultLine(label: "Cover", value: card.coverLine.text),
                    ResultLine(label: "Closes", value: card.burnAt.formatted(date: .abbreviated, time: .shortened))
                ],
                note: card.coverLine.safetyContext
            )

            SectionCard(title: "Cover face", footnote: "Shoulder-safe line only.") {
                DetailRow(label: "Line", value: card.coverLine.text, isProminent: true)
                DetailRow(label: "Context", value: card.coverLine.safetyContext)
                DetailRow(label: "Lock", value: lockTitle(card.lockKind))
            }

            gateControls(for: card)

            if let gateNote {
                SectionCard(footnote: gateNote) {
                    DetailRow(label: "Result", value: "Still sealed", isProminent: true)
                }
            }

            CTAButton(
                title: "Review lock",
                systemImage: "arrow.clockwise",
                emphasis: .secondary,
                hint: "Refresh the cover-safe gate without opening a cue"
            ) {
                secondaryAction()
            }
        }
    }

    private func openedBody(_ opened: OpenedReveal) -> some View {
        ScreenScaffold {
            ScreenHeader(
                title: opened.coverLine.text,
                subtitle: "The cover opened. Continue to the cue screen to read the prepared instruction."
            )

            ResultCard(
                title: "Opened",
                value: "Ready",
                lines: [
                    ResultLine(label: "Opened", value: opened.openedAt.formatted(date: .abbreviated, time: .omitted)),
                    ResultLine(label: "Cover", value: opened.coverLine.text),
                    ResultLine(label: "Context", value: opened.coverLine.safetyContext)
                ],
                note: "The cue itself is held on the next screen."
            )

            CTAButton(
                title: "Open prepared cue",
                systemImage: "text.badge.checkmark",
                hint: "Shows the authorized host instruction"
            ) {
                openRevealedCue()
            }

            CTAButton(
                title: "Back to covers",
                emphasis: .secondary,
                hint: "Returns to the previous cover list"
            ) {
                returnAction()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cover opened. Continue to the prepared cue.")
    }

    private func burnedBody(_ burned: BurnedReveal) -> some View {
        ScreenScaffold {
            ScreenHeader(
                title: burned.coverLine.text,
                subtitle: "The window closed. The prepared cue is not shown."
            )

            ResultCard(
                title: "Burned",
                value: "Closed",
                lines: [
                    ResultLine(label: "Closed", value: burned.burnedAt.formatted(date: .abbreviated, time: .shortened)),
                    ResultLine(label: "Cover", value: burned.coverLine.text),
                    ResultLine(label: "Reason", value: burned.reason)
                ],
                note: burned.coverLine.safetyContext
            )

            SectionCard(title: "Archived outcome", footnote: "Archive keeps this reason without the cue.") {
                DetailRow(label: "Cover", value: burned.coverLine.text, isProminent: true)
                DetailRow(label: "Reason", value: burned.reason)
            }

            CTAButton(
                title: "Back to covers",
                systemImage: "arrow.uturn.backward",
                hint: "Returns to the previous cover list"
            ) {
                returnAction()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cover burned. \(burned.reason)")
    }

    @ViewBuilder
    private func gateControls(for card: CoverCard) -> some View {
        switch card.lockKind {
        case .exactTime:
            SectionCard(title: "Exact time", footnote: "Uses the local clock against the stored threshold.") {
                DetailRow(
                    label: "Now",
                    value: now.formatted(date: .abbreviated, time: .shortened),
                    isProminent: true
                )
                CTAButton(
                    title: "Check exact time",
                    systemImage: "clock",
                    hint: "Asks the lock if the exact time has arrived"
                ) {
                    primaryAction(.exactTime)
                }
            }
        case .calendarDate:
            SectionCard(title: "Calendar date", footnote: "Uses the local calendar date, not the clock minute.") {
                DetailRow(
                    label: "Today",
                    value: now.formatted(date: .abbreviated, time: .omitted),
                    isProminent: true
                )
                CTAButton(
                    title: "Check calendar date",
                    systemImage: "calendar",
                    hint: "Asks the lock if the calendar date has arrived"
                ) {
                    primaryAction(.calendarDate)
                }
            }
        case .localCode:
            SectionCard(title: "Local code", footnote: "Ordinary local content used only on this device.") {
                TextField("Local code", text: $localCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Local code")
                    .accessibilityHint("Ordinary local content used to open this cover")
                CTAButton(
                    title: "Check local code",
                    systemImage: "number",
                    hint: "Submits the entered local code to the lock",
                    isEnabled: !localCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    let trimmed = localCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    recordConfirmation(
                        UnlockConfirmation(
                            id: "confirm-code-\(payload.cardID)",
                            cardID: payload.cardID,
                            kind: .localCode,
                            suppliedCode: trimmed,
                            confirmedAt: now
                        )
                    )
                    primaryAction(.localCode(trimmed))
                }
            }
        case .hostConfirmedArrival:
            SectionCard(title: "Host arrival", footnote: "Only the host tap records arrival on this device.") {
                DetailRow(label: "Arrival", value: "Waiting for the host tap")
                CTAButton(
                    title: "Confirm host arrival",
                    systemImage: "figure.walk",
                    hint: "Records that the host arrived and asks the lock to open"
                ) {
                    recordConfirmation(
                        UnlockConfirmation(
                            id: "confirm-arrival-\(payload.cardID)",
                            cardID: payload.cardID,
                            kind: .hostConfirmedArrival,
                            suppliedCode: nil,
                            confirmedAt: now
                        )
                    )
                    store.confirmHostArrival(for: payload.cardID)
                    primaryAction(.hostArrivalConfirmed)
                }
            }
        }
    }

    private var now: Date {
        store.rehearsalNow ?? Date()
    }

    private var isRehearsal: Bool {
        payload.rehearsalSessionID != nil
    }

    private func recordConfirmation(_ confirmation: UnlockConfirmation) {
        recordedConfirmations.insert(confirmation)
    }

    private func refresh() {
        let current = now
        guard let card = revealCards.coverCard(
            id: payload.cardID,
            now: current,
            confirmations: recordedConfirmations
        ) else {
            viewState = .empty
            openedReveal = nil
            burnedReveal = nil
            self.card = nil
            return
        }

        self.card = card
        viewState = .loaded
        gateNote = nil

        switch card.phase {
        case .opened:
            if let opened = revealCards.openedReveal(cardID: card.id, at: current) {
                openedReveal = opened
                burnedReveal = nil
            } else {
                openedReveal = nil
                burnedReveal = nil
                viewState = .empty
            }
        case .burned:
            openedReveal = nil
            burnedReveal = BurnedReveal(
                id: card.id,
                coverLine: card.coverLine,
                burnedAt: card.burnAt,
                reason: "The reveal window closed before opening.",
                recipeID: card.recipeID
            )
        case .sealed, .unlockable:
            openedReveal = nil
            burnedReveal = nil
        }
    }

    private func primaryAction(_ attempt: UnlockAttempt) {
        attemptPulse += 1
        apply(revealCards.transition(
            cardID: payload.cardID,
            attempt: attempt,
            now: now,
            isRehearsal: isRehearsal
        ))
    }

    private func secondaryAction() {
        refresh()
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
        revealedPayload = nil
    }

    private func archiveBurnedOutcome(_ burned: BurnedReveal) {
        burnedReveal = burned
        openedReveal = nil
        burnedPulse += 1
    }

    private func apply(_ transition: RevealTransition) {
        switch transition {
        case .sealed(let card):
            self.card = card
            openedReveal = nil
            burnedReveal = nil
            gateNote = "The lock is still closed. The cue stays hidden."
            viewState = .loaded
        case .opened(let opened):
            openedReveal = opened
            burnedReveal = nil
            gateNote = nil
            viewState = .loaded
            openedPulse += 1
        case .burned(let burned):
            archiveBurnedOutcome(burned)
            viewState = .loaded
        case .unavailable:
            viewState = .empty
            openedReveal = nil
            burnedReveal = nil
            card = nil
        }
    }

    private func openRevealedCue() {
        guard openedReveal != nil else { return }
        navigatePulse += 1
        revealedPayload = CoverRoutePayload(
            id: "revealed-\(payload.cardID)",
            cardID: payload.cardID,
            sourceTab: payload.sourceTab,
            rehearsalSessionID: payload.rehearsalSessionID
        )
    }

    private func lockTitle(_ kind: LockKind) -> String {
        switch kind {
        case .exactTime:
            "Exact time"
        case .calendarDate:
            "Calendar date"
        case .localCode:
            "Local code"
        case .hostConfirmedArrival:
            "Host arrival"
        }
    }

    private func phaseTitle(_ phase: RevealPhase) -> String {
        switch phase {
        case .sealed:
            "Sealed"
        case .unlockable:
            "Ready"
        case .opened:
            "Opened"
        case .burned:
            "Burned"
        }
    }

    private func phaseIcon(_ phase: RevealPhase) -> String {
        switch phase {
        case .sealed:
            "lock.fill"
        case .unlockable:
            "lock.open.fill"
        case .opened:
            "eye"
        case .burned:
            "flame"
        }
    }

    private func lockIcon(_ kind: LockKind) -> String {
        switch kind {
        case .exactTime:
            "clock"
        case .calendarDate:
            "calendar"
        case .localCode:
            "number"
        case .hostConfirmedArrival:
            "figure.walk"
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
            UnlockGateScreen(
                dependencies: .preview(modelContext: container.mainContext),
                payload: CoverRoutePayload(
                    id: "preview-gate",
                    cardID: "card-008",
                    sourceTab: .fuses,
                    rehearsalSessionID: nil
                )
            )
        }
        .modelContainer(container)
    }
}
