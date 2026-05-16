import Foundation

enum OnboardingStep: Int, Codable, CaseIterable, Equatable {
    case name = 0
    case goal
    case plan
    case training
    case body
    case notePreview
    case recap
    case paywall
    case appleHealth
    case notifications

    static let flowSteps: [OnboardingStep] = [
        .name,
        .goal,
        .plan,
        .training,
        .body,
        .notePreview,
        .appleHealth,
        .notifications,
        .recap
    ]

    var nextStep: OnboardingStep? {
        guard let index = Self.flowSteps.firstIndex(of: self),
              index < Self.flowSteps.index(before: Self.flowSteps.endIndex)
        else { return nil }
        return Self.flowSteps[index + 1]
    }

    var previousStep: OnboardingStep? {
        guard let index = Self.flowSteps.firstIndex(of: self),
              index > Self.flowSteps.startIndex
        else { return nil }
        return Self.flowSteps[index - 1]
    }
}

struct OnboardingDraft: Codable, Equatable, Hashable {
    var firstName: String
    var step: OnboardingStep
    var updatedAt: Date

    init(
        firstName: String = "",
        step: OnboardingStep = .name,
        updatedAt: Date = .now
    ) {
        self.firstName = firstName
        self.step = step
        self.updatedAt = updatedAt
    }

    var sanitized: OnboardingDraft {
        var copy = self
        copy.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.updatedAt = .now
        return copy
    }

    var canContinueFromCurrentStep: Bool {
        switch step {
        case .name:
            !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            true
        }
    }
}
