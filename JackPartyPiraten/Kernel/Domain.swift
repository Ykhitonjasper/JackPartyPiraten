import Foundation
import SwiftData

enum RevealPhase: String, Codable, CaseIterable, Sendable {
    case sealed
    case unlockable
    case opened
    case burned
}

enum LockKind: String, Codable, CaseIterable, Sendable {
    case exactTime
    case calendarDate
    case localCode
    case hostConfirmedArrival
}

enum ArchiveOutcome: String, Codable, CaseIterable, Sendable {
    case opened
    case burned
    case rehearsalOpened
    case rehearsalBurned
}

enum UnlockAttempt: Hashable, Sendable {
    case exactTime
    case calendarDate
    case localCode(String)
    case hostArrivalConfirmed
}

struct CoverLine: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let text: String
    let safetyContext: String
    let recipeID: String
    let createdAt: Date
}

struct RevealCue: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let instruction: String
    let hostAction: String
    let safetyNote: String
    let estimatedSeconds: Int
}

struct LockSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let kind: LockKind
    let thresholdDate: Date?
    let expectedCode: String?
    let burnAt: Date
}

struct FuseCardState: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let persistedPhase: RevealPhase
    let lock: LockSnapshot
    let recipeID: String
}

struct CoverCard: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let coverLine: CoverLine
    let lockKind: LockKind
    let lockSummary: String
    let phase: RevealPhase
    let burnAt: Date
    let recipeID: String
}

struct OpenedReveal: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let coverLine: CoverLine
    let revealCue: RevealCue
    let openedAt: Date
    let recipeID: String
}

struct BurnedReveal: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let coverLine: CoverLine
    let burnedAt: Date
    let reason: String
    let recipeID: String
}

enum RevealTransition: Sendable {
    case sealed(CoverCard)
    case opened(OpenedReveal)
    case burned(BurnedReveal)
    case unavailable(String)
}

struct UnlockConfirmation: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let cardID: String
    let kind: LockKind
    let suppliedCode: String?
    let confirmedAt: Date
}

struct LockConditionDraft: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let kind: LockKind
    let thresholdDate: Date?
    let localCode: String?
    let burnAt: Date
}

struct RevealCardDraft: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let coverLine: CoverLine
    let revealCue: RevealCue
    let lock: LockConditionDraft
    let recipeID: String
}

struct SituationRecipe: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let momentPrompt: String
    let coverPrompt: String
    let cuePrompt: String
    let suggestedLockKind: LockKind
}

struct RehearsalSession: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let cardID: String
    let referenceNow: Date
    let expectedPhase: RevealPhase
    let shoulderSafeCheck: String
}

struct EventRecap: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let createdAt: Date
    let eventCount: Int
    let summary: String
}

struct CoverRoutePayload: Identifiable, Hashable, Sendable {
    let id: String
    let cardID: String
    let sourceTab: FuseTab
    let rehearsalSessionID: String?
}

struct RecipeRoutePayload: Identifiable, Hashable, Sendable {
    let id: String
    let recipeID: String
    let sourceTab: FuseTab
    let suggestedLockKind: LockKind
}

struct ArchiveRoutePayload: Identifiable, Hashable, Sendable {
    let id: String
    let eventID: String
    let cardID: String
    let sourceTab: FuseTab
}

struct RehearsalRoutePayload: Identifiable, Hashable, Sendable {
    let id: String
    let sessionID: String
    let cardID: String
    let referenceNow: Date
}

struct RecapRoutePayload: Identifiable, Hashable, Sendable {
    let id: String
    let eventIDs: [String]
    let sourceTab: FuseTab
    let generatedAt: Date
}

@Model
final class RevealCard: Identifiable {
    @Attribute(.unique) var id: String
    var coverText: String
    var coverSafetyContext: String
    private var cueInstruction: String
    private var cueHostAction: String
    private var cueSafetyNote: String
    var cueSeconds: Int
    var lockID: String
    var recipeID: String
    var burnAt: Date
    var phaseRaw: String
    var createdAt: Date

