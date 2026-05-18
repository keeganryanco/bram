import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
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
    let setWorkoutRemindersEnabled: (Bool) async -> Bool
    let openGoals: () -> Void
    let openHealth: () -> Void
    let submitSupportRequest: (SupportRequestDraft) async throws -> Void
    let onSupportOpened: () -> Void
    @AppStorage("bramAppearancePreference") private var appearancePreferenceRaw = BramAppearancePreference.system.rawValue
    @AppStorage("bramWorkoutRemindersEnabled") private var workoutRemindersEnabled = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSupport = false
    @State private var showingNotificationSettingsAlert = false
    @State private var isUpdatingWorkoutReminders = false

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
        setWorkoutRemindersEnabled: @escaping (Bool) async -> Bool = { _ in false },
        openGoals: @escaping () -> Void = {},
        openHealth: @escaping () -> Void = {},
        submitSupportRequest: @escaping (SupportRequestDraft) async throws -> Void = { _ in },
        onSupportOpened: @escaping () -> Void = {}
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
        self.setWorkoutRemindersEnabled = setWorkoutRemindersEnabled
        self.openGoals = openGoals
        self.openHealth = openHealth
        self.submitSupportRequest = submitSupportRequest
        self.onSupportOpened = onSupportOpened
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
                SettingsAppearanceRow(selection: appearanceBinding)
                SettingsReminderToggleRow(
                    isOn: reminderBinding,
                    isUpdating: isUpdatingWorkoutReminders
                )
                SettingsToggleRow(title: "Developer mode", subtitle: "Visible when account entitlement allows it", systemImage: "hammer.fill", tint: BramColor.cool, isOn: account.isDeveloper)
            }

            SettingsSection(title: "Support") {
                SettingsActionRow(title: "Contact Support", systemImage: "envelope.fill", tint: BramColor.cool) {
                    onSupportOpened()
                    showingSupport = true
                }
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
        .alert("Notifications are off", isPresented: $showingNotificationSettingsAlert) {
            Button("Not now", role: .cancel) {}
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settingsURL)
                }
            }
        } message: {
            Text("Turn on notifications in iOS Settings to use workout reminders.")
        }
        .sheet(isPresented: $showingSupport) {
            SupportRequestSheet(account: account, submit: submitSupportRequest)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
    }

    private var subscriptionSubtitle: String {
        if account.founderOfferEligible {
            "Founder offer eligible"
        } else {
            "Manage through App Store"
        }
    }

    private var appearanceBinding: Binding<BramAppearancePreference> {
        Binding(
            get: { BramAppearancePreference(rawValue: appearancePreferenceRaw) ?? .system },
            set: { appearancePreferenceRaw = $0.rawValue }
        )
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { workoutRemindersEnabled },
            set: { nextValue in
                guard !isUpdatingWorkoutReminders else { return }
                if !nextValue {
                    workoutRemindersEnabled = false
                }
                isUpdatingWorkoutReminders = true
                Task {
                    let enabled = await setWorkoutRemindersEnabled(nextValue)
                    await MainActor.run {
                        workoutRemindersEnabled = enabled
                        if nextValue, !enabled {
                            showingNotificationSettingsAlert = true
                        }
                        isUpdatingWorkoutReminders = false
                    }
                }
            }
        )
    }
}

private struct SupportRequestSheet: View {
    let account: SettingsAccountState
    let submit: (SupportRequestDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: SupportCategory = .bug
    @State private var message = ""
    @State private var includeDiagnostics = true
    @State private var isSubmitting = false
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Contact Support")
                        .font(BramFont.largeTitle(size: 30))
                        .foregroundStyle(BramColor.textPrimary)
                    Text("Send a bug, billing, account, or workout data note.")
                        .font(BramFont.body(size: 15))
                        .foregroundStyle(BramColor.textSecondary)
                }

                Picker("Category", selection: $category) {
                    ForEach(SupportCategory.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.menu)
                .tint(BramColor.violet)

                TextEditor(text: $message)
                    .font(BramFont.body(size: 16))
                    .foregroundStyle(BramColor.textPrimary)
                    .frame(minHeight: 150)
                    .padding(12)
                    .background(BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(BramColor.hairline, lineWidth: 1)
                    }
                    .accessibilityLabel("Support message")

                Toggle("Include diagnostics", isOn: $includeDiagnostics)
                    .font(BramFont.label())
                    .tint(BramColor.violet)

                if let resultMessage {
                    Text(resultMessage)
                        .font(BramFont.callout(size: 13))
                        .foregroundStyle(BramColor.textSecondary)
                }

                Spacer()

                Button {
                    Task { await submitTapped() }
                } label: {
                    Text(isSubmitting ? "Sending..." : "Send")
                        .font(BramFont.button(size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(BramColor.violet, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
                .opacity(isSubmitting ? 0.5 : 1)
            }
            .padding(22)
            .background(BramColor.appBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func submitTapped() async {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else {
            resultMessage = "Add a short note so support knows what happened."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await submit(
                SupportRequestDraft(
                    category: category,
                    message: cleanMessage,
                    contactEmail: account.email,
                    includeDiagnostics: includeDiagnostics,
                    source: "settings_support"
                )
            )
            resultMessage = "Sent. We will follow up by email if needed."
            message = ""
        } catch {
            resultMessage = error.localizedDescription
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

private struct SettingsAppearanceRow: View {
    @Binding var selection: BramAppearancePreference

    var body: some View {
        Menu {
            ForEach(BramAppearancePreference.allCases) { preference in
                Button {
                    selection = preference
                } label: {
                    HStack {
                        Text(preference.label)
                        if selection == preference {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(BramColor.violet)
                    .frame(width: 24)
                Text("Appearance")
                    .font(BramFont.label())
                    .foregroundStyle(BramColor.textPrimary)
                Spacer()
                Text(selection.label)
                    .font(BramFont.body(size: 15))
                    .foregroundStyle(BramColor.textSecondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BramColor.textTertiary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Appearance")
        .accessibilityValue(selection.label)
    }
}

private struct SettingsReminderToggleRow: View {
    @Binding var isOn: Bool
    let isUpdating: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .foregroundStyle(BramColor.violet)
                .frame(width: 24)
            Text("Workout reminders")
                .font(BramFont.label())
                .foregroundStyle(BramColor.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(BramColor.violet)
                .disabled(isUpdating)
        }
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

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(url)
        } label: {
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
        .buttonStyle(.plain)
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
