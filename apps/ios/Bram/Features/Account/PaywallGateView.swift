import SwiftUI

struct PaywallGateView: View {
    @Environment(\.scenePhase) private var scenePhase

    let account: SettingsAccountState
    let accountMessage: String?
    let load: () async throws -> BramPaywallSnapshot
    let trackImpression: () -> Void
    let purchase: (String) async -> Void
    let continueToTesting: () async -> Void
    let restore: () async -> Void
    let redeemCode: () async -> Void
    let retryAccess: () async -> Void
    let signOut: () async -> Void

    @State private var snapshot = BramPaywallSnapshot.unavailable
    @State private var selectedPackageId: String?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var message: String?
    @State private var didTrackImpression = false
    @State private var shouldRestoreAfterOfferCodeSheet = false

    var body: some View {
        ZStack {
            BramColor.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    BramLogoMark(size: 34)
                    Spacer()
                    Button("Sign out") {
                        Task { await signOut() }
                    }
                    .font(BramFont.label(size: 13))
                    .foregroundStyle(BramColor.textTertiary)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Try Bram free for 3 days.")
                            .font(BramFont.largeTitle(size: 42))
                            .foregroundStyle(BramColor.textPrimary)
                        Text("Log your workouts like a note. Bram tracks your lifts, PRs, and streaks so you can stop guessing and actually progress.")
                            .font(BramFont.body(size: 17))
                            .foregroundStyle(BramColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 10) {
                            PaywallBenefit("Write workouts naturally")
                            PaywallBenefit("Track PRs without spreadsheets")
                            PaywallBenefit("See what to beat next time")
                            PaywallBenefit("Cancel anytime during the trial")
                        }
                        .padding(.vertical, 8)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else if snapshot.packages.isEmpty {
                            Text(snapshot.message ?? "Subscription options are not available yet.")
                                .font(BramFont.callout())
                                .foregroundStyle(BramColor.textSecondary)
                                .padding(16)
                                .background(BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            VStack(spacing: 10) {
                                ForEach(paywallPackages) { package in
                                    PaywallPackageButton(
                                        package: package,
                                        isSelected: selectedPackageId == package.id
                                    ) {
                                        selectedPackageId = package.id
                                    }
                                }
                            }
                        }

                        if let displayMessage {
                            Text(displayMessage)
                                .font(BramFont.callout(size: 13))
                                .foregroundStyle(BramColor.textTertiary)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }

                VStack(spacing: 14) {
                    PaywallPrimaryButton(
                        title: primaryButtonTitle,
                        isDisabled: isPrimaryButtonDisabled
                    ) {
                        if account.usesReviewTestingPaywall {
                            isSubmitting = true
                            Task {
                                await continueToTesting()
                                await MainActor.run { isSubmitting = false }
                            }
                            return
                        }
                        guard let selectedPackageId else { return }
                        isSubmitting = true
                        Task {
                            await purchase(selectedPackageId)
                            await MainActor.run { isSubmitting = false }
                        }
                    }

                    HStack(spacing: 18) {
                        Button("Restore") {
                            Task { await restore() }
                        }
                        Button("Redeem code") {
                            shouldRestoreAfterOfferCodeSheet = true
                            Task { await redeemCode() }
                        }
                        Button("Retry") {
                            Task {
                                await retryAccess()
                                await reload()
                            }
                        }
                    }
                    .font(BramFont.label(size: 13))
                    .foregroundStyle(BramColor.textTertiary)
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .background(
                    LinearGradient(
                        colors: [BramColor.appBackground.opacity(0), BramColor.appBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )
            }
        }
        .task {
            await reload()
        }
        .onAppear {
            guard !didTrackImpression else { return }
            didTrackImpression = true
            trackImpression()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, shouldRestoreAfterOfferCodeSheet else { return }
            shouldRestoreAfterOfferCodeSheet = false
            Task {
                await restore()
                await reload()
            }
        }
    }

    private func reload() async {
        isLoading = true
        message = nil
        do {
            snapshot = try await load()
            selectedPackageId = snapshot.packages.first(where: \.isRecommended)?.id ?? snapshot.packages.first?.id
        } catch {
            snapshot = .unavailable
            message = error.localizedDescription
        }
        isLoading = false
    }

    private var paywallPackages: [BramPaywallPackage] {
        snapshot.packages
    }

    private var displayMessage: String? {
        accountMessage ?? message
    }

    private var primaryButtonTitle: String {
        if isSubmitting {
            return account.usesReviewTestingPaywall ? "Opening Bram..." : "Checking..."
        }
        return account.usesReviewTestingPaywall ? "Continue to testing" : "Try 3 days free"
    }

    private var isPrimaryButtonDisabled: Bool {
        if account.usesReviewTestingPaywall {
            return isSubmitting
        }
        return selectedPackageId == nil || isSubmitting
    }
}

private struct PaywallPrimaryButton: View {
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
                .background(BramColor.violet, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: BramColor.violet.opacity(0.30), radius: 22, y: 12)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.50 : 1)
    }
}

private struct PaywallBenefit: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(BramColor.violet)
            Text(text)
                .font(BramFont.label())
                .foregroundStyle(BramColor.textPrimary)
        }
    }
}

private struct PaywallPackageButton: View {
    let package: BramPaywallPackage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(package.title)
                            .font(BramFont.headline(size: 18))
                        if package.isRecommended {
                            Text("Best value")
                                .font(BramFont.label(size: 11))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(BramColor.violet, in: Capsule())
                        }
                    }
                    Text(package.detail)
                        .font(BramFont.callout(size: 13))
                        .foregroundStyle(BramColor.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if package.promoPrice != nil {
                        Text(package.price)
                            .font(BramFont.callout(size: 12))
                            .foregroundStyle(BramColor.textTertiary)
                            .strikethrough()
                        Text(package.displayPrice)
                            .font(BramFont.label())
                    } else {
                        Text(package.price)
                            .font(BramFont.label())
                    }
                    Text(package.period)
                        .font(BramFont.callout(size: 12))
                        .foregroundStyle(BramColor.textTertiary)
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BramColor.violet)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(BramColor.textPrimary)
            .padding(16)
            .background(BramColor.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? BramColor.violet : BramColor.hairline, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}
