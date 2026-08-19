import Foundation

enum SeedCatalog {
    private static func d(_ value:TimeInterval) -> Date { Date(timeIntervalSince1970:value) }
    private static let cardRows:[(String,String,String,String,LockKind,TimeInterval,String?,TimeInterval,RevealPhase,String)] = [
        ("card-001","lock-001","Keep the fruit bowl on the left.","Bring out the candle tray when music pauses.",.exactTime,1787086800,nil,1787092200,.sealed,"recipe-kitchen"),
        ("card-002","lock-002","The blue cushion belongs by the window.","Guide the guest toward the photo cushion.",.calendarDate,1787184000,nil,1787259600,.sealed,"recipe-couch"),
        ("card-003","lock-003","Ribbon scissors are in the top drawer.","Place the wrapped album at the front.",.localCode,0,"RIBBON",1787348400,.sealed,"recipe-gift-table"),
        ("card-004","lock-004","Set the phone face down by the charger.","Play the prepared local voice note.",.hostConfirmedArrival,0,nil,1787438400,.sealed,"recipe-phone-nearby"),
        ("card-005","lock-005","The hall light can stay dim.","Switch on the string lights at the door.",.exactTime,1787528700,nil,1787531400,.sealed,"recipe-back-in-room"),
        ("card-006","lock-006","Chill water on the lower shelf.","Pour the first glass into the striped cup.",.calendarDate,1787529600,nil,1787614800,.sealed,"recipe-kitchen"),
        ("card-007","lock-007","Fold the spare blanket over the chair.","Unfold the banner hidden inside.",.localCode,0,"BLANKET",1787697600,.sealed,"recipe-couch"),
        ("card-008","lock-008","Put plain envelopes behind the stand.","Hand over the envelope marked with a star.",.exactTime,1787074200,nil,1787176800,.unlockable,"recipe-gift-table"),
        ("card-009","lock-009","Leave the cable beside the lamp.","Show the prepared photo after the toast.",.calendarDate,1787011200,nil,1787180400,.unlockable,"recipe-phone-nearby"),
        ("card-010","lock-010","Place indoor shoes beside the bench.","Cue the welcome chorus after the knock.",.exactTime,1787076000,nil,1787184000,.unlockable,"recipe-back-in-room"),
        ("card-011","lock-011","Stack plates beside the napkins.","Carry dessert in after the first toast.",.calendarDate,1787011200,nil,1787185800,.unlockable,"recipe-kitchen"),
        ("card-012","lock-012","Keep the reading lamp warm.","Open the folded note together.",.localCode,0,"NOTE",1787180400,.opened,"recipe-couch"),
        ("card-013","lock-013","Align place cards with the table edge.","Turn over the center place card.",.calendarDate,1787011200,nil,1787182200,.opened,"recipe-gift-table"),
        ("card-014","lock-014","The speaker volume is set.","Play the celebration track after arrival.",.hostConfirmedArrival,0,nil,1787184000,.opened,"recipe-phone-nearby"),
        ("card-015","lock-015","The nearest coat hook is free.","Offer the paper crown after the coat is hung.",.exactTime,1787076900,nil,1787187600,.opened,"recipe-back-in-room"),
        ("card-016","lock-016","Keep two mugs on the drying mat.","Set out the cocoa topper.",.localCode,0,"COCOA",1786999200,.burned,"recipe-kitchen"),
        ("card-017","lock-017","The side table has room for one book.","Open the scrapbook to the marked page.",.hostConfirmedArrival,0,nil,1787002800,.burned,"recipe-couch"),
        ("card-018","lock-018","The paper bag can stay under the table.","Scatter the paper stars after the gift opens.",.exactTime,1787001000,nil,1787006400,.burned,"recipe-gift-table")
    ]
    static var revealCards:[RevealCard] { cardRows.map { row in RevealCard(id:row.0, coverText:row.2, coverSafetyContext:"Keep the walking path clear.", cueInstruction:row.3, cueHostAction:"Perform the prepared host action.", cueSafetyNote:"Use only the prepared local materials.", cueSeconds:20, lockID:row.1, recipeID:row.9, burnAt:d(row.7), phase:row.8, createdAt:d(1785585600)) } }
    static var lockConditions:[LockCondition] { cardRows.map { row in LockCondition(id:row.1, cardID:row.0, kind:row.4, thresholdDate:row.5 == 0 ? nil:d(row.5), code:row.6, burnAt:d(row.7), createdAt:d(1785585600)) } }
    private static let eventRows:[(String,String,TimeInterval,ArchiveOutcome,LockKind,Bool)] = [
        ("event-001","card-012",1787076300,.opened,.localCode,false),("event-002","card-013",1787076600,.opened,.calendarDate,false),("event-003","card-014",1787077200,.opened,.hostConfirmedArrival,false),("event-004","card-015",1787077500,.opened,.exactTime,false),
        ("event-005","card-016",1786999200,.burned,.localCode,false),("event-006","card-017",1787002800,.burned,.hostConfirmedArrival,false),("event-007","card-018",1787006400,.burned,.exactTime,false),("event-008","card-008",1787075100,.rehearsalOpened,.exactTime,true),
        ("event-009","card-009",1787075400,.rehearsalOpened,.calendarDate,true),("event-010","card-010",1787076060,.rehearsalOpened,.exactTime,true),("event-011","card-003",1787076720,.rehearsalBurned,.localCode,true),("event-012","card-004",1787077080,.rehearsalOpened,.hostConfirmedArrival,true)
    ]
    static var unlockEvents:[UnlockEvent] { eventRows.map { UnlockEvent(id:$0.0, cardID:$0.1, occurredAt:d($0.2), outcome:$0.3, lockKind:$0.4, wasRehearsal:$0.5, note:$0.5 ? "Rehearsal outcome recorded.":"Host outcome recorded.") } }
    static let situationRecipes:[SituationRecipe] = [
        SituationRecipe(id:"recipe-kitchen",title:"Kitchen",momentPrompt:"Prepare while serving continues.",coverPrompt:"Write a harmless placement note.",cuePrompt:"Name one short serving action.",suggestedLockKind:.exactTime),
        SituationRecipe(id:"recipe-couch",title:"Couch",momentPrompt:"Keep the room calm.",coverPrompt:"Describe an ordinary cushion task.",cuePrompt:"Name the movement that starts the reveal.",suggestedLockKind:.localCode),
        SituationRecipe(id:"recipe-gift-table",title:"Gift Table",momentPrompt:"Stage one clear handoff.",coverPrompt:"Describe safe table arrangement.",cuePrompt:"Identify the exact object.",suggestedLockKind:.calendarDate),
        SituationRecipe(id:"recipe-phone-nearby",title:"Phone Nearby",momentPrompt:"Prepare local media privately.",coverPrompt:"Describe a charging note.",cuePrompt:"Name the prepared media action.",suggestedLockKind:.hostConfirmedArrival),
        SituationRecipe(id:"recipe-back-in-room",title:"Back in Room",momentPrompt:"Coordinate the doorway return.",coverPrompt:"Describe a normal entrance setup.",cuePrompt:"Name the visible host signal.",suggestedLockKind:.hostConfirmedArrival)
    ]
    static let rehearsalSessions:[RehearsalSession] = [
        RehearsalSession(id:"rehearsal-001",title:"Exact Time Walkthrough",cardID:"card-008",referenceNow:d(1787075100),expectedPhase:.unlockable,shoulderSafeCheck:"Only the envelope cover is visible."),
        RehearsalSession(id:"rehearsal-002",title:"Local Code Walkthrough",cardID:"card-003",referenceNow:d(1787076720),expectedPhase:.sealed,shoulderSafeCheck:"The cue remains absent until the code clears."),
        RehearsalSession(id:"rehearsal-003",title:"Arrival Tap Walkthrough",cardID:"card-004",referenceNow:d(1787077080),expectedPhase:.sealed,shoulderSafeCheck:"The host performs the arrival action locally.")
    ]
    static var appPreferences:[AppPreference] { [AppPreference(id:"preference-main",onboardingCompleted:false,updatedAt:d(1787054400),schemaVersion:1)] }
    static var lockKinds: [LockCondition] {
        let created = d(1785585600)
        return [
            LockCondition(id: "kind-exact-time", cardID: "kind-card-exact-time", kind: .exactTime, thresholdDate: d(1787076000), code: nil, burnAt: d(1787184000), createdAt: created),
            LockCondition(id: "kind-calendar-date", cardID: "kind-card-calendar-date", kind: .calendarDate, thresholdDate: d(1787011200), code: nil, burnAt: d(1787184000), createdAt: created),
            LockCondition(id: "kind-local-code", cardID: "kind-card-local-code", kind: .localCode, thresholdDate: nil, code: "LOCAL", burnAt: d(1787184000), createdAt: created),
            LockCondition(id: "kind-host-arrival", cardID: "kind-card-host-arrival", kind: .hostConfirmedArrival, thresholdDate: nil, code: nil, burnAt: d(1787184000), createdAt: created)
        ]
    }
}
