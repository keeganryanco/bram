import SwiftUI

struct SettingsView: View {
    let account: SettingsAccountState

    var body: some View {
        BramPanelChrome(title: "Settings") {
            SettingsSection(title: "Account") {
                SettingsInfoRow(title: "Name", value: account.displayName)
                SettingsInfoRow(title: "Email", value: account.email)
                SettingsLinkRow(title: account.subscriptionLabel, subtitle: subscriptionSubtitle, systemImage: "crown.fill", tint: BramColor.warning)
            }

            SettingsSection(title: "Training") {
                SettingsLinkRow(title: "Goals and split", subtitle: "Hypertrophy, 4 days/week", systemImage: "target", tint: BramColor.violet)
                SettingsLinkRow(title: "Health profile", subtitle: "\(account.preferredUnits), bodyweight later", systemImage: "figure.strengthtraining.traditional", tint: BramColor.energy)
                SettingsToggleRow(title: "Apple Health", subtitle: "Recovery and bodyweight sync", systemImage: "heart.fill", tint: BramColor.recovery, isOn: account.appleHealthConnected)
            }

            SettingsSection(title: "Preferences") {
                SettingsInfoRow(title: "Appearance", value: account.appearance)
                SettingsToggleRow(title: "Developer mode", subtitle: "Visible when account entitlement allows it", systemImage: "hammer.fill", tint: BramColor.cool, isOn: account.isDeveloper)
            }

            SettingsSection(title: "Support") {
                SettingsExternalLink(title: "Contact Support", systemImage: "envelope.fill", url: URL(string: "mailto:support@trybram.app")!)
                SettingsExternalLink(title: "Privacy Policy", systemImage: "lock.fill", url: URL(string: "https://trybram.app/privacy")!)
                SettingsExternalLink(title: "Terms", systemImage: "doc.text.fill", url: URL(string: "https://trybram.app/terms")!)
                SettingsDestructiveRow(title: "Delete Account", systemImage: "person.crop.circle.badge.xmark")
            }
        }
    }

    private var subscriptionSubtitle: String {
        if account.founderOfferEligible {
            "Founder offer eligible"
        } else {
            "Manage through App Store"
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(BramFont.label(size: 13))
                .foregroundStyle(BramColor.textTertiary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(BramColor.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(BramColor.hairline, lineWidth: 1)
            }
        }
    }
}

private struct SettingsInfoRow: View {
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
        .font(BramFont.body(size: 15))
        .padding(16)
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BramFont.label())
                    .foregroundStyle(BramColor.textPrimary)
                Text(subtitle)
                    .font(BramFont.callout(size: 12))
                    .foregroundStyle(BramColor.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BramColor.textTertiary)
        }
        .padding(16)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BramFont.label())
                    .foregroundStyle(BramColor.textPrimary)
                Text(subtitle)
                    .font(BramFont.callout(size: 12))
                    .foregroundStyle(BramColor.textTertiary)
            }
            Spacer()
            Toggle("", isOn: .constant(isOn))
                .labelsHidden()
                .tint(BramColor.violet)
                .disabled(true)
        }
        .padding(16)
    }
}

private struct SettingsExternalLink: View {
    let title: String
    let systemImage: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(BramColor.cool)
                    .frame(width: 24)
                Text(title)
                    .font(BramFont.label())
                    .foregroundStyle(BramColor.textPrimary)
                Spacer()
            }
            .padding(16)
        }
    }
}

private struct SettingsDestructiveRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
            Text(title)
                .font(BramFont.label())
            Spacer()
        }
        .foregroundStyle(.red)
        .padding(16)
    }
}

#Preview {
    SettingsView(account: BramPreviewData.account)
        .preferredColorScheme(.dark)
}
