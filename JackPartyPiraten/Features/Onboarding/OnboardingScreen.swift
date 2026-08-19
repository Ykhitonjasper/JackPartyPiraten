import SwiftData
import SwiftUI

enum OnboardingScreenViewState {
    case loaded
}

struct OnboardingScreen: View {
    private let preferences: any PreferenceRepository
    private let store: AppStore

    @State private var viewState: OnboardingScreenViewState = .loaded
    @State private var pageIndex = 0
    @State private var coverDraft = ""
    @State private var acceptedCover: CoverLine?
    @State private var pagePulse = 0
    @State private var acceptPulse = 0
    @State private var completionPulse = 0

    private let pageCount = 3

    init(dependencies: AppDependencies) {
        preferences = dependencies.preferences
        store = dependencies.appStore
    }

    var body: some View {
        Group {
            switch viewState {
            case .loaded:
                loadedBody
            }
        }
        .sensoryFeedback(.selection, trigger: pagePulse)
        .sensoryFeedback(.impact(weight: .medium), trigger: acceptPulse)
        .sensoryFeedback(.success, trigger: completionPulse)
        .accessibilityIdentifier("onboarding.pages")
    }

    private var loadedBody: some View {
        ScreenScaffold(scrolls: false) {
            TabView(selection: $pageIndex) {
                welcomePage.tag(0)
                samplePage.tag(1)
                finishPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Orientation page \(pageIndex + 1) of \(pageCount)")

            footerButtons
        }
    }

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            ScreenHeader(
                title: AppTheme.displayName,
                subtitle: "Stage a guest-safe cover line while the host cue stays sealed behind a local lock."
            )

            SectionCard(
                title: "What stays visible",
                footnote: "Guests only ever see the cover. The sealed cue waits on this device until a lock opens."
            ) {
                DetailRow(label: "Cover line", value: "Public placement note", isProminent: true)
                DetailRow(label: "Sealed cue", value: "Hidden until unlock")
                DetailRow(label: "Locks", value: "Time, date, code, arrival")
            }

            TileGrid {
                MetricTile(
                    title: "Cover",
                    value: "Visible",
                    caption: "Safe to leave on a table",
                    systemImage: "eye"
                )
                MetricTile(
                    title: "Cue",
                    value: "Sealed",
                    caption: "Stays off the walking path",
                    systemImage: "lock"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to \(AppTheme.displayName). Covers stay visible; cues stay sealed.")
    }

    private var samplePage: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            ScreenHeader(
                title: "Practice a cover line",
                subtitle: "Write the sentence guests may see. This sealed sample accepts a cover line only."
            )

            SectionCard(title: "Cover line", footnote: "Keep the walking path clear and skip the host cue.") {
                TextField("Cover line guests can see", text: $coverDraft)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(AppMetrics.contentSpacing)
                    .background(AppTheme.bgBase, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                            .stroke(AppTheme.hairline, lineWidth: AppMetrics.hairlineWidth)
                    }
                    .accessibilityLabel("Cover line guests can see")
                    .accessibilityHint("Enter a public placement note. The sealed cue is not collected here.")

                CTAButton(
                    title: "Accept Cover",
                    systemImage: "checkmark.seal",
                    emphasis: .secondary,
                    hint: "Stores the cover line on this sealed sample",
                    isEnabled: canAcceptCover
                ) {
                    secondaryAction()
                }
            }

            if let acceptedCover {
                SectionCard(title: "Sealed sample", footnote: "Only the cover line is accepted. The host cue stays out of this sample.") {
                    DetailRow(label: "Cover", value: acceptedCover.text, isProminent: true)
                    DetailRow(label: "Safety", value: acceptedCover.safetyContext)
                    DetailRow(label: "Recipe", value: acceptedCover.recipeID)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Practice a cover line for the sealed sample")
    }

    private var finishPage: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            ScreenHeader(
                title: "Ready when you are",
                subtitle: "Create a cover, set a lock, then archive what opened on this device."
            )

            SectionCard(title: "Host loop") {
                DetailRow(label: "Fuses", value: "Active covers and locks", isProminent: true)
                DetailRow(label: "Create", value: "Pair a cover with a sealed cue")
                DetailRow(label: "Archive", value: "Opened and burned outcomes")
            }

            TileGrid {
                MetricTile(
                    title: "Pages",
                    value: "\(pageCount)",
                    caption: "Orientation complete after start",
                    systemImage: "square.stack"
                )
                MetricTile(
                    title: "Storage",
                    value: "Local",
                    caption: "Records stay on this device",
                    systemImage: "internaldrive"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Finish orientation and start hosting covers")
    }

    private var footerButtons: some View {
        VStack(spacing: AppMetrics.contentSpacing) {
            if pageIndex > 0 {
                CTAButton(
                    title: "Back",
                    emphasis: .secondary,
                    hint: "Returns to the previous orientation page"
                ) {
                    returnAction()
                }
            }

            if pageIndex < pageCount - 1 {
                CTAButton(
                    title: "Continue",
                    systemImage: "arrow.right",
                    hint: "Shows the next orientation page"
                ) {
                    primaryAction()
                }
            } else {
                CTAButton(
                    title: "Get Started",
                    systemImage: "play.fill",
                    hint: "Saves orientation complete and opens the host tabs"
                ) {
                    primaryAction()
                }
            }
        }
    }

    private var canAcceptCover: Bool {
        !coverDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func primaryAction() {
        if pageIndex < pageCount - 1 {
            pageIndex += 1
            pagePulse += 1
            return
        }

        let now = Date()
        preferences.setOnboardingCompleted(true, at: now)
        store.onboardingComplete = true
        completionPulse += 1
    }

    private func secondaryAction() {
        let trimmed = coverDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        acceptedCover = CoverLine(
            id: "sample-cover-line",
            text: trimmed,
            safetyContext: "Keep the walking path clear.",
            recipeID: "recipe-kitchen",
            createdAt: Date()
        )
        acceptPulse += 1
    }

    private func returnAction() {
        guard pageIndex > 0 else { return }
        pageIndex -= 1
        pagePulse += 1
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
        OnboardingScreen(dependencies: .preview(modelContext: container.mainContext))
            .modelContainer(container)
    }
}
