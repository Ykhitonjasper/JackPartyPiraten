import SwiftData
import SwiftUI

enum SituationRecipesScreenViewState {
    case loaded
    case empty
}

struct SituationRecipesScreen: View {
    private let recipes: any SituationRecipeRepository
    private let payload: RecipeRoutePayload
    private let onSelect: ((SituationRecipe) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var viewState: SituationRecipesScreenViewState = .loaded
    @State private var selectedKind: LockKind?
    @State private var selectedRecipeID: String
    @State private var applyPulse = 0
    @State private var filterPulse = 0

    init(
        dependencies: AppDependencies,
        payload: RecipeRoutePayload,
        onSelect: ((SituationRecipe) -> Void)? = nil
    ) {
        recipes = dependencies.recipes
        self.payload = payload
        self.onSelect = onSelect
        _selectedRecipeID = State(initialValue: payload.recipeID)
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
        .task {
            refresh()
        }
        .sensoryFeedback(.success, trigger: applyPulse)
        .sensoryFeedback(.selection, trigger: filterPulse)
    }

    private var loadedBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Moment recipes",
                subtitle: "Browse seeded party moments and return a paired cover and cue prompt to Create."
            )

            TileGrid {
                MetricTile(
                    title: "Moments",
                    value: "\(allRecipes.count)",
                    caption: "Seeded pairings",
                    systemImage: "sparkles"
                )
                MetricTile(
                    title: "Lock",
                    value: selectedRecipe?.suggestedLockKind.label ?? payload.suggestedLockKind.label,
                    caption: "Suggested for this pairing",
                    systemImage: "lock"
                )
            }

            ChipRow {
                FilterChip(title: "All", isSelected: selectedKind == nil) {
                    selectedKind = nil
                    filterPulse += 1
                }
                ForEach(LockKind.allCases, id: \.self) { kind in
                    FilterChip(title: kind.label, isSelected: selectedKind == kind) {
                        secondaryAction(kind)
                    }
                }
            }

            if filteredRecipes.isEmpty {
                EmptyStateCard(
                    title: "No matches",
                    message: "No seeded moment uses that lock. Show every recipe to pick a pairing.",
                    systemImage: "sparkles",
                    actionTitle: "Show all moments"
                ) {
                    selectedKind = nil
                    filterPulse += 1
                }
            } else {
                ForEach(filteredRecipes) { recipe in
                    NavigationRow(
                        title: recipe.title,
                        subtitle: recipe.momentPrompt,
                        systemImage: "lightbulb",
                        trailingText: recipe.suggestedLockKind.label,
                        hint: "Reviews the paired cover and cue prompts"
                    ) {
                        selectedRecipeID = recipe.id
                        filterPulse += 1
                    }
                }
            }

            if let selectedRecipe {
                SectionCard(
                    title: selectedRecipe.title,
                    footnote: "Use this pairing to fill Create with a cover prompt and a sealed cue prompt."
                ) {
                    DetailRow(label: "Moment", value: selectedRecipe.momentPrompt, isProminent: true)
                    DetailRow(label: "Cover", value: selectedRecipe.coverPrompt)
                    DetailRow(label: "Cue", value: selectedRecipe.cuePrompt)
                    DetailRow(label: "Lock", value: selectedRecipe.suggestedLockKind.label)
                }

                CTAButton(
                    title: "Use this pairing",
                    systemImage: "arrow.uturn.backward",
                    hint: "Returns the paired prompts to Create"
                ) {
                    primaryAction()
                }
            }

            CTAButton(
                title: "Close recipes",
                emphasis: .secondary,
                hint: "Returns to Create without changing the draft"
            ) {
                returnAction()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyBody: some View {
        ScreenScaffold {
            ScreenHeader(
                title: "Moment recipes",
                subtitle: "Pair a guest-safe cover with a sealed host cue."
            )

            EmptyStateCard(
                title: "No moment recipes",
                message: "Recipes appear here so Create can reuse a paired cover and cue. Close this sheet and write the pairing by hand.",
                systemImage: "sparkles",
                actionTitle: "Close recipes"
            ) {
                returnAction()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var allRecipes: [SituationRecipe] {
        recipes.situationRecipes()
    }

    private var filteredRecipes: [SituationRecipe] {
        guard let selectedKind else { return allRecipes }
        return allRecipes.filter { $0.suggestedLockKind == selectedKind }
    }

    private var selectedRecipe: SituationRecipe? {
        recipes.situationRecipe(id: selectedRecipeID) ?? filteredRecipes.first
    }

    private func refresh() {
        viewState = allRecipes.isEmpty ? .empty : .loaded
        if recipes.situationRecipe(id: selectedRecipeID) == nil {
            selectedRecipeID = allRecipes.first?.id ?? payload.recipeID
        }
    }

    private func primaryAction() {
        guard let selectedRecipe else { return }
        applyPulse += 1
        onSelect?(selectedRecipe)
        dismiss()
    }

    private func secondaryAction(_ kind: LockKind) {
        selectedKind = kind
        filterPulse += 1
        if let match = allRecipes.first(where: { $0.suggestedLockKind == kind }) {
            selectedRecipeID = match.id
        }
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
        SituationRecipesScreen(
            dependencies: .preview(modelContext: container.mainContext),
            payload: RecipeRoutePayload(
                id: "preview-recipes",
                recipeID: "recipe-kitchen",
                sourceTab: .create,
                suggestedLockKind: .exactTime
            )
        )
        .modelContainer(container)
    }
}
