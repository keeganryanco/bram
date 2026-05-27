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
    let onDisplayNameSave: (String) async throws -> Void
    let onEmailChange: (String, String) async throws -> Void
    let onPasswordReset: () async throws -> Void
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
    @State private var accountSheet: SettingsAccountSheet?
    @State private var accountActionMessage: String?
    @State private var isSendingPasswordReset = false

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
        onDisplayNameSave: @escaping (String) async throws -> Void = { _ in },
        onEmailChange: @escaping (String, String) async throws -> Void = { _, _ in },
        onPasswordReset: @escaping () async throws -> Void = {},
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
        self.onDisplayNameSave = onDisplayNameSave
        self.onEmailChange = onEmailChange
        self.onPasswordReset = onPasswordReset
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
                SettingsEditableInfoRow(title: "Name", value: account.displayName) {
                    accountSheet = .name
                }
                SettingsEditableInfoRow(title: "Email", value: account.email) {
                    accountSheet = .email
                }
                SettingsActionRow(title: "Change password", systemImage: "key.fill", tint: BramColor.cool) {
                    Task { await sendPasswordResetTapped() }
                }
                .opacity(isSendingPasswordReset ? 0.55 : 1)
                SettingsLinkRow(title: account.subscriptionLabel, subtitle: subscriptionSubtitle, systemImage: "crown.fill", tint: BramColor.warning) {
                    openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
                }
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
                if account.isDeveloper {
                    SettingsToggleRow(
                        title: "Developer mode",
                        subtitle: "Enabled by account entitlement",
                        systemImage: "hammer.fill",
                        tint: BramColor.cool,
                        isOn: true
                    )
                }
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
        .alert("Account", isPresented: accountActionAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(accountActionMessage ?? "")
        }
        .sheet(isPresented: $showingSupport) {
            SupportRequestSheet(account: account, submit: submitSupportRequest)
                .presentationDetents([.height(680)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .sheet(item: $accountSheet) { sheet in
            switch sheet {
            case .name:
                EditDisplayNameSheet(
                    initialName: account.displayName,
                    save: onDisplayNameSave
                )
                .presentationDetents([.medium])
                .presentationCornerRadius(28)
            case .email:
                ChangeEmailSheet(
                    currentEmail: account.email,
                    canChangeEmailWithPassword: account.canChangeEmailWithPassword,
                    changeEmail: onEmailChange
                )
                .presentationDetents([.medium])
                .presentationCornerRadius(28)
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

    private var accountActionAlertBinding: Binding<Bool> {
        Binding(
            get: { accountActionMessage != nil },
            set: { isPresented in
                if !isPresented {
                    accountActionMessage = nil
                }
            }
        )
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

    private func sendPasswordResetTapped() async {
        guard !isSendingPasswordReset else { return }
        isSendingPasswordReset = true
        defer { isSendingPasswordReset = false }
        do {
            try await onPasswordReset()
            accountActionMessage = "Password reset email sent. Check your inbox for the reset link."
        } catch {
            accountActionMessage = error.localizedDescription
        }
    }
}

private enum SettingsAccountSheet: Identifiable {
    case name
    case email

    var id: String {
        switch self {
        case .name: "name"
        case .email: "email"
        }
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
    @State private var didSubmit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Contact Support")
                        .font(BramFont.largeTitle(size: 30))
                        .foregroundStyle(BramColor.textPrimary)
                    Text("Send a bug, billing, account, or workout data note.")
                        .font(BramFont.body(size: 15))
                        .foregroundStyle(BramColor.textSecondary)
                }
                Spacer()
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BramColor.textTertiary)
                        .frame(width: 36, height: 36)
                        .background(BramColor.cardSurface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            if didSubmit {
                SettingsSupportSubmittedView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Category", selection: $category) {
                        ForEach(SupportCategory.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(BramColor.violet)

                    TextEditor(text: $message)
                        .scrollContentBackground(.hidden)
                        .font(BramFont.body(size: 16))
                        .foregroundStyle(BramColor.textPrimary)
                        .frame(height: 210)
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

                    Spacer(minLength: 0)

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
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .padding(22)
        .background(BramColor.appBackground)
        .animation(.snappy(duration: 0.28), value: didSubmit)
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
            didSubmit = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                dismiss()
            }
        } catch {
            resultMessage = error.localizedDescription
        }
    }
}

private struct SettingsSupportSubmittedView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 78, height: 78)
                .background(BramColor.violet, in: Circle())
                .shadow(color: BramColor.violet.opacity(0.24), radius: 18, y: 8)

            VStack(spacing: 8) {
                Text("Your feedback has been submitted")
                    .font(BramFont.headline(size: 24))
                    .foregroundStyle(BramColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("We'll address it as soon as possible and email you if we need any follow-up information or have an update.")
                    .font(BramFont.body(size: 15))
                    .foregroundStyle(BramColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
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

private struct SettingsEditableInfoRow: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(BramFont.body(size: 15))
                    .foregroundStyle(BramColor.textSecondary)
                Spacer()
                Text(value)
                    .font(BramFont.body(size: 15))
                    .foregroundStyle(BramColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BramColor.textTertiary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EditDisplayNameSheet: View {
    let initialName: String
    let save: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var message: String?
    @FocusState private var focused: Bool

    init(initialName: String, save: @escaping (String) async throws -> Void) {
        self.initialName = initialName
        self.save = save
        _name = State(initialValue: initialName)
    }

    var body: some View {
        AccountFormSheet(title: "Name", message: message) {
            AccountTextField(title: "Name", text: $name, textContentType: .name)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { Task { await saveTapped() } }

            AccountPrimaryButton(title: isSaving ? "Saving..." : "Save", isDisabled: isSaving || cleanName.isEmpty) {
                Task { await saveTapped() }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
            }
        }
        .onAppear { focused = true }
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveTapped() async {
        guard !isSaving else { return }
        guard !cleanName.isEmpty else {
            message = "Enter the name you want Bram to use."
            return
        }
        focused = false
        isSaving = true
        defer { isSaving = false }
        do {
            try await save(cleanName)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct ChangeEmailSheet: View {
    let currentEmail: String
    let canChangeEmailWithPassword: Bool
    let changeEmail: (String, String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newEmail = ""
    @State private var password = ""
    @State private var isSaving = false
    @State private var message: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        AccountFormSheet(title: "Email", message: message) {
            if canChangeEmailWithPassword {
                AccountTextField(title: "New email", text: $newEmail, textContentType: .emailAddress, keyboardType: .emailAddress)
                    .focused($focusedField, equals: .email)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                SecureField("Current password", text: $password)
                    .textContentType(.password)
                    .font(BramFont.body(size: 16))
                    .foregroundStyle(BramColor.textPrimary)
                    .padding(16)
                    .background(BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(BramColor.hairline, lineWidth: 1)
                    }
                    .focused($focusedField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit { Task { await saveTapped() } }

                Text("Bram will ask Supabase to confirm the email change. You may need to confirm it from your inbox before the new email appears here.")
                    .font(BramFont.callout(size: 13))
                    .foregroundStyle(BramColor.textTertiary)

                AccountPrimaryButton(title: isSaving ? "Saving..." : "Change email", isDisabled: isSaving || cleanEmail.isEmpty || password.isEmpty) {
                    Task { await saveTapped() }
                }
            } else {
                Text("This account signs in with Apple or Google. Change the email for that account from the provider you use to sign in.")
                    .font(BramFont.body(size: 15))
                    .foregroundStyle(BramColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                AccountPrimaryButton(title: "Done", isDisabled: false) {
                    dismiss()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onAppear {
            newEmail = currentEmail
            if canChangeEmailWithPassword {
                focusedField = .email
            }
        }
    }

    private var cleanEmail: String {
        newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func saveTapped() async {
        guard !isSaving else { return }
        focusedField = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await changeEmail(cleanEmail, password)
            message = "Check your inbox to confirm the email change."
            password = ""
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct AccountFormSheet<Content: View>: View {
    let title: String
    let message: String?
    private let content: Content

    @Environment(\.dismiss) private var dismiss

    init(title: String, message: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.message = message
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(BramFont.largeTitle(size: 30))
                    .foregroundStyle(BramColor.textPrimary)

                content

                if let message {
                    Text(message)
                        .font(BramFont.callout(size: 13))
                        .foregroundStyle(BramColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(22)
            .background(BramColor.appBackground)
            .contentShape(Rectangle())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct AccountTextField: View {
    let title: String
    @Binding var text: String
    var textContentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(title, text: $text)
            .textContentType(textContentType)
            .keyboardType(keyboardType)
            .font(BramFont.body(size: 16))
            .foregroundStyle(BramColor.textPrimary)
            .padding(16)
            .background(BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BramColor.hairline, lineWidth: 1)
            }
    }
}

private struct AccountPrimaryButton: View {
    let title: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BramFont.button(size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(BramColor.violet, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1)
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
