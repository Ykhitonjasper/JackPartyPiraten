import SwiftData
import SwiftUI

enum ArchiveEventDetailScreenViewState {
    case loaded
    case empty
}

struct ArchiveEventDetailScreen: View {
    private let archive: any ArchiveRepository
    private let store: AppStore
    private let eventID: String?
    private let recapRequest: RecapRoutePayload?

    @Environment(\.dismiss) private var dismiss

    @State private var viewState: ArchiveEventDetailScreenViewState = .loaded
    @State private var event: UnlockEvent?
    @State private var recap: EventRecap?
    @State private var related: [UnlockEvent] = []
    @State private var recapPulse = 0
    @State private var navigatePulse = 0

    init(dependencies: AppDependencies, payload: ArchiveRoutePayload) {
        archive = dependencies.archive
        store = dependencies.appStore
        eventID = payload.eventID
        recapRequest = nil
    }

    init(dependencies: AppDependencies, recapPayload: RecapRoutePayload) {
        archive = dependencies.archive
        store = dependencies.appStore
        eventID = recapPayload.eventIDs.first
        recapRequest = recapPayload
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
        .sensoryFeedback(.success, trigger: recapPulse)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: navigatePulse)
    }

    private var loadedBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: recapRequest == nil ? "Archive event" : "Reveal sequence recap",
                subtitle: recapRequest == nil
                    ? "This row is read-only. The lock path and timestamps stay local, and sealed cue text is excluded."
                    : "Totals stay on this device. Sealed cue text is excluded from the summary."
            )

            if let event {
                ResultCard(
                    title: coverLabel(event.cardID),
                    value: outcomeLabel(event.outcome),
                    unit: event.wasRehearsal ? "Practice" : "Host",
                    lines: [
                        ResultLine(label: "Recorded", value: event.occurredAt.formatted(date: .abbreviated, time: .shortened)),
                        ResultLine(label: "Lock path", value: lockPath(event)),
                        ResultLine(label: "Note", value: event.note)
                    ],
                    note: "Cue instruction and host action stay off this surface."
                )

                SectionCard(title: "Immutable record") {
                    DetailRow(label: "Cover", value: coverLabel(event.cardID), isProminent: true)
                    DetailRow(label: "Outcome", value: outcomeLabel(event.outcome))
                    DetailRow(label: "Recorded", value: event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    DetailRow(label: "Lock", value: event.lockKind.label)
                    DetailRow(label: "Source", value: event.wasRehearsal ? "Practice result" : "Host result")
                    DetailRow(label: "Note", value: event.note)
                }

                ChipRow {
                    TagChip(
                        title: event.wasRehearsal ? "Practice result" : "Host result",
                        systemImage: event.wasRehearsal ? "theatermasks" : "person.fill"
                    )
                    TagChip(title: event.lockKind.label, systemImage: "lock.fill")
                    TagChip(title: outcomeLabel(event.outcome), systemImage: iconName(for: event.outcome))
                }
            }

            if let recap {
                SectionCard(title: recap.title, footnote: recap.createdAt.formatted(date: .abbreviated, time: .shortened)) {
                    Text(recap.summary)
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(recap.summary)
                }

                TileGrid {
                    MetricTile(
                        title: "Events",
                        value: "\(recap.eventCount)",
                        caption: "In this recap",
                        systemImage: "square.stack"
                    )
                    MetricTile(
                        title: "Opened",
                        value: "\(openedInRecap)",
                        caption: "Host and practice",
                        systemImage: "envelope.open.fill"
                    )
                    MetricTile(
                        title: "Closed",
                        value: "\(closedInRecap)",
                        caption: "Burned windows",
                        systemImage: "flame.fill"
                    )
                }
            }

            if !related.isEmpty {
                SectionCard(
                    title: recapRequest == nil ? "Same cover" : "Included outcomes",
                    footnote: "Outcomes only. Sealed reveal content stays hidden."
                ) {
                    ForEach(related, id: \.id) { item in
                        DetailRow(
                            label: outcomeLabel(item.outcome),
                            value: item.occurredAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }
            }

            CTAButton(
                title: recap == nil ? "Build recap" : "Refresh recap",
                systemImage: "doc.text",
                hint: "Builds a copyable local summary from the selected archive IDs."
            ) {
                primaryAction()
            }

            if event != nil {
                CTAButton(
                    title: "Open cover",
                    systemImage: "doc.plaintext",
                    emphasis: .secondary,
                    hint: "Opens the cover line for this archived card."
                ) {
                    secondaryAction()
                }
            }

            CTAButton(
                title: "Back to archive",
                systemImage: "archivebox",
                emphasis: .secondary,
                hint: "Returns to the archive list."
            ) {
                returnAction()
            }
        }
    }

    private var emptyBody: some View {
        ScreenScaffold(scrolls: false) {
            ScreenHeader(
                title: "Archive event",
                subtitle: "This outcome is no longer in the on-device archive."
            )

            EmptyStateCard(
                title: "Event unavailable",
                message: "The selected archive row is gone. Return to the archive and pick another recorded outcome.",
                systemImage: "archivebox",
                actionTitle: "Back to archive",
                action: returnAction
            )
        }
    }

    private var openedInRecap: Int {
        related.filter { $0.outcome == .opened || $0.outcome == .rehearsalOpened }.count
    }

    private var closedInRecap: Int {
        related.filter { $0.outcome == .burned || $0.outcome == .rehearsalBurned }.count
    }

    private func refresh() {
        if let recapRequest {
            recap = archive.recap(eventIDs: recapRequest.eventIDs, generatedAt: recapRequest.generatedAt)
            related = recapRequest.eventIDs.compactMap { archive.archiveEvent(id: $0) }
            event = related.first
        } else if let eventID {
            event = archive.archiveEvent(id: eventID)
            if let event {
                related = archive.archiveEvents().filter { $0.cardID == event.cardID }
            }
        }

        viewState = event == nil && recap == nil ? .empty : .loaded
    }

    private func primaryAction() {
        showRecapState()
    }

    private func secondaryAction() {
        if let event {
            openCover(event)
        }
    }

    private func returnAction() {
        dismiss()
    }

    private func showRecapState() {
        let ids: [String]
        if let recapRequest {
            ids = recapRequest.eventIDs
        } else if let event {
            ids = [event.id]
        } else {
            return
        }

        recap = archive.recap(eventIDs: ids, generatedAt: Date())
        related = ids.compactMap { archive.archiveEvent(id: $0) }
        recapPulse += 1
        viewState = .loaded
    }

    private func openCover(_ event: UnlockEvent) {
        navigatePulse += 1
        store.path.append(
            .coverDetail(
                CoverRoutePayload(
                    id: "archive-cover-\(event.cardID)",
                    cardID: event.cardID,
                    sourceTab: .archive,
                    rehearsalSessionID: nil
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

    private func lockPath(_ event: UnlockEvent) -> String {
        "\(event.lockKind.label) → \(outcomeLabel(event.outcome))"
    }

    private func iconName(for outcome: ArchiveOutcome) -> String {
        switch outcome {
        case .opened, .rehearsalOpened: return "envelope.open.fill"
        case .burned, .rehearsalBurned: return "flame.fill"
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
        ArchiveEventDetailScreen(
            dependencies: .preview(modelContext: container.mainContext),
            payload: ArchiveRoutePayload(
                id: "archive-event-001",
                eventID: "event-001",
                cardID: "card-012",
                sourceTab: .archive
            )
        )
        .modelContainer(container)
    }
}
