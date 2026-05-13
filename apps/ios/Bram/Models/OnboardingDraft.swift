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
