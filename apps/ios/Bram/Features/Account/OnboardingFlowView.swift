import SwiftUI

struct OnboardingFlowView: View {
    let account: SettingsAccountState
    let initialDraft: OnboardingDraft
    let initialProfile: TrainingGoalsProfile
    let saveProgress: (OnboardingDraft, TrainingGoalsProfile) async -> Void
    let complete: (String, TrainingGoalsProfile) async -> Void
    let signOut: () async -> Void

    @State private var draft: OnboardingDraft
    @State private var profile: TrainingGoalsProfile
    @State private var currentWeightText: String
    @State private var targetWeightText: String

    init(
        account: SettingsAccountState,
        initialDraft: OnboardingDraft,
        initialProfile: TrainingGoalsProfile,
        saveProgress: @escaping (OnboardingDraft, TrainingGoalsProfile) async -> Void,
        complete: @escaping (String, TrainingGoalsProfile) async -> Void,
        signOut: @escaping () async -> Void
    ) {
        self.account = account
        self.initialDraft = initialDraft
        self.initialProfile = initialProfile
        self.saveProgress = saveProgress
        self.complete = complete
        self.signOut = signOut
        var resumableDraft = initialDraft
        if resumableDraft.step == .paywall {
            resumableDraft.step = .recap
        }
        _draft = State(initialValue: resumableDraft)
        _profile = State(initialValue: initialProfile.sanitized)
        _currentWeightText = State(initialValue: Self.text(for: initialProfile.currentWeightValue))
        _targetWeightText = State(initialValue: Self.text(for: initialProfile.targetWeightValue))
    }

