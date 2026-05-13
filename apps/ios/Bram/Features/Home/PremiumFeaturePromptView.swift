import SwiftUI

struct PremiumFeaturePromptView: View {
    let feature: String

    var body: some View {
        BramPanelChrome(title: feature) {
            PremiumFeaturePromptContent(feature: feature)
        }
    }
}

struct PremiumFeaturePromptContent: View {
    let feature: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(BramColor.violet)

            Text("Keep writing for free.")
                .font(BramFont.headline())
                .foregroundStyle(BramColor.textPrimary)

            Text("Stats, Apple Health, progress insights, and suggestions unlock with Bram Premium after onboarding.")
                .font(BramFont.callout())
                .foregroundStyle(BramColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    PremiumFeaturePromptView(feature: "Workout stats")
}
