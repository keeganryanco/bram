import SwiftUI

struct OnboardingFlowView: View {
    let account: SettingsAccountState
    let initialDraft: OnboardingDraft
    let initialProfile: TrainingGoalsProfile
    let saveProgress: (OnboardingDraft, TrainingGoalsProfile) async -> Void
    let complete: (String, TrainingGoalsProfile) async -> Void
    let signOut: () async -> Void
    let requestHealthAccess: () async -> Void
    let requestNotificationAccess: () async -> Void
    let trackStepViewed: (OnboardingStep) -> Void
    let trackStepCompleted: (OnboardingStep, TrainingGoalsProfile) -> Void

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
        signOut: @escaping () async -> Void,
        requestHealthAccess: @escaping () async -> Void = {},
        requestNotificationAccess: @escaping () async -> Void = {},
        trackStepViewed: @escaping (OnboardingStep) -> Void = { _ in },
        trackStepCompleted: @escaping (OnboardingStep, TrainingGoalsProfile) -> Void = { _, _ in }
    ) {
        self.account = account
        self.initialDraft = initialDraft
        self.initialProfile = initialProfile
        self.saveProgress = saveProgress
        self.complete = complete
        self.signOut = signOut
        self.requestHealthAccess = requestHealthAccess
        self.requestNotificationAccess = requestNotificationAccess
        self.trackStepViewed = trackStepViewed
        self.trackStepCompleted = trackStepCompleted
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
            OnboardingStyle.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                currentStep
                    .id(draft.step)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .animation(.snappy, value: draft.step)

                footer
            }
        }
        .task(id: draft.step) {
            trackStepViewed(draft.step)
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        switch draft.step {
        case .name:
            nameStep
        case .goal:
            goalStep
        case .plan:
            planStep
        case .training:
            trainingStep
        case .body:
            bodyStep
        case .notePreview:
            notePreviewStep
        case .appleHealth:
            appleHealthStep
        case .notifications:
            notificationsStep
        case .recap, .paywall:
            recapStep
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                Task { await backTapped() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(BramFont.label(size: 14))
                    Text("Back")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                    .font(BramFont.label(size: 15))
                    .foregroundStyle(draft.step == .name ? OnboardingStyle.textTertiary : OnboardingStyle.textPrimary)
                    .padding(.horizontal, 13)
                    .frame(minWidth: 88, minHeight: 44)
                    .background(OnboardingStyle.cardSurfaceStrong, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(draft.step == .name)
            .opacity(draft.step == .name ? 0.42 : 1)
            .layoutPriority(2)
            .accessibilityLabel("Back")

            OnboardingProgressDots(step: draft.step)
                .layoutPriority(1)

            Spacer()

            Button("Sign out") {
                Task { await signOut() }
            }
            .font(BramFont.label(size: 13))
            .foregroundStyle(OnboardingStyle.textTertiary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task { await continueTapped() }
            } label: {
                Text("Continue")
                    .font(BramFont.button(size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(BramColor.violet, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: BramColor.violet.opacity(0.30), radius: 22, y: 12)
            }
            .buttonStyle(.plain)
            .disabled(!draft.canContinueFromCurrentStep)
            .opacity(draft.canContinueFromCurrentStep ? 1 : 0.48)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
        .padding(.top, 14)
        .background(
            LinearGradient(
                colors: [OnboardingStyle.background.opacity(0), OnboardingStyle.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var nameStep: some View {
        OnboardingStepShell(
            title: "What should Bram call you?",
            mascotImageName: "BramBearFirstName",
            mascotSize: 150
        ) {
            TextField("First name", text: $draft.firstName)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .font(BramFont.headline(size: 22))
                .foregroundStyle(OnboardingStyle.textPrimary)
                .padding(18)
                .background(OnboardingStyle.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(OnboardingStyle.hairline, lineWidth: 1)
                }
        }
    }

    private var goalStep: some View {
        OnboardingStepShell(
            title: "What are you training for?",
            mascotImageName: "BramBearGoal",
            mascotSize: 150
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
            title: "What does a good week look like?",
            mascotImageName: "BramBearWeeklyRhythm",
            mascotSize: 150
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
            title: "Where do you usually train?",
            mascotImageName: "BramBearTrainingSetup",
            mascotSize: 136
        ) {
            OnboardingChipGroup(title: "Style", items: TrainingStyle.allCases, selected: $profile.trainingStyles) { $0.label }
            OnboardingChipGroup(title: "Equipment", items: EquipmentContext.allCases, selected: $profile.equipment) { $0.label }
        }
    }

    private var bodyStep: some View {
        OnboardingStepShell(
            title: "Set a simple starting point.",
            mascotImageName: "BramBearBodyBaseline",
            mascotSize: 142
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
            title: "Write naturally. Bram keeps score.",
            subtitle: "A note like this becomes sets, volume, PRs, and cardio.",
            mascotSize: 126
        ) {
            AnimatedNotePreview()
        }
    }

    private var appleHealthStep: some View {
        OnboardingStepShell(
            title: "Connect Apple Health for better context.",
            mascotImageName: "BramBearTrainingSetup",
            mascotSize: 136
        ) {
            OnboardingPermissionCard(
                systemImage: "heart.fill",
                title: "Energy, heart rate, and bodyweight",
                detail: "Bram can connect saved workouts to progress without extra logging."
            )
        }
    }

    private var notificationsStep: some View {
        OnboardingStepShell(
            title: "Let Bram remind you at the right time.",
            mascotImageName: "BramBearWeeklyRhythm",
            mascotSize: 136
        ) {
            OnboardingPermissionCard(
                systemImage: "bell.fill",
                title: "Workout reminders",
                detail: "A simple nudge after your usual training rhythm helps keep the habit going."
            )
        }
    }

    private var recapStep: some View {
        OnboardingStepShell(
            title: "\(draft.firstName.nilIfBlank ?? "You"), your baseline is set.",
            mascotSize: 142
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
        trackStepCompleted(draft.step, profile.sanitized)
        if draft.step == .appleHealth {
            await requestHealthAccess()
        } else if draft.step == .notifications {
            await requestNotificationAccess()
        }
        if draft.step == .recap {
            await saveProgress(OnboardingDraft(firstName: draft.firstName, step: .paywall), profile)
            await complete(draft.firstName, profile)
            return
        }

        guard let next = draft.step.nextStep else { return }
        draft.step = next
        await saveProgress(draft, profile)
    }

    private func backTapped() async {
        syncTextFields()
        guard let previous = draft.step.previousStep else { return }
        draft.step = previous
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
    let title: String
    let subtitle: String?
    let mascotImageName: String?
    let mascotSize: CGFloat
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        mascotImageName: String? = nil,
        mascotSize: CGFloat = 150,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.mascotImageName = mascotImageName
        self.mascotSize = mascotSize
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 18) {
                OnboardingMascotStage(imageName: mascotImageName, size: mascotSize)
                    .frame(maxWidth: .infinity)
                    .frame(height: min(max(geometry.size.height * 0.30, 128), 182))
                Text(title)
                    .font(BramFont.largeTitle(size: 34))
                    .foregroundStyle(OnboardingStyle.textPrimary)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(BramFont.body(size: 16))
                        .foregroundStyle(OnboardingStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct OnboardingMascotStage: View {
    let imageName: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .accessibilityHidden(true)
            } else {
                BramLogoMark(size: size)
                    .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingProgressDots: View {
    let step: OnboardingStep

    private var visibleSteps: [OnboardingStep] {
        OnboardingStep.flowSteps
    }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(visibleSteps, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? BramColor.violet : BramColor.violet.opacity(0.28))
                    .frame(width: item == step ? 34 : 8, height: 8)
            }
        }
        .animation(.snappy, value: step)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\((visibleSteps.firstIndex(of: step) ?? 0) + 1) of \(visibleSteps.count)")
    }
}

private struct OnboardingPermissionCard: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(BramColor.violet, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BramFont.label(size: 15))
                    .foregroundStyle(OnboardingStyle.textPrimary)
                Text(detail)
                    .font(BramFont.callout(size: 13))
                    .foregroundStyle(OnboardingStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(OnboardingStyle.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingStyle.hairline, lineWidth: 1)
        }
    }
}

private struct OnboardingChoiceButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
            }
            .font(BramFont.label(size: 14))
            .foregroundStyle(isSelected ? .white : OnboardingStyle.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isSelected ? BramColor.violet : OnboardingStyle.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? BramColor.violet : OnboardingStyle.hairline, lineWidth: 1)
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
                .foregroundStyle(OnboardingStyle.textPrimary)
            Spacer()
            Button(action: decrement) { Image(systemName: "minus") }
                .accessibilityLabel("Decrease \(title)")
            Text(value)
                .font(BramFont.label())
                .frame(minWidth: 88)
            Button(action: increment) { Image(systemName: "plus") }
                .accessibilityLabel("Increase \(title)")
        }
        .font(.system(size: 15, weight: .semibold))
        .padding(16)
        .foregroundStyle(OnboardingStyle.textPrimary)
        .background(OnboardingStyle.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    .foregroundStyle(OnboardingStyle.textPrimary)
                Text(detail)
                    .font(BramFont.callout(size: 12))
                    .foregroundStyle(OnboardingStyle.textTertiary)
            }
            Spacer()
            TextField("-", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(BramFont.headline(size: 18))
                .foregroundStyle(OnboardingStyle.textPrimary)
                .frame(maxWidth: 120)
        }
        .padding(16)
        .background(OnboardingStyle.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .foregroundStyle(OnboardingStyle.textSecondary)
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(items) { item in
                    Button {
                        if selected.contains(item) {
                            selected.remove(item)
                        } else {
                            selected.insert(item)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if selected.contains(item) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text(label(item))
                        }
                            .font(BramFont.label(size: 13))
                            .foregroundStyle(selected.contains(item) ? .white : OnboardingStyle.textPrimary)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(selected.contains(item) ? BramColor.violet : OnboardingStyle.cardSurface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AnimatedNotePreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let note = "Bench 185 3x8\nRun 1 mile\nBodyweight 190"

    @State private var visibleCharacters = 0
    @State private var showStats = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(note.prefix(visibleCharacters)))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(OnboardingStyle.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)

            HStack(spacing: 8) {
                OnboardingPreviewPill("3 sets")
                OnboardingPreviewPill("4,440 lb")
                OnboardingPreviewPill("1 mi")
            }
            .opacity(showStats ? 1 : 0)
            .offset(y: showStats ? 0 : 10)
            .animation(.snappy.delay(0.08), value: showStats)
        }
        .padding(18)
        .background(OnboardingStyle.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingStyle.hairline, lineWidth: 1)
        }
        .task {
            if reduceMotion {
                visibleCharacters = note.count
                showStats = true
            } else {
                await runAnimation()
            }
        }
    }

    private func runAnimation() async {
        visibleCharacters = 0
        showStats = false

        for index in 1...note.count {
            try? await Task.sleep(for: .milliseconds(index % 11 == 0 ? 120 : 32))
            visibleCharacters = index
        }

        try? await Task.sleep(for: .milliseconds(160))
        showStats = true
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
                .foregroundStyle(OnboardingStyle.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(OnboardingStyle.textPrimary)
        }
        .font(BramFont.label())
        .padding(16)
        .background(OnboardingStyle.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
