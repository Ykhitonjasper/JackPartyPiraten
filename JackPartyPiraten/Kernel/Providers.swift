import Foundation
import Observation
import SwiftData

@MainActor
final class SwiftDataRevealCardProvider: RevealCardRepository {
    private let context: ModelContext
    private let engine: any FuseEvaluating

    init(context: ModelContext, engine: any FuseEvaluating) {
        self.context = context
        self.engine = engine
        seedIfNeeded()
    }

    func coverCards(now: Date, confirmations: Set<UnlockConfirmation>) -> [CoverCard] {
        cards().compactMap { card in
            guard let lock = locks().first(where: { $0.id == card.lockID })?.snapshot else { return nil }
            let input = FuseCardState(id: card.id, persistedPhase: card.phase, lock: lock, recipeID: card.recipeID)
            return card.cover(lock: lock, phase: engine.state(card: input, now: now, confirmations: confirmations))
        }.sorted { $0.id < $1.id }
    }

    func coverCard(id: String, now: Date, confirmations: Set<UnlockConfirmation>) -> CoverCard? {
        coverCards(now: now, confirmations: confirmations).first { $0.id == id }
    }

    func transition(cardID: String, attempt: UnlockAttempt, now: Date, isRehearsal: Bool) -> RevealTransition {
        guard let card = cards().first(where: { $0.id == cardID }), let lock = locks().first(where: { $0.id == card.lockID })?.snapshot else { return .unavailable(cardID) }
        let confirmation: UnlockConfirmation
        switch attempt {
        case .exactTime: confirmation = UnlockConfirmation(id: "confirm-time-\(cardID)", cardID: cardID, kind: .exactTime, suppliedCode: nil, confirmedAt: now)
        case .calendarDate: confirmation = UnlockConfirmation(id: "confirm-date-\(cardID)", cardID: cardID, kind: .calendarDate, suppliedCode: nil, confirmedAt: now)
        case .localCode(let code): confirmation = UnlockConfirmation(id: "confirm-code-\(cardID)", cardID: cardID, kind: .localCode, suppliedCode: code, confirmedAt: now)
        case .hostArrivalConfirmed: confirmation = UnlockConfirmation(id: "confirm-arrival-\(cardID)", cardID: cardID, kind: .hostConfirmedArrival, suppliedCode: nil, confirmedAt: now)
        }
        let input = FuseCardState(id: card.id, persistedPhase: card.phase, lock: lock, recipeID: card.recipeID)
        let phase = engine.state(card: input, now: now, confirmations: [confirmation])
        if phase == .sealed { return .sealed(card.cover(lock: lock, phase: .sealed)) }
        if phase == .burned {
            card.phase = .burned
            appendEvent(cardID: cardID, lockKind: lock.kind, at: now, outcome: isRehearsal ? .rehearsalBurned : .burned, rehearsal: isRehearsal)
            return .burned(card.burned(at: now))
        }
        card.phase = .opened
        appendEvent(cardID: cardID, lockKind: lock.kind, at: now, outcome: isRehearsal ? .rehearsalOpened : .opened, rehearsal: isRehearsal)
        return card.opened(at: now).map(RevealTransition.opened) ?? .unavailable(cardID)
    }

    func openedReveal(cardID: String, at: Date) -> OpenedReveal? {
        cards().first { $0.id == cardID }?.opened(at: at)
    }

    func createCard(_ draft: RevealCardDraft, now: Date) -> String {
        let ordinal = cards().count + 1
        let stamp = Int(now.timeIntervalSince1970)
        let cardID = "card-local-\(stamp)-\(ordinal)"
        let lockID = "lock-local-\(stamp)-\(ordinal)"
        context.insert(RevealCard(id: cardID, coverText: draft.coverLine.text, coverSafetyContext: draft.coverLine.safetyContext, cueInstruction: draft.revealCue.instruction, cueHostAction: draft.revealCue.hostAction, cueSafetyNote: draft.revealCue.safetyNote, cueSeconds: draft.revealCue.estimatedSeconds, lockID: lockID, recipeID: draft.recipeID, burnAt: draft.lock.burnAt, phase: .sealed, createdAt: now))
        context.insert(LockCondition(id: lockID, cardID: cardID, kind: draft.lock.kind, thresholdDate: draft.lock.thresholdDate, code: draft.lock.localCode, burnAt: draft.lock.burnAt, createdAt: now))
        try? context.save()
        return cardID
    }

    private func cards() -> [RevealCard] { (try? context.fetch(FetchDescriptor<RevealCard>())) ?? [] }
    private func locks() -> [LockCondition] { (try? context.fetch(FetchDescriptor<LockCondition>())) ?? [] }
    private func seedIfNeeded() {
        if cards().isEmpty { SeedCatalog.revealCards.forEach { context.insert($0) } }
        if locks().isEmpty { SeedCatalog.lockConditions.forEach { context.insert($0) } }
        try? context.save()
    }
    private func appendEvent(cardID: String, lockKind: LockKind, at: Date, outcome: ArchiveOutcome, rehearsal: Bool) {
        context.insert(UnlockEvent(id: "event-\(cardID)-\(Int(at.timeIntervalSince1970))-\(outcome.rawValue)", cardID: cardID, occurredAt: at, outcome: outcome, lockKind: lockKind, wasRehearsal: rehearsal, note: rehearsal ? "Rehearsal outcome recorded." : "Host outcome recorded."))
        try? context.save()
    }
}

