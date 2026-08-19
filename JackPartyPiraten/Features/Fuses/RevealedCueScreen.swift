import SwiftData
import SwiftUI

enum RevealedCueScreenViewState {
    case loaded
    case empty
}

struct RevealedCueScreen: View {
    private let revealCards: any RevealCardRepository
    private let store: AppStore
    private let payload: CoverRoutePayload

    @State private var viewState: RevealedCueScreenViewState = .loaded
    @State private var opened: OpenedReveal?
    @State private var didComplete = false
    @State private var completePulse = 0
    @State private var returnPulse = 0

    init(dependencies: AppDependencies, payload: CoverRoutePayload) {
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
        .navigationTitle("Prepared cue")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            refresh()
        }
        .sensoryFeedback(.success, trigger: completePulse)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: returnPulse)
    }

    @ViewBuilder
    private var loadedBody: some View {
        if let opened {
            ScreenScaffold {
                ScreenHeader(
                    title: opened.revealCue.instruction,
                    subtitle: "Authorized host instruction for this opened cover."
                )

                ResultCard(
                    title: "Cue",
                    value: "\(opened.revealCue.estimatedSeconds)s",
                    unit: "hold",
                    lines: [
                        ResultLine(label: "Opened", value: opened.openedAt.formatted(date: .abbreviated, time: .shortened)),
                        ResultLine(label: "Cover", value: opened.coverLine.text),
                        ResultLine(label: "Action", value: opened.revealCue.hostAction)
                    ],
                    note: opened.revealCue.safetyNote
                )

                SectionCard(title: "Host instruction") {
                    DetailRow(label: "Do", value: opened.revealCue.instruction, isProminent: true)
                    DetailRow(label: "Then", value: opened.revealCue.hostAction)
                    DetailRow(label: "Hold", value: "\(opened.revealCue.estimatedSeconds) seconds")
                }

                SectionCard(title: "Safety", footnote: opened.coverLine.safetyContext) {
                    DetailRow(label: "Note", value: opened.revealCue.safetyNote, isProminent: true)
                    DetailRow(label: "Cover", value: opened.coverLine.text)
                }

                if didComplete {
                    ResultCard(
                        title: "Archive",
                        value: "Filed",
                        lines: [
                            ResultLine(label: "Outcome", value: "Opened"),
                            ResultLine(label: "Cover", value: opened.coverLine.text)
                        ],
                        note: "The opened outcome is already in Archive. Return whenever you are done."
                    )
                }

                CTAButton(
                    title: didComplete ? "Mark complete again" : "Complete and file",
                    systemImage: "checkmark.circle.fill",
                    hint: "Keeps the opened outcome in Archive and leaves a return path"
                ) {
                    primaryAction()
                }

                CTAButton(
                    title: "Review safety note",
                    systemImage: "hand.raised",
                    emphasis: .secondary,
                    hint: "Keeps the safety note in view"
                ) {
                    secondaryAction()
                }

                CTAButton(
                    title: "Return to covers",
                    systemImage: "arrow.uturn.backward",
                    emphasis: .secondary,
                    hint: "Leaves the cue and returns to the previous screen"
                ) {
                    returnAction()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Prepared cue. \(opened.revealCue.instruction)")
        } else {
            emptyBody
        }
    }

    private var emptyBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Prepared cue",
                subtitle: "This cue stays sealed until a lock opens it."
            )
            EmptyStateCard(
                title: "Cue is not available",
                message: "Open the cover at its gate first. This screen only shows an authorized opened cue.",
                systemImage: "eye.slash",
                actionTitle: "Back to covers",
                action: returnAction
            )
        }
    }

    private var now: Date {
        store.rehearsalNow ?? Date()
    }

    private func refresh() {
        if let opened = revealCards.openedReveal(cardID: payload.cardID, at: now) {
            self.opened = opened
            viewState = .loaded
        } else {
            self.opened = nil
            viewState = .empty
        }
    }

    private func primaryAction() {
        guard let authorized = revealCards.openedReveal(cardID: payload.cardID, at: now) else {
            opened = nil
            viewState = .empty
            didComplete = false
            return
        }
        opened = authorized
        viewState = .loaded
        didComplete = true
        completePulse += 1
    }

    private func secondaryAction() {
        refresh()
    }

    private func returnAction() {
        returnPulse += 1
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
            RevealedCueScreen(
                dependencies: .preview(modelContext: container.mainContext),
                payload: CoverRoutePayload(
                    id: "preview-cue",
                    cardID: "card-012",
                    sourceTab: .fuses,
                    rehearsalSessionID: nil
                )
            )
        }
        .modelContainer(container)
    }
}
