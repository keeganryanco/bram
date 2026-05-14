import SwiftUI

struct SettingsView: View {
    let account: SettingsAccountState
    let goalsProfile: TrainingGoalsProfile
    let healthConnected: Bool
    let note: DailyWorkoutNote
    let noteStore: any WorkoutLocalStore
    let canUseHealth: Bool
    let onGoalsSave: (TrainingGoalsProfile) -> Void
    let onSignOut: () async -> Void
    let onDeleteAccount: () async -> Void
    let onHealthUpdated: () -> Void
    let openGoals: () -> Void
    let openHealth: () -> Void
    @State private var showingDeleteConfirmation = false

    init(
        account: SettingsAccountState,
        goalsProfile: TrainingGoalsProfile = BramPreviewData.goalsProfile,
        healthConnected: Bool = false,
        note: DailyWorkoutNote = BramPreviewData.populatedNote,
        noteStore: any WorkoutLocalStore = SQLiteWorkoutLocalStore.shared,
        canUseHealth: Bool = true,
        onGoalsSave: @escaping (TrainingGoalsProfile) -> Void = { _ in },
        onSignOut: @escaping () async -> Void = {},
        onDeleteAccount: @escaping () async -> Void = {},
        onHealthUpdated: @escaping () -> Void = {},
        openGoals: @escaping () -> Void = {},
        openHealth: @escaping () -> Void = {}
    ) {
        self.account = account
        self.goalsProfile = goalsProfile
        self.healthConnected = healthConnected
        self.note = note
        self.noteStore = noteStore
        self.canUseHealth = canUseHealth
        self.onGoalsSave = onGoalsSave
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
        self.onHealthUpdated = onHealthUpdated
        self.openGoals = openGoals
        self.openHealth = openHealth
    }

    var body: some View {
        BramPanelChrome(title: "Settings") {
            SettingsSection(title: "Account") {
                SettingsInfoRow(title: "Name", value: account.displayName)
                SettingsInfoRow(title: "Email", value: account.email)
                SettingsLinkRow(title: account.subscriptionLabel, subtitle: subscriptionSubtitle, systemImage: "crown.fill", tint: BramColor.warning)
            }

            SettingsSection(title: "Training") {
                SettingsNavigationRow(
                    title: "Goals",
                    subtitle: goalsProfile.settingsSubtitle,
                    systemImage: "target",
                    tint: BramColor.violet
                ) {
                    SettingsDestinationScroll {
                        GoalsSettingsContent(profile: goalsProfile, onSave: onGoalsSave)
                    }
                    .navigationTitle("Goals")
                    .navigationBarTitleDisplayMode(.inline)
                }
                SettingsNavigationRow(
                    title: "Apple Health",
                    subtitle: healthConnected || account.appleHealthConnected ? "Connected for progress stats" : "Energy, heart rate, and bodyweight",
                    systemImage: "heart.fill",
                    tint: BramColor.recovery
                ) {
                    if canUseHealth {
                        SettingsDestinationScroll {
                            HealthConnectionContent(
                                note: note,
                                noteStore: noteStore,
                                healthService: AppleHealthService(),
                                onUpdated: onHealthUpdated
                            )
                        }
                        .navigationTitle("Apple Health")
                        .navigationBarTitleDisplayMode(.inline)
                    } else {
                        SettingsDestinationScroll {
                            PremiumFeaturePromptContent(feature: "Apple Health")
                        }
                        .navigationTitle("Apple Health")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }

            SettingsSection(title: "Preferences") {
                SettingsInfoRow(title: "Appearance", value: account.appearance)
                SettingsToggleRow(title: "Developer mode", subtitle: "Visible when account entitlement allows it", systemImage: "hammer.fill", tint: BramColor.cool, isOn: account.isDeveloper)
            }

            SettingsSection(title: "Support") {
                SettingsExternalLink(title: "Contact Support", systemImage: "envelope.fill", url: URL(string: "mailto:support@trybram.app")!)
                SettingsExternalLink(title: "Privacy Policy", systemImage: "lock.fill", url: URL(string: "https://trybram.app/privacy")!)
                SettingsExternalLink(title: "Terms", systemImage: "doc.text.fill", url: URL(string: "https://trybram.app/terms")!)
                SettingsActionRow(title: "Sign Out", systemImage: "rectangle.portrait.and.arrow.right", tint: BramColor.cool) {
                    Task {
                        await onSignOut()
                    }
                }
                SettingsDestructiveRow(title: "Delete Account", systemImage: "person.crop.circle.badge.xmark") {
                    showingDeleteConfirmation = true
                }
            }
        }
        .alert("Delete account?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await onDeleteAccount()
                }
            }
        } message: {
            Text("This permanently deletes your Bram account and synced account data. Local data on this device will also be cleared.")
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

private struct SettingsActionRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 24)
                Text(title)
                    .font(BramFont.label())
                    .foregroundStyle(BramColor.textPrimary)
                Spacer()
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsDestinationScroll<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 34)
        }
        .background(BramColor.appBackground)
        .scrollDismissesKeyboard(.interactively)
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
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(16)
    }
}

private struct SettingsNavigationRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let destination: Destination

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                Text(title)
                    .font(BramFont.label())
                Spacer()
            }
            .foregroundStyle(.red)
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(account: BramPreviewData.account)
        .preferredColorScheme(.dark)
}