@MainActor
final class SwiftDataArchiveProvider: ArchiveRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context; seedIfNeeded() }
    func archiveEvents() -> [UnlockEvent] { events().sorted { $0.occurredAt > $1.occurredAt } }
    func archiveEvent(id: String) -> UnlockEvent? { events().first { $0.id == id } }
    func recap(eventIDs: [String], generatedAt: Date) -> EventRecap {
        let selected = events().filter { eventIDs.contains($0.id) }
        let opened = selected.filter { $0.outcome == .opened || $0.outcome == .rehearsalOpened }.count
        return EventRecap(id: "recap-\(Int(generatedAt.timeIntervalSince1970))-\(selected.count)", title: "Reveal Sequence Recap", createdAt: generatedAt, eventCount: selected.count, summary: "\(opened) opened and \(selected.count - opened) closed. Sealed cue text is excluded.")
    }
    private func events() -> [UnlockEvent] { (try? context.fetch(FetchDescriptor<UnlockEvent>())) ?? [] }
    private func seedIfNeeded() { if events().isEmpty { SeedCatalog.unlockEvents.forEach { context.insert($0) }; try? context.save() } }
}

struct SeededSituationRecipeProvider: SituationRecipeRepository, Sendable {
    func situationRecipes() -> [SituationRecipe] { SeedCatalog.situationRecipes }
    func situationRecipe(id: String) -> SituationRecipe? { SeedCatalog.situationRecipes.first { $0.id == id } }
}

struct SeededRehearsalProvider: RehearsalRepository, Sendable {
    func rehearsalSessions() -> [RehearsalSession] { SeedCatalog.rehearsalSessions }
    func rehearsalSession(id: String) -> RehearsalSession? { SeedCatalog.rehearsalSessions.first { $0.id == id } }
}

@MainActor
final class SwiftDataPreferenceProvider: PreferenceRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context; seedIfNeeded() }
    func onboardingCompleted() -> Bool { preferences().first?.onboardingCompleted ?? false }
    func setOnboardingCompleted(_ completed: Bool, at: Date) -> Void {
        if let preference = preferences().first { preference.onboardingCompleted = completed; preference.updatedAt = at }
        else { context.insert(AppPreference(id: "preference-main", onboardingCompleted: completed, updatedAt: at, schemaVersion: 1)) }
        try? context.save()
    }
    private func preferences() -> [AppPreference] { (try? context.fetch(FetchDescriptor<AppPreference>())) ?? [] }
    private func seedIfNeeded() { if preferences().isEmpty { SeedCatalog.appPreferences.forEach { context.insert($0) }; try? context.save() } }
}

@MainActor
final class SwiftDataLocalResetProvider: LocalResetting {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func deleteAllRecords(at: Date) -> Void {
        ((try? context.fetch(FetchDescriptor<RevealCard>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<LockCondition>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<UnlockEvent>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<AppPreference>())) ?? []).forEach { context.delete($0) }
        context.insert(AppPreference(id: "preference-main", onboardingCompleted: false, updatedAt: at, schemaVersion: 1))
        try? context.save()
    }
}

@MainActor
@Observable
final class AppStore {
    var selectedTab: FuseTab = .fuses
    var path: [AppRoute] = []
    var onboardingComplete: Bool
    var hostArrivalConfirmations: Set<String> = []
    var rehearsalNow: Date?
    init(onboardingComplete: Bool) { self.onboardingComplete = onboardingComplete }
    func confirmHostArrival(for cardID: String) { hostArrivalConfirmations.insert(cardID) }
    func resetAfterDeletion() { selectedTab = .fuses; path.removeAll(); onboardingComplete = false; hostArrivalConfirmations.removeAll(); rehearsalNow = nil }
}

@MainActor
struct AppDependencies {
    let revealCards: any RevealCardRepository
    let archive: any ArchiveRepository
    let recipes: any SituationRecipeRepository
    let rehearsals: any RehearsalRepository
    let preferences: any PreferenceRepository
    let resetter: any LocalResetting
    let fuseEngine: any FuseEvaluating
    let rehearsalClock: any RehearsalClockProviding
    let appStore: AppStore

    static func live(modelContext: ModelContext) -> AppDependencies {
        let engine = FuseEngine()
        let preferences = SwiftDataPreferenceProvider(context: modelContext)
        return AppDependencies(revealCards: SwiftDataRevealCardProvider(context: modelContext, engine: engine), archive: SwiftDataArchiveProvider(context: modelContext), recipes: SeededSituationRecipeProvider(), rehearsals: SeededRehearsalProvider(), preferences: preferences, resetter: SwiftDataLocalResetProvider(context: modelContext), fuseEngine: engine, rehearsalClock: DeterministicRehearsalClock(), appStore: AppStore(onboardingComplete: preferences.onboardingCompleted()))
    }

    static func preview(modelContext: ModelContext) -> AppDependencies {
        live(modelContext: modelContext)
    }
}
