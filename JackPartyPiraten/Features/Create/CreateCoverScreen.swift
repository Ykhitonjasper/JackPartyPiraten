import SwiftData
import SwiftUI

enum CreateCoverScreenViewState {
    case loaded
    case empty
}

struct CreateCoverScreen: View {
    private let dependencies: AppDependencies
    private let revealCards: any RevealCardRepository
    private let recipes: any SituationRecipeRepository
    private let store: AppStore

    @State private var viewState: CreateCoverScreenViewState = .loaded
    @State private var availableRecipes: [SituationRecipe] = []
    @State private var recipeID = ""
    @State private var coverText = ""
    @State private var coverSafety = ""
    @State private var cueInstruction = ""
    @State private var cueHostAction = ""
    @State private var cueSafetyNote = ""
    @State private var cueSeconds = 20
    @State private var lockKind: LockKind = .exactTime
    @State private var thresholdDate = Date()
    @State private var localCode = ""
    @State private var burnAt = Date()
    @State private var validationNote: String?
    @State private var savedCardID: String?
    @State private var recipePayload: RecipeRoutePayload?
    @State private var savePulse = 0
    @State private var recipePulse = 0

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        revealCards = dependencies.revealCards
        recipes = dependencies.recipes
        store = dependencies.appStore
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
        }
        .sheet(item: $recipePayload) { payload in
            SituationRecipesScreen(dependencies: dependencies, payload: payload) { recipe in
                applyRecipe(recipe)
            }
        }
        .task {
            refresh()
        }
        .sensoryFeedback(.success, trigger: savePulse)
        .sensoryFeedback(.selection, trigger: recipePulse)
    }

    private var loadedBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Create cover",
                subtitle: "Write the shoulder-safe cover and the private cue as a pair, then arm one of the four local locks."
            )

            if let savedCardID {
                ResultCard(
                    title: "Saved locally",
                    value: "Ready",
                    lines: [
                        ResultLine(label: "Cover", value: coverSummary),
                        ResultLine(label: "Card", value: savedCardID)
                    ],
                    note: "The new cover sits with the other local fuses."
                )
            }

            SectionCard(title: "Situation recipe", footnote: "A recipe fills both sides of the pair without leaving this tab.") {
                if availableRecipes.isEmpty {
                    DetailRow(label: "Recipes", value: "None on device")
                } else {
                    ChipRow {
                        ForEach(availableRecipes) { recipe in
                            FilterChip(title: recipe.title, isSelected: recipeID == recipe.id) {
                                applyRecipe(recipe)
                            }
                        }
                    }
                }

                NavigationRow(
                    title: "Browse recipes",
                    subtitle: "Review prompts and suggested locks",
                    systemImage: "list.bullet.rectangle",
                    hint: "Opens the local recipe board"
                ) {
                    secondaryAction()
                }
            }

            SectionCard(title: "Paired copy", footnote: "The cover stays visible. The cue stays sealed until a lock opens.") {
                labeledField("Cover line", text: $coverText, hint: "Ordinary placement note")
                labeledField("Cover context", text: $coverSafety, hint: "Keep paths and hands clear")
                labeledField("Cue instruction", text: $cueInstruction, hint: "Prepared host action")
                labeledField("Host action", text: $cueHostAction, hint: "What the host does after opening")
                labeledField("Safety note", text: $cueSafetyNote, hint: "Local materials only")

                SectionLabel(title: "Cue length", detail: "\(cueSeconds)s")
                ChipRow {
                    ForEach(Self.cueDurations, id: \.self) { seconds in
                        FilterChip(title: "\(seconds)s", isSelected: cueSeconds == seconds) {
                            cueSeconds = seconds
                        }
                    }
                }
            }

            SectionCard(title: "Local lock", footnote: lockFootnote) {
                ChipRow {
                    ForEach(Self.lockChoices, id: \.self) { kind in
                        FilterChip(title: lockTitle(kind), isSelected: lockKind == kind) {
                            lockKind = kind
                        }
                    }
                }

                lockFields
            }

            if let validationNote {
                SectionCard(footnote: validationNote) {
                    DetailRow(label: "Check", value: "Needs a correction", isProminent: true)
                }
            }

            CTAButton(
                title: "Save cover",
                systemImage: "plus.square.fill",
                hint: "Stores the paired cover and cue on this device",
                isEnabled: canSave
            ) {
                primaryAction()
            }

            CTAButton(
                title: "Clear draft",
                systemImage: "arrow.counterclockwise",
                emphasis: .secondary,
                hint: "Returns the form to a blank pair"
            ) {
                returnAction()
            }
        }
    }

    private var emptyBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Create cover",
                subtitle: "No situation recipes are on the device yet."
            )
            EmptyStateCard(
                title: "No recipes to lean on",
                message: "Compose a paired cover and cue from scratch, then arm one local lock.",
                systemImage: "plus.square",
                actionTitle: "Compose a cover",
                action: startBlankDraft
            )
        }
    }

    @ViewBuilder
    private var lockFields: some View {
        switch lockKind {
        case .exactTime:
            DatePicker(
                "Open after",
                selection: $thresholdDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityLabel("Exact time lock")
            DatePicker(
                "Burn at",
                selection: $burnAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityLabel("Burn time")
        case .calendarDate:
            DatePicker(
                "Open on",
                selection: $thresholdDate,
                displayedComponents: [.date]
            )
            .accessibilityLabel("Calendar date lock")
            DatePicker(
                "Burn at",
                selection: $burnAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityLabel("Burn time")
        case .localCode:
            labeledField("Local code", text: $localCode, hint: "Ordinary local content for this cover")
            DatePicker(
                "Burn at",
                selection: $burnAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityLabel("Burn time")
        case .hostConfirmedArrival:
            DetailRow(
                label: "Arrival",
                value: "Host taps confirm at the door",
                isProminent: true
            )
            DatePicker(
                "Burn at",
                selection: $burnAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityLabel("Burn time")
        }
    }

    private var canSave: Bool {
        validationMessage() == nil
    }

    private var coverSummary: String {
        let trimmed = coverText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New cover" : trimmed
    }

    private var lockFootnote: String {
        switch lockKind {
        case .exactTime:
            "Opens once the local clock passes the exact time."
        case .calendarDate:
            "Opens on the selected calendar date."
        case .localCode:
            "Opens when the host enters the ordinary local code."
        case .hostConfirmedArrival:
            "Opens when the host confirms arrival with a tap."
        }
    }

    private var now: Date {
        store.rehearsalNow ?? Date()
    }

    private var thresholdValue: Date? {
        switch lockKind {
        case .exactTime, .calendarDate:
            thresholdDate
        case .localCode, .hostConfirmedArrival:
            nil
        }
    }

    private var codeValue: String? {
        switch lockKind {
        case .localCode:
            let trimmed = localCode.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .exactTime, .calendarDate, .hostConfirmedArrival:
            return nil
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: AppMetrics.tightSpacing) {
            SectionLabel(title: title)
            TextField(title, text: text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .accessibilityLabel(title)
                .accessibilityHint(hint)
        }
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

    private func refresh() {
        availableRecipes = recipes.situationRecipes()
        if availableRecipes.isEmpty {
            viewState = .empty
            return
        }
        viewState = .loaded
        if recipeID.isEmpty, let first = availableRecipes.first {
            applyRecipe(first)
        }
        if burnAt <= thresholdDate {
            burnAt = thresholdDate.addingTimeInterval(3600)
        }
    }

    private func applyRecipe(_ recipe: SituationRecipe) {
        recipeID = recipe.id
        lockKind = recipe.suggestedLockKind
        coverText = recipe.coverPrompt
        coverSafety = recipe.momentPrompt
        cueInstruction = recipe.cuePrompt
        cueHostAction = "Perform the prepared host action."
        cueSafetyNote = "Use only the prepared local materials."
        cueSeconds = 20
        savedCardID = nil
        validationNote = nil
        recipePulse += 1
    }

    private func startBlankDraft() {
        recipeID = "recipe-custom"
        coverText = ""
        coverSafety = "Keep the walking path clear."
        cueInstruction = ""
        cueHostAction = "Perform the prepared host action."
        cueSafetyNote = "Use only the prepared local materials."
        cueSeconds = 20
        lockKind = .exactTime
        savedCardID = nil
        validationNote = nil
        viewState = .loaded
    }

    private func primaryAction() {
        if let message = validationMessage() {
            validationNote = message
            return
        }
        let current = now
        let stamp = String(Int(current.timeIntervalSince1970))
        let draft = RevealCardDraft(
            id: "draft-card-\(stamp)",
            coverLine: CoverLine(
                id: "draft-cover-\(stamp)",
                text: coverText.trimmingCharacters(in: .whitespacesAndNewlines),
                safetyContext: coverSafety.trimmingCharacters(in: .whitespacesAndNewlines),
                recipeID: recipeID,
                createdAt: current
            ),
            revealCue: RevealCue(
                id: "draft-cue-\(stamp)",
                instruction: cueInstruction.trimmingCharacters(in: .whitespacesAndNewlines),
                hostAction: cueHostAction.trimmingCharacters(in: .whitespacesAndNewlines),
                safetyNote: cueSafetyNote.trimmingCharacters(in: .whitespacesAndNewlines),
                estimatedSeconds: cueSeconds
            ),
            lock: LockConditionDraft(
                id: "draft-lock-\(stamp)",
                kind: lockKind,
                thresholdDate: thresholdValue,
                localCode: codeValue,
                burnAt: burnAt
            ),
            recipeID: recipeID
        )
        savedCardID = revealCards.createCard(draft, now: current)
        validationNote = nil
        savePulse += 1
    }

    private func secondaryAction() {
        recipePulse += 1
        recipePayload = RecipeRoutePayload(
            id: "create-recipe-sheet",
            recipeID: recipeID.isEmpty ? "recipe-kitchen" : recipeID,
            sourceTab: .create,
            suggestedLockKind: lockKind
        )
    }

    private func returnAction() {
        if availableRecipes.isEmpty {
            startBlankDraft()
        } else if let first = availableRecipes.first {
            applyRecipe(first)
        }
    }

    private func validationMessage() -> String? {
        if coverText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add a shoulder-safe cover line."
        }
        if coverSafety.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add a short safety context for the cover."
        }
        if cueInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add the paired cue instruction."
        }
        if cueHostAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add the host action that follows the cue."
        }
        if cueSafetyNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add a safety note for the cue."
        }
        if recipeID.isEmpty {
            return "Choose a situation recipe or start a blank pair."
        }
        switch lockKind {
        case .exactTime, .calendarDate:
            if burnAt <= thresholdDate {
                return "The burn time must fall after the lock opens."
            }
        case .localCode:
            if localCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Enter the ordinary local code for this cover."
            }
            if burnAt <= now {
                return "The burn time must stay in the future."
            }
        case .hostConfirmedArrival:
            if burnAt <= now {
                return "The burn time must stay in the future."
            }
        }
        return nil
    }

    private static let cueDurations = [15, 20, 30, 45]
    private static let lockChoices: [LockKind] = [
        .exactTime, .calendarDate, .localCode, .hostConfirmedArrival
    ]
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
        CreateCoverScreen(dependencies: .preview(modelContext: container.mainContext))
            .modelContainer(container)
    }
}
