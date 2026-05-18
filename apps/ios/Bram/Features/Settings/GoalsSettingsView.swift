import SwiftUI
import UIKit

struct GoalsSettingsView: View {
    let profile: TrainingGoalsProfile
    let onSave: (TrainingGoalsProfile) -> Void

    var body: some View {
        BramPanelChrome(title: "Goals") {
            GoalsSettingsContent(profile: profile, onSave: onSave)
        }
    }
}

struct GoalsSettingsContent: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TrainingGoalsProfile
    @State private var heightText: String
    @State private var currentWeightText: String
    @State private var targetWeightText: String
    @State private var caloriesText: String
    let onSave: (TrainingGoalsProfile) -> Void

    init(profile: TrainingGoalsProfile, onSave: @escaping (TrainingGoalsProfile) -> Void) {
        let profile = profile.sanitized
        _draft = State(initialValue: profile)
        _heightText = State(initialValue: Self.text(for: profile.heightValue))
        _currentWeightText = State(initialValue: Self.text(for: profile.currentWeightValue))
        _targetWeightText = State(initialValue: Self.text(for: profile.targetWeightValue))
        _caloriesText = State(initialValue: profile.estimatedDailyCalories.map(String.init) ?? "")
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GoalsHeroCard(profile: draft)

            GoalsSection(title: "Focus") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(TrainingPrimaryGoal.allCases) { goal in
                        GoalsOptionButton(
                            title: goal.label,
                            systemImage: icon(for: goal),
                            isSelected: draft.primaryGoal == goal
                        ) {
                            withAnimation(.snappy) {
                                draft.primaryGoal = goal
                            }
                        }
                    }
                }
            }

            GoalsSection(title: "Plan") {
                GoalsStepperRow(
                    title: "Workout days",
                    subtitle: "Weekly target",
                    value: "\(draft.weeklyTrainingDays)/week",
                    systemImage: "calendar",
                    decrement: { draft.weeklyTrainingDays = max(1, draft.weeklyTrainingDays - 1) },
                    increment: { draft.weeklyTrainingDays = min(14, draft.weeklyTrainingDays + 1) }
                )
                GoalsDivider()
                GoalsStepperRow(
                    title: "Session length",
                    subtitle: "Typical workout",
                    value: "\(draft.sessionLengthMinutes) min",
                    systemImage: "clock",
                    decrement: { draft.sessionLengthMinutes = max(10, draft.sessionLengthMinutes - 5) },
                    increment: { draft.sessionLengthMinutes = min(240, draft.sessionLengthMinutes + 5) }
                )
            }

            GoalsSection(title: "Training") {
                GoalsChipGroup(title: "Style", items: TrainingStyle.allCases, selected: $draft.trainingStyles) { $0.label }
                GoalsDivider()
                GoalsChipGroup(title: "Equipment", items: EquipmentContext.allCases, selected: $draft.equipment) { $0.label }
            }

            GoalsSection(title: "Body") {
                Picker("Units", selection: $draft.preferredUnits) {
                    ForEach(MeasurementUnitPreference.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                GoalsDivider()
                GoalsTextField(title: heightTitle, text: $heightText, keyboardType: .decimalPad)
                GoalsTextField(title: "Current weight", detail: currentWeightDetail, text: $currentWeightText, keyboardType: .decimalPad)
                GoalsTextField(title: "Target weight", detail: draft.preferredUnits.weightUnit, text: $targetWeightText, keyboardType: .decimalPad)

                GoalsDivider()
                GoalsSexSelector(selection: $draft.sex)

                if draft.sex == .selfDescribe {
                    GoalsTextField(title: "Self-description", text: $draft.sexSelfDescription, keyboardType: .default)
                }
            }

            GoalsSection(title: "Optional") {
                GoalsTextField(title: "Daily calories", detail: "future context", text: $caloriesText, keyboardType: .numberPad)
                Text("Bram can use this later for goal framing. It stays private account data.")
                    .font(BramFont.callout(size: 12))
                    .foregroundStyle(BramColor.textTertiary)
            }

            Button(action: save) {
                Text("Done")
                    .font(BramFont.button())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BramColor.violet, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private var heightTitle: String {
        switch draft.preferredUnits {
        case .imperial: "Height"
        case .metric: "Height"
        }
    }

    private var currentWeightDetail: String {
        if let source = draft.currentWeightSource {
            return "\(draft.preferredUnits.weightUnit) · \(source.label)"
        }
        return draft.preferredUnits.weightUnit
    }

    private func icon(for goal: TrainingPrimaryGoal) -> String {
        switch goal {
        case .stronger: "bolt.fill"
        case .buildMuscle: "dumbbell.fill"
        case .leaner: "flame.fill"
        case .betterCardio: "heart.fill"
        case .healthyRoutine: "leaf.fill"
        case .maintain: "equal.circle.fill"
        }
    }

    private func save() {
        draft.heightValue = Double(heightText)
        let previousWeight = draft.currentWeightValue
        draft.currentWeightValue = Double(currentWeightText)
        if draft.currentWeightValue != previousWeight {
            draft.currentWeightLoggedAt = .now
            draft.currentWeightSource = .manual
        }
        draft.targetWeightValue = Double(targetWeightText)
        draft.estimatedDailyCalories = Int(caloriesText)
        onSave(draft.sanitized)
        dismiss()
    }

    private static func text(for value: Double?) -> String {
        guard let value else { return "" }
        return value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

private struct GoalsHeroCard: View {
    let profile: TrainingGoalsProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.primaryGoal.shortLabel)
                        .font(BramFont.largeTitle(size: 28))
                        .foregroundStyle(BramColor.textPrimary)
                    Text("Bram uses this to frame progress, streaks, and suggestions.")
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "target")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(BramColor.violet)
                    .frame(width: 42, height: 42)
                    .background(BramColor.violet.opacity(0.12), in: Circle())
            }

            HStack(spacing: 10) {
                GoalsHeroMetric(value: "\(profile.weeklyTrainingDays)x", label: "weekly")
                GoalsHeroMetric(value: "\(profile.sessionLengthMinutes)", label: "min")
                GoalsHeroMetric(value: weightText, label: "current")
            }
        }
        .padding(18)
        .background(BramColor.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BramColor.hairline, lineWidth: 1)
        }
    }

    private var weightText: String {
        guard let weight = profile.currentWeightValue else { return "--" }
        let value = weight.rounded() == weight ? "\(Int(weight))" : String(format: "%.1f", weight)
        return value
    }
}