    init(id: String, coverText: String, coverSafetyContext: String, cueInstruction: String, cueHostAction: String, cueSafetyNote: String, cueSeconds: Int, lockID: String, recipeID: String, burnAt: Date, phase: RevealPhase, createdAt: Date) {
        self.id = id
        self.coverText = coverText
        self.coverSafetyContext = coverSafetyContext
        self.cueInstruction = cueInstruction
        self.cueHostAction = cueHostAction
        self.cueSafetyNote = cueSafetyNote
        self.cueSeconds = cueSeconds
        self.lockID = lockID
        self.recipeID = recipeID
        self.burnAt = burnAt
        self.phaseRaw = phase.rawValue
        self.createdAt = createdAt
    }

    var phase: RevealPhase {
        get { RevealPhase(rawValue: phaseRaw) ?? .sealed }
        set { phaseRaw = newValue.rawValue }
    }

    func cover(lock: LockSnapshot, phase: RevealPhase) -> CoverCard {
        CoverCard(id: id, coverLine: CoverLine(id: "cover-\(id)", text: coverText, safetyContext: coverSafetyContext, recipeID: recipeID, createdAt: createdAt), lockKind: lock.kind, lockSummary: lock.kind.label, phase: phase, burnAt: burnAt, recipeID: recipeID)
    }

    func opened(at: Date) -> OpenedReveal? {
        guard phase == .opened else { return nil }
        let cue = RevealCue(id: "cue-\(id)", instruction: cueInstruction, hostAction: cueHostAction, safetyNote: cueSafetyNote, estimatedSeconds: cueSeconds)
        return OpenedReveal(id: id, coverLine: cover(lock: LockSnapshot(id: lockID, kind: .exactTime, thresholdDate: nil, expectedCode: nil, burnAt: burnAt), phase: .opened).coverLine, revealCue: cue, openedAt: at, recipeID: recipeID)
    }

    func burned(at: Date) -> BurnedReveal {
        BurnedReveal(id: id, coverLine: CoverLine(id: "cover-\(id)", text: coverText, safetyContext: coverSafetyContext, recipeID: recipeID, createdAt: createdAt), burnedAt: at, reason: "The reveal window closed before opening.", recipeID: recipeID)
    }
}

@Model
final class LockCondition: Identifiable {
    @Attribute(.unique) var id: String
    var cardID: String
    var kindRaw: String
    var thresholdDate: Date?
    var code: String?
    var burnAt: Date
    var createdAt: Date

    init(id: String, cardID: String, kind: LockKind, thresholdDate: Date?, code: String?, burnAt: Date, createdAt: Date) {
        self.id = id
        self.cardID = cardID
        self.kindRaw = kind.rawValue
        self.thresholdDate = thresholdDate
        self.code = code
        self.burnAt = burnAt
        self.createdAt = createdAt
    }

    var kind: LockKind { LockKind(rawValue: kindRaw) ?? .exactTime }
    var snapshot: LockSnapshot { LockSnapshot(id: id, kind: kind, thresholdDate: thresholdDate, expectedCode: code, burnAt: burnAt) }
}

@Model
final class UnlockEvent: Identifiable {
    @Attribute(.unique) var id: String
    var cardID: String
    var occurredAt: Date
    var outcomeRaw: String
    var lockKindRaw: String
    var wasRehearsal: Bool
    var note: String

    init(id: String, cardID: String, occurredAt: Date, outcome: ArchiveOutcome, lockKind: LockKind, wasRehearsal: Bool, note: String) {
        self.id = id
        self.cardID = cardID
        self.occurredAt = occurredAt
        self.outcomeRaw = outcome.rawValue
        self.lockKindRaw = lockKind.rawValue
        self.wasRehearsal = wasRehearsal
        self.note = note
    }

    var outcome: ArchiveOutcome
    { ArchiveOutcome(rawValue: outcomeRaw) ?? .burned }
    var lockKind: LockKind { LockKind(rawValue: lockKindRaw) ?? .exactTime }
}

@Model
final class AppPreference: Identifiable {
    @Attribute(.unique) var id: String
    var onboardingCompleted: Bool
    var updatedAt: Date
    var schemaVersion: Int

    init(id: String, onboardingCompleted: Bool, updatedAt: Date, schemaVersion: Int) {
        self.id = id
        self.onboardingCompleted = onboardingCompleted
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }
}

extension LockKind {
    var label: String {
        switch self {
        case .exactTime: return "Exact time"
        case .calendarDate: return "Calendar date"
        case .localCode: return "Local code"
        case .hostConfirmedArrival: return "Host-confirmed arrival"
        }
    }
}