    var body: some View {
        ZStack {
            BramColor.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                TabView(selection: $draft.step) {
                    nameStep.tag(OnboardingStep.name)
                    goalStep.tag(OnboardingStep.goal)
                    planStep.tag(OnboardingStep.plan)
                    trainingStep.tag(OnboardingStep.training)
                    bodyStep.tag(OnboardingStep.body)
                    notePreviewStep.tag(OnboardingStep.notePreview)
                    recapStep.tag(OnboardingStep.recap)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy, value: draft.step)

                footer
            }
        }
    }

    private var header: some View {
        HStack {
            BramLogoMark(size: 34)
            Spacer()
            Button("Sign out") {
                Task { await signOut() }
            }
            .font(BramFont.label(size: 13))
            .foregroundStyle(BramColor.textTertiary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
                .tint(BramColor.violet)

            BramCapsuleButton(action: {
                Task { await continueTapped() }
            }) {
                Text(draft.step == .recap ? "Continue to Bram Premium" : "Continue")
            }
            .disabled(!draft.canContinueFromCurrentStep)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
        .background(.thinMaterial)
    }

    private var progress: Double {
        Double(draft.step.rawValue + 1) / Double(OnboardingStep.paywall.rawValue)
    }

    private var nameStep: some View {
        OnboardingStepShell(
            eyebrow: "Your baseline",
            title: "What should Bram call you?",
            subtitle: "This keeps the app feeling personal without collecting more than we need."
        ) {
            TextField("First name", text: $draft.firstName)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .font(BramFont.headline(size: 22))
                .foregroundStyle(BramColor.textPrimary)
                .padding(18)
                .background(BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BramColor.hairline, lineWidth: 1)
                }
        }
    }

    private var goalStep: some View {
        OnboardingStepShell(
            eyebrow: "Training focus",
            title: "What are you training for?",
            subtitle: "Bram uses this to frame progress and streaks around what matters to you."
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(TrainingPrimaryGoal.allCases) { goal in
                    OnboardingChoiceButton(
                        title: goal.label,
                        isSelected: profile.primaryGoal == goal
                    ) {
                        profile.primaryGoal = goal
                    }
                }
            }
        }
    }

    private var planStep: some View {
        OnboardingStepShell(
            eyebrow: "Weekly rhythm",
            title: "What does a good week look like?",
            subtitle: "Pick a target that feels repeatable. You can change this any time."
        ) {
            OnboardingStepper(title: "Workout days", value: "\(profile.weeklyTrainingDays)x / week") {
                profile.weeklyTrainingDays = max(1, profile.weeklyTrainingDays - 1)
            } increment: {
                profile.weeklyTrainingDays = min(14, profile.weeklyTrainingDays + 1)
            }
            OnboardingStepper(title: "Typical session", value: "\(profile.sessionLengthMinutes) min") {
                profile.sessionLengthMinutes = max(10, profile.sessionLengthMinutes - 5)
            } increment: {
                profile.sessionLengthMinutes = min(240, profile.sessionLengthMinutes + 5)
            }
        }
    }

    private var trainingStep: some View {
        OnboardingStepShell(
            eyebrow: "Setup",
            title: "Where do you usually train?",
            subtitle: "This helps Bram keep future suggestions realistic."
        ) {
            OnboardingChipGroup(title: "Style", items: TrainingStyle.allCases, selected: $profile.trainingStyles) { $0.label }
            OnboardingChipGroup(title: "Equipment", items: EquipmentContext.allCases, selected: $profile.equipment) { $0.label }
        }
    }

    private var bodyStep: some View {
        OnboardingStepShell(
            eyebrow: "Body baseline",
            title: "Set a simple starting point.",
            subtitle: "These stay private account fields and help Bram make progress feel grounded."
        ) {
            Picker("Units", selection: $profile.preferredUnits) {
                ForEach(MeasurementUnitPreference.allCases) { unit in
                    Text(unit.label).tag(unit)
                }
            }
            .pickerStyle(.segmented)

            OnboardingNumberField(title: "Current weight", detail: profile.preferredUnits.weightUnit, text: $currentWeightText)
            OnboardingNumberField(title: "Target weight", detail: profile.preferredUnits.weightUnit, text: $targetWeightText)
        }
    }

    private var notePreviewStep: some View {
        OnboardingStepShell(
            eyebrow: "The Bram moment",
            title: "Write naturally. Bram keeps score.",
            subtitle: "A note like this becomes sets, volume, PRs, and cardio without you tapping through forms."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bench 185 3x8\nRun 1 mile\nBodyweight 190")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(BramColor.textPrimary)
                HStack(spacing: 8) {
                    OnboardingPreviewPill("3 sets")
                    OnboardingPreviewPill("4,440 lb")
                    OnboardingPreviewPill("1 mi")
                }
            }
            .padding(18)
            .background(BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var recapStep: some View {
        OnboardingStepShell(
            eyebrow: "Ready",
            title: "\(draft.firstName.nilIfBlank ?? "You"), your baseline is set.",
            subtitle: "Bram is ready to turn workout notes into a progress system you can keep using."
        ) {
            VStack(spacing: 10) {
                OnboardingRecapRow(title: "Goal", value: profile.primaryGoal.shortLabel)
                OnboardingRecapRow(title: "Weekly target", value: "\(profile.weeklyTrainingDays)x")
                OnboardingRecapRow(title: "Typical session", value: "\(profile.sessionLengthMinutes) min")
                OnboardingRecapRow(title: "Training", value: profile.trainingStyles.first?.label ?? "Flexible")
            }
        }
    }

    private func continueTapped() async {
        syncTextFields()
        if draft.step == .recap {
            await saveProgress(OnboardingDraft(firstName: draft.firstName, step: .paywall), profile)
            await complete(draft.firstName, profile)
            return
        }

        guard let next = OnboardingStep(rawValue: draft.step.rawValue + 1) else { return }
        draft.step = next
        await saveProgress(draft, profile)
    }

    private func syncTextFields() {
        let previousWeight = profile.currentWeightValue
        profile.currentWeightValue = Double(currentWeightText)
        if profile.currentWeightValue != previousWeight {
            profile.currentWeightLoggedAt = .now
            profile.currentWeightSource = .manual
        }
        profile.targetWeightValue = Double(targetWeightText)
    }

    private static func text(for value: Double?) -> String {
        guard let value else { return "" }
        return value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

private struct OnboardingStepShell<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let content: Content

    init(eyebrow: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Spacer(minLength: 26)
                Text(eyebrow.uppercased())
                    .font(BramFont.label(size: 12))
                    .foregroundStyle(BramColor.violet)
                Text(title)
                    .font(BramFont.largeTitle(size: 38))
                    .foregroundStyle(BramColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(BramFont.body(size: 17))
                    .foregroundStyle(BramColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                content
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct OnboardingChoiceButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BramFont.label(size: 14))
                .foregroundStyle(isSelected ? .white : BramColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(isSelected ? BramColor.violet : BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? BramColor.violet : BramColor.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingStepper: View {
    let title: String
    let value: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(BramFont.label())
                .foregroundStyle(BramColor.textPrimary)
            Spacer()
            Button(action: decrement) { Image(systemName: "minus") }
            Text(value)
                .font(BramFont.label())
                .frame(minWidth: 88)
            Button(action: increment) { Image(systemName: "plus") }
        }
        .font(.system(size: 15, weight: .semibold))
        .padding(16)
        .background(BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .buttonStyle(.plain)
    }
}

private struct OnboardingNumberField: View {
    let title: String
    let detail: String
    @Binding var text: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BramFont.label())
                Text(detail)
                    .font(BramFont.callout(size: 12))
                    .foregroundStyle(BramColor.textTertiary)
            }
            Spacer()
            TextField("-", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(BramFont.headline(size: 18))
                .frame(maxWidth: 120)
        }
        .padding(16)
        .background(BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct OnboardingChipGroup<Item: Identifiable & Hashable>: View {
    let title: String
    let items: [Item]
    @Binding var selected: Set<Item>
    let label: (Item) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(BramFont.label(size: 13))
                .foregroundStyle(BramColor.textSecondary)
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(items) { item in
                    Button {
                        if selected.contains(item) {
                            selected.remove(item)
                        } else {
                            selected.insert(item)
                        }
                    } label: {
                        Text(label(item))
                            .font(BramFont.label(size: 13))
                            .foregroundStyle(selected.contains(item) ? .white : BramColor.textPrimary)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(selected.contains(item) ? BramColor.violet : BramColor.cardSurface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct OnboardingPreviewPill: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(BramFont.label(size: 12))
            .foregroundStyle(BramColor.violet)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(BramColor.violet.opacity(0.12), in: Capsule())
    }
}

private struct OnboardingRecapRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(BramColor.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(BramColor.textPrimary)
        }
        .font(BramFont.label())
        .padding(16)
        .background(BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.width ?? 320, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for item in layout(in: bounds.width, subviews: subviews).items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, items: [(index: Int, origin: CGPoint)]) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var items: [(Int, CGPoint)] = []

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            items.append((index, CGPoint(x: x, y: y)))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: width, height: y + rowHeight), items)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