private struct GoalsHeroMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(BramFont.headline(size: 18))
                .foregroundStyle(BramColor.textPrimary)
            Text(label)
                .font(BramFont.label(size: 11))
                .foregroundStyle(BramColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BramColor.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct GoalsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.textTertiary)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(16)
            .background(BramColor.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(BramColor.hairline, lineWidth: 1)
            }
        }
    }
}

private struct GoalsOptionButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "checkmark" : systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : BramColor.violet)
                    .frame(width: 16)
                Text(title)
                    .font(BramFont.label(size: 13))
                    .foregroundStyle(isSelected ? .white : BramColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(isSelected ? BramColor.violet : BramColor.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? BramColor.violet.opacity(0.1) : BramColor.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct GoalsStepperRow: View {
    let title: String
    let subtitle: String
    let value: String
    let systemImage: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BramColor.violet)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BramFont.label())
                    .foregroundStyle(BramColor.textPrimary)
                Text(subtitle)
                    .font(BramFont.callout(size: 12))
                    .foregroundStyle(BramColor.textTertiary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: decrement) {
                    Image(systemName: "minus")
                }
                .accessibilityLabel("Decrease \(title)")
                Text(value)
                    .font(BramFont.label())
                    .foregroundStyle(BramColor.textPrimary)
                    .frame(minWidth: 58)
                Button(action: increment) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Increase \(title)")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(BramColor.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

private struct GoalsTextField: View {
    let title: String
    var detail: String? = nil
    @Binding var text: String
    let keyboardType: UIKeyboardType

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BramFont.label())
                    .foregroundStyle(BramColor.textPrimary)
                if let detail {
                    Text(detail)
                        .font(BramFont.callout(size: 12))
                        .foregroundStyle(BramColor.textTertiary)
                }
            }
            Spacer()
            TextField("-", text: $text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .font(BramFont.body(size: 16))
                .foregroundStyle(BramColor.textPrimary)
                .tint(BramColor.violet)
                .frame(maxWidth: 120)
        }
    }
}

private struct GoalsSexSelector: View {
    @Binding var selection: BodySex?

    private var options: [(id: String, label: String, value: BodySex?)] {
        [("not_set", "Not set", nil)] + BodySex.allCases.map { ($0.id, $0.label, Optional($0)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sex")
                .font(BramFont.label(size: 13))
                .foregroundStyle(BramColor.textSecondary)

            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(options, id: \.id) { option in
                    Button {
                        withAnimation(.snappy) {
                            selection = option.value
                        }
                    } label: {
                        HStack(spacing: 7) {
                            if isSelected(option.value) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text(option.label)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .font(BramFont.label(size: 13))
                        .foregroundStyle(isSelected(option.value) ? .white : BramColor.textPrimary)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(isSelected(option.value) ? BramColor.violet : BramColor.elevated, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(isSelected(option.value) ? BramColor.violet.opacity(0.1) : BramColor.hairline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                    .accessibilityAddTraits(isSelected(option.value) ? .isSelected : [])
                }
            }
        }
    }

    private func isSelected(_ value: BodySex?) -> Bool {
        selection == value
    }
}

private struct GoalsChipGroup<Item: Identifiable & Hashable>: View {
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
                        toggle(item)
                    } label: {
                        Text(label(item))
                            .font(BramFont.label(size: 13))
                            .foregroundStyle(selected.contains(item) ? .white : BramColor.textPrimary)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(selected.contains(item) ? BramColor.violet : BramColor.elevated, in: Capsule())
                            .overlay {
                                Capsule().stroke(BramColor.hairline, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggle(_ item: Item) {
        if selected.contains(item) {
            selected.remove(item)
        } else {
            selected.insert(item)
        }
    }
}

private struct GoalsDivider: View {
    var body: some View {
        Rectangle()
            .fill(BramColor.hairline)
            .frame(height: 1)
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

#Preview {
    GoalsSettingsView(profile: BramPreviewData.goalsProfile, onSave: { _ in })
        .preferredColorScheme(.dark)
}
