import Foundation

enum FuseTab: String, CaseIterable, Hashable, Sendable {
    case fuses = "Fuses"
    case create = "Create"
    case archive = "Archive"
    case settings = "Settings"
}

enum AppRoute: Hashable, Sendable {
    case coverDetail(CoverRoutePayload)
    case glancePreview(CoverRoutePayload)
    case situationRecipes(RecipeRoutePayload)
    case unlockGate(CoverRoutePayload)
    case revealedCue(CoverRoutePayload)
    case burnedCue(CoverRoutePayload)
    case archiveDetail(ArchiveRoutePayload)
    case rehearsalBoard(RehearsalRoutePayload)
    case eventRecap(RecapRoutePayload)
}

@MainActor
protocol RevealCardRepository {
    func coverCards(now: Date, confirmations: Set<UnlockConfirmation>) -> [CoverCard]
    func coverCard(id: String, now: Date, confirmations: Set<UnlockConfirmation>) -> CoverCard?
    func transition(cardID: String, attempt: UnlockAttempt, now: Date, isRehearsal: Bool) -> RevealTransition
    func openedReveal(cardID: String, at: Date) -> OpenedReveal?
    func createCard(_ draft: RevealCardDraft, now: Date) -> String
}

@MainActor
protocol ArchiveRepository {
    func archiveEvents() -> [UnlockEvent]
    func archiveEvent(id: String) -> UnlockEvent?
    func recap(eventIDs: [String], generatedAt: Date) -> EventRecap
}

protocol SituationRecipeRepository {
    func situationRecipes() -> [SituationRecipe]
    func situationRecipe(id: String) -> SituationRecipe?
}

protocol RehearsalRepository {
    func rehearsalSessions() -> [RehearsalSession]
    func rehearsalSession(id: String) -> RehearsalSession?
}

@MainActor
protocol PreferenceRepository {
    func onboardingCompleted() -> Bool
    func setOnboardingCompleted(_ completed: Bool, at: Date) -> Void
}

@MainActor
protocol LocalResetting {
    func deleteAllRecords(at: Date) -> Void
}

protocol FuseEvaluating {
    func state(card: FuseCardState, now: Date, confirmations: Set<UnlockConfirmation>) -> RevealPhase
}

protocol RehearsalClockProviding {
    func now(for session: RehearsalSession) -> Date
}

struct FuseEngine: FuseEvaluating, Sendable {
    func state(card: FuseCardState, now: Date, confirmations: Set<UnlockConfirmation>) -> RevealPhase {
        if card.persistedPhase == .opened { return .opened }
        if card.persistedPhase == .burned { return .burned }
        if now >= card.lock.burnAt { return .burned }
        switch card.lock.kind {
        case .exactTime:
            return card.lock.thresholdDate.map { now >= $0 } == true ? .unlockable : .sealed
        case .calendarDate:
            guard let date = card.lock.thresholdDate else { return .sealed }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
            return calendar.startOfDay(for: now) >= calendar.startOfDay(for: date) ? .unlockable : .sealed
        case .localCode:
            return confirmations.contains { $0.cardID == card.id && $0.kind == .localCode && $0.suppliedCode == card.lock.expectedCode } ? .unlockable : .sealed
        case .hostConfirmedArrival:
            return confirmations.contains { $0.cardID == card.id && $0.kind == .hostConfirmedArrival } ? .unlockable : .sealed
        }
    }
}

struct DeterministicRehearsalClock: RehearsalClockProviding, Sendable {
    func now(for session: RehearsalSession) -> Date { session.referenceNow }
}
