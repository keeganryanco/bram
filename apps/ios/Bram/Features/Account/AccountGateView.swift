import SwiftUI

struct AccountGateView: View {
    var message: String?
    var signIn: (String, String) async -> Void
    var signUp: (String, String) async -> Void
    var signInWithApple: () async -> Void
    var signInWithGoogle: () async -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            BramColor.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                Spacer(minLength: 28)

                BramLogoMark(size: 54)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bram")
                        .font(BramFont.largeTitle(size: 42))
                        .foregroundStyle(BramColor.textPrimary)
                    Text("Write your workout naturally. Bram tracks the rest.")
                        .font(BramFont.body(size: 17))
                        .foregroundStyle(BramColor.textSecondary)
                }

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .bramAccountField()

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .bramAccountField()

                    if let message {
                        Text(message)
                            .font(BramFont.callout(size: 13))
                            .foregroundStyle(BramColor.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                VStack(spacing: 10) {
                    BramCapsuleButton(action: {
                        submit { await signIn(email, password) }
                    }) {
                        Text(isSubmitting ? "Signing in..." : "Sign in")
                    }
                    .disabled(isSubmitting || email.isEmpty || password.isEmpty)

                    Button("Create account") {
                        submit { await signUp(email, password) }
                    }
                    .font(BramFont.label())
                    .foregroundStyle(BramColor.violet)
                    .disabled(isSubmitting || email.isEmpty || password.isEmpty)
                }

                HStack(spacing: 10) {
                    AccountProviderButton(title: "Apple", systemImage: "apple.logo") {
                        submit { await signInWithApple() }
                    }
                    AccountProviderButton(title: "Google", systemImage: "globe") {
                        submit { await signInWithGoogle() }
                    }
                }
                .disabled(isSubmitting)

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: 520)
        }
    }

    private func submit(_ operation: @escaping () async -> Void) {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            await operation()
            await MainActor.run {
                isSubmitting = false
            }
        }
    }
}

struct OnboardingGateView: View {
    let account: SettingsAccountState
    let goalsProfile: TrainingGoalsProfile
    let complete: (TrainingGoalsProfile) async -> Void
    let signOut: () async -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Set your baseline")
                            .font(BramFont.largeTitle(size: 34))
                            .foregroundStyle(BramColor.textPrimary)
                        Text(account.email)
                            .font(BramFont.callout(size: 13))
                            .foregroundStyle(BramColor.textTertiary)
                    }

                    GoalsSettingsContent(profile: goalsProfile) { profile in
                        Task {
                            await complete(profile)
                        }
                    }

                    Button("Sign out") {
                        Task {
                            await signOut()
                        }
                    }
                    .font(BramFont.label())
                    .foregroundStyle(.red)
                }
                .padding(20)
            }
            .background(BramColor.appBackground)
        }
    }
}

private struct AccountProviderButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(BramFont.label())
            .foregroundStyle(BramColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(BramColor.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(BramColor.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func bramAccountField() -> some View {
        self
            .font(BramFont.body(size: 16))
            .foregroundStyle(BramColor.textPrimary)
            .padding(14)
            .background(BramColor.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(BramColor.hairline, lineWidth: 1)
            }
    }
}

#Preview {
    AccountGateView(
        message: nil,
        signIn: { _, _ in },
        signUp: { _, _ in },
        signInWithApple: {},
        signInWithGoogle: {}
    )
    .preferredColorScheme(.dark)
}
