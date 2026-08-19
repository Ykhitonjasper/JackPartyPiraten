import SwiftData
import SwiftUI

enum GlancePreviewScreenViewState {
    case loaded
    case empty
}

struct GlancePreviewScreen: View {
    private let revealCards: any RevealCardRepository
    private let payload: CoverRoutePayload

    @Environment(\.dismiss) private var dismiss

    @State private var viewState: GlancePreviewScreenViewState = .loaded
    @State private var sealedCard: CoverCard?
    @State private var openedFace: OpenedReveal?
    @State private var showsOpenedFace = false
    @State private var revealPulse = 0
    @State private var coverPulse = 0

    init(dependencies: AppDependencies, payload: CoverRoutePayload) {
        revealCards = dependencies.revealCards
        self.payload = payload
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", action: returnAction)
                }
            }
        }
        .task {
            refresh()
        }
        .sensoryFeedback(.success, trigger: revealPulse)
        .sensoryFeedback(.selection, trigger: coverPulse)
    }

    @ViewBuilder
    private var loadedBody: some View {
        if let sealedCard {
            ScreenScaffold {
                ScreenHeader(
                    title: "Shoulder-safe glance",
                    subtitle: "The cover face is always safe to show. The opened face appears only after the opened-reveal API returns a record."
                )

                ChipRow {
                    FilterChip(title: "Cover face", isSelected: !showsOpenedFace) {
                        secondaryAction()
                    }
                    FilterChip(title: "Opened face", isSelected: showsOpenedFace) {
                        primaryAction()
                    }
                }

                if showsOpenedFace {
                    openedBody
                } else {
                    sealedBody(sealedCard)
                }
            }
        } else {
            emptyBody
        }
    }

    private var emptyBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Shoulder-safe glance",
                subtitle: "This preview needs a local cover."
            )
            EmptyStateCard(
                title: "Cover unavailable",
                message: "Close this preview and pick another cover from the active list.",
                systemImage: "theatermasks",
                actionTitle: "Close preview",
                action: returnAction
            )
        }
    }

    private func sealedBody(_ card: CoverCard) -> some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            ResultCard(
                title: "Cover face",
                value: phaseTitle(card.phase),
                lines: [
                    ResultLine(label: "Line", value: card.coverLine.text),
                    ResultLine(label: "Lock", value: card.lockSummary)
                ],
                note: card.coverLine.safetyContext
            )

            SectionCard(
                title: "Shoulder-safe line",
                footnote: "A person nearby can see this placement note and nothing else."
            ) {
                DetailRow(label: "Line", value: card.coverLine.text, isProminent: true)
                DetailRow(label: "Context", value: card.coverLine.safetyContext)
                DetailRow(label: "Lock", value: card.lockSummary)
                DetailRow(label: "Phase", value: phaseTitle(card.phase))
                DetailRow(
                    label: "Window",
                    value: card.burnAt.formatted(date: .abbreviated, time: .shortened)
                )
            }

            CTAButton(
                title: "Request opened face",
                systemImage: "eye",
                hint: "Asks the opened-reveal API for this cover"
            ) {
                primaryAction()
            }
        }
    }

    @ViewBuilder
    private var openedBody: some View {
        if let openedFace {
            VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
                ResultCard(
                    title: "Opened face",
                    value: "\(openedFace.revealCue.estimatedSeconds)",
                    unit: "sec",
                    lines: [
                        ResultLine(label: "Instruction", value: openedFace.revealCue.instruction),
                        ResultLine(label: "Host move", value: openedFace.revealCue.hostAction)
                    ],
                    note: openedFace.revealCue.safetyNote
                )

                SectionCard(
                    title: "Gated instruction",
                    footnote: "This face is available only because the opened-reveal API returned a record."
                ) {
                    DetailRow(label: "Line", value: openedFace.coverLine.text, isProminent: true)
                    DetailRow(label: "Instruction", value: openedFace.revealCue.instruction)
                    DetailRow(label: "Host move", value: openedFace.revealCue.hostAction)
                    DetailRow(label: "Safety", value: openedFace.revealCue.safetyNote)
                    DetailRow(
                        label: "Opened",
                        value: openedFace.openedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                CTAButton(
                    title: "Show cover face",
                    systemImage: "theatermasks",
                    emphasis: .secondary,
                    hint: "Returns to the shoulder-safe cover"
                ) {
                    secondaryAction()
                }
            }
        } else {
            EmptyStateCard(
                title: "Opened face is gated",
                message: "The opened-reveal API has no record for this cover yet. Keep the shoulder-safe line on screen.",
                systemImage: "eye.slash",
                actionTitle: "Show cover face",
                action: secondaryAction
            )
        }
    }

    private func phaseTitle(_ phase: RevealPhase) -> String {
        switch phase {
        case .sealed: return "Sealed"
        case .unlockable: return "Ready"
        case .opened: return "Opened"
        case .burned: return "Burned"
        }
    }

    private func refresh() {
        sealedCard = revealCards.coverCard(
            id: payload.cardID,
            now: Date(),
            confirmations: []
        )
        openedFace = nil
        showsOpenedFace = false
        viewState = sealedCard == nil ? .empty : .loaded
    }

    private func primaryAction() {
        openedFace = revealCards.openedReveal(cardID: payload.cardID, at: Date())
        showsOpenedFace = true
        if openedFace != nil {
            revealPulse += 1
        } else {
            coverPulse += 1
        }
    }

    private func secondaryAction() {
        showsOpenedFace = false
        coverPulse += 1
    }

    private func returnAction() {
        dismiss()
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
        GlancePreviewScreen(
            dependencies: .preview(modelContext: container.mainContext),
            payload: CoverRoutePayload(
                id: "preview-glance",
                cardID: "card-012",
                sourceTab: .fuses,
                rehearsalSessionID: nil
            )
        )
        .modelContainer(container)
    }
}
