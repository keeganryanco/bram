import SwiftUI

struct AccountGateView: View {
    var message: String?
    var signIn: (String, String) async -> Void
    var signUp: (String, String) async -> Void
    var resetPassword: (String) async -> Void
    var signInWithApple: () async -> Void
    var signInWithGoogle: () async -> Void

    private enum Mode {
        case createAccount
        case signIn
    }

    private enum FocusedField: Hashable {
        case email
        case password
    }

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var mode: Mode = .createAccount
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        ZStack {
            OnboardingStyle.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 16)

                Image("BramBearAccountCreation")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .accessibilityHidden(true)
                    .padding(.bottom, 4)

                VStack(spacing: 8) {
                    Text(mode == .createAccount ? "Welcome to Bram" : "Welcome back")
                        .font(BramFont.largeTitle(size: 36))
                        .foregroundStyle(OnboardingStyle.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(mode == .createAccount ? "The simplest workout tracker ever." : "Pick up where you left off.")
                        .font(BramFont.body(size: 18))
                        .foregroundStyle(OnboardingStyle.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                        .bramAccountField()

                    SecureField("Password", text: $password)
                        .textContentType(mode == .createAccount ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit {
                            submitPrimary()
                        }
                        .bramAccountField()
                }

                VStack(spacing: 12) {
                    AuthPrimaryButton(title: primaryButtonTitle, isDisabled: isSubmitting || email.isEmpty || password.isEmpty) {
                        submitPrimary()
                    }

                    HStack(spacing: 10) {
                        AccountProviderButton(provider: .apple) {
                            submit { await signInWithApple() }
                        }
                        AccountProviderButton(provider: .google) {
                            submit { await signInWithGoogle() }
                        }
                    }
                    .disabled(isSubmitting)

                    if message != nil || mode == .signIn {
                        Button("Forgot password?") {
                            submit { await resetPassword(email) }
                        }
                            .font(BramFont.callout(size: 13))
                            .foregroundStyle(OnboardingStyle.textTertiary)
                            .disabled(isSubmitting)
                    }

                    if let message {
                        Text(message)
                            .font(BramFont.callout(size: 13))
                            .foregroundStyle(OnboardingStyle.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }

                Spacer()

                Button(mode == .createAccount ? "Already have an account? Sign in" : "Create a new account") {
                    withAnimation(.snappy) {
                        mode = mode == .createAccount ? .signIn : .createAccount
                        password = ""
                        focusedField = .email
                    }
                }
                .font(BramFont.label())
                .foregroundStyle(OnboardingStyle.textSecondary)
                .disabled(isSubmitting)
            }
            .padding(24)
            .frame(maxWidth: 520)
        }
        .onAppear {
            if message != nil {
                mode = .signIn
            }
        }
    }

    private var primaryButtonTitle: String {
        if isSubmitting {
            return mode == .createAccount ? "Creating account..." : "Signing in..."
        }
        return mode == .createAccount ? "Create account" : "Sign in"
    }

    private func submit(_ operation: @escaping () async -> Void) {
        guard !isSubmitting else { return }
        focusedField = nil
        isSubmitting = true
        Task {
            await operation()
            await MainActor.run {
                isSubmitting = false
            }
        }
    }

    private func submitPrimary() {
        guard !email.isEmpty, !password.isEmpty else { return }
        submit {
            if mode == .createAccount {
                await signUp(email, password)
            } else {
                await signIn(email, password)
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

private struct AuthPrimaryButton: View {
    let title: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BramFont.button(size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(BramColor.violet, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: BramColor.violet.opacity(0.26), radius: 22, y: 12)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }
}

private enum AccountProvider {
    case apple
    case google

    var title: String {
        switch self {
        case .apple: "Apple"
        case .google: "Google"
        }
    }
}

private struct AccountProviderButton: View {
    let provider: AccountProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if provider == .apple {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .semibold))
                } else {
                    GoogleGlyph()
                        .frame(width: 18, height: 18)
                }
                Text(provider.title)
            }
            .font(BramFont.label())
            .foregroundStyle(OnboardingStyle.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(OnboardingStyle.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(OnboardingStyle.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct GoogleGlyph: View {
    var body: some View {
        Text("G")
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(OnboardingStyle.textPrimary)
            .accessibilityHidden(true)
    }
}

private extension View {
    func bramAccountField() -> some View {
        self
            .font(BramFont.body(size: 16))
            .foregroundStyle(OnboardingStyle.textPrimary)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(OnboardingStyle.fieldSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(OnboardingStyle.hairline, lineWidth: 1)
            }
            .shadow(color: OnboardingStyle.fieldShadow, radius: 18, y: 8)
    }
}

#Preview {
    AccountGateView(
        message: nil,
        signIn: { _, _ in },
        signUp: { _, _ in },
        resetPassword: { _ in },
        signInWithApple: {},
        signInWithGoogle: {}
    )
    .preferredColorScheme(.dark)
}
