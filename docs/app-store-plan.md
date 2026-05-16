# Bram App Store Plan

## Metadata

- Title: `Bram: Workout Notes`
- Bundle ID: `app.trybram.Bram`
- SKU: `app.trybram.Bram`
- Subtitle candidates:
  - Simple strength tracking
  - Workout notes that track progress
  - Write workouts. Track progress.
  - A calmer way to get stronger

## Required Links

- Privacy Policy: `https://trybram.app/privacy`
- Terms: `https://trybram.app/terms`
- Support: `support@trybram.app`

## Screenshots

Initial screenshot story:

1. Write your workout naturally.
2. Bram tracks the rest.
3. Progress without spreadsheets.
4. A calmer way to get stronger.
5. Your workouts, remembered.

## Submission Readiness

Before submission, verify subscriptions, deletion/export, analytics disclosures, AI processing disclosure, and final legal review.

## May 16-22, 2026 Launch Plan

Saturday, May 16:

- Finish support intake, crash follow-up, analytics, and review prompt instrumentation.
- Confirm RevenueCat public iOS SDK key is in `BRAM_IOS_REVENUECAT_API_KEY`; without it the native paywall cannot load offerings.
- Verify the RevenueCat current/default offering contains `app.trybram.Bram.premium.year` and `app.trybram.Bram.premium.monthly` under entitlement `premium`.
- Verify Settings can opt into local workout reminders and that saving a workout-like note schedules a contextual local reminder.
- Verify onboarding permission screens trigger Apple Health and notification prompts before the baseline recap.

Sunday, May 17:

- Run a launch readiness pass on onboarding, paywall copy, note parsing, stats, suggestions, local/account data separation, account deletion, and privacy labels.
- Create App Store screenshots and Product Hunt screenshots from real in-app flows.
- Create App Review demo account with developer access enabled in Supabase so reviewers can bypass payment if subscription products are unavailable during review.

Monday, May 18:

- Upload the archive to App Store Connect.
- Submit the app and the first subscriptions together for App Review, with review notes explaining the hard paywall, demo account, RevenueCat entitlement, and restore flow.
- Submit the first external TestFlight build for Beta App Review.

Tuesday-Thursday, May 19-21:

- Use TestFlight for Reddit/forum/friends feedback. TestFlight in-app purchases use Apple's sandbox and are free to testers, so use Supabase admin grants only when testers need app access without completing sandbox purchase flows.
- Apply `TESTFLIGHT1MONTH` style grants through Bram's admin grant route for selected testers; keep Product Hunt grants separate as `PRODUCT_HUNT` one-month grants.
- Fix only launch-blocking bugs: crashes, account loss/mixing, broken onboarding, broken paywall, broken note parsing, broken data deletion/export, and metadata/privacy mismatches.

Friday, May 22:

- Product Hunt launch.
- Use Product Hunt one-month access via Bram-owned Supabase grants first; public Apple/RevenueCat offer codes can follow after App Store subscription approval and offer-code setup.
- Monitor PostHog onboarding/paywall funnels, Supabase support requests/error reports, Linear support issues, RevenueCat purchase state, and App Store/TestFlight feedback.

## Review Notes Checklist

- Demo account email and password, with Supabase developer access enabled.
- Clear note that subscriptions are auto-renewable, include a 3-day free trial, and are managed through App Store purchase/restore.
- If subscription products are `Ready to Submit`, explain that they are submitted with this binary and visible on the Bram Premium screen.
- Support URL/email and privacy/terms links.
- Any AI processing disclosure in plain language: users write workout notes; Bram interprets them to calculate workout stats and suggestions.

## Setup

Use [App Store Connect setup](app-store-connect-setup.md) to create the app record and upload the first TestFlight build.
