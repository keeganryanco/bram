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
- App description must clearly state near the top: `Bram requires an auto-renewable subscription after a 3-day free trial.`

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

Saturday, May 16 DONE:

- Finish support intake, crash follow-up, analytics, and review prompt instrumentation.
- Add `LINEAR_API_KEY` in Vercel production and redeploy so authenticated support requests mirror into the Linear `Support Inbox` project.
- Confirm RevenueCat public iOS SDK key is in `BRAM_IOS_REVENUECAT_API_KEY`; without it the native paywall cannot load offerings.
- Verify the RevenueCat current/default offering contains `app.trybram.Bram.premium.year` and `app.trybram.Bram.premium.monthly` under entitlement `premium`.
- Verify Settings can opt into local workout reminders and that saving a workout-like note schedules a contextual local reminder.
- Verify onboarding permission screens trigger Apple Health and notification prompts before the baseline recap.
- Verify Apple Health on a physical iPhone before App Store submission. Bram has the local HealthKit entitlement, `HealthKit.framework`, and `NSHealthShareUsageDescription`; the Apple Developer App ID for `app.trybram.Bram` must also have HealthKit enabled. Simulator/iPad-style runs can report Health unavailable or have no Health store data. On device, confirm the permission sheet appears, then check iOS Health > Sharing > Apps > Bram for workouts, active energy, heart rate, distance, and bodyweight read access.

Sunday, May 17:

- Run a launch readiness pass on onboarding, paywall copy, note parsing, stats, suggestions, local/account data separation, account deletion, and privacy labels.
- Create App Store screenshots and Product Hunt screenshots from real in-app flows.
- Create App Review demo account with developer access enabled in Supabase so reviewers can bypass payment if subscription products are unavailable during review.

Monday, May 18:

- Upload the archive to App Store Connect.
- Submit the app and the first subscriptions together for App Review, with review notes explaining the hard paywall, demo account, RevenueCat entitlement, and restore flow.
- Submit the first external TestFlight build for Beta App Review.

Tuesday-Thursday, May 19-21:

- Use TestFlight for Reddit/forum/friends feedback. TestFlight in-app purchases use Apple's sandbox and are free to testers.
- Use Apple subscription offer codes for one-month TestFlight access. The in-app `Redeem code` button opens Apple's official offer-code redemption sheet.
- Supabase promo tables remain for campaign tracking, email segmentation, and private entitlement grants, but public in-app promo codes do not unlock paid access in the App Store build.
- When a tester receives a TestFlight offer code email, the branded "Welcome to the Bram TestFlight" Resend email is sent once and recorded in `account_email_events`.
- When a signed-in user bootstraps from a TestFlight build, iOS sends a sandbox-receipt distribution signal to `/api/account/welcome-email`; the server records `testflight_signup_2026_05` for launch follow-up email targeting.
- Every first successful Bram signup/session bootstrap can trigger the branded "Welcome to Bram" Resend email once through `account_email_events` event key `welcome_2026_05`.
- Fix only launch-blocking bugs: crashes, account loss/mixing, broken onboarding, broken paywall, broken note parsing, broken data deletion/export, and metadata/privacy mismatches.

Friday, May 22:

- Product Hunt launch.
- Use Apple subscription offer codes for Product Hunt one-month access. Distribute redemption links/codes through the launch email and Product Hunt messaging.
- Vercel Cron sends the waitlist launch email at 7:00 AM Central when `CRON_SECRET` is configured and `LAUNCH_DAY_EMAIL_ENABLED=true`. Standard waitlisters get the one-month founder email. Emails with `FRIENDS_DISCOUNT` or `FOUNDER_LIFETIME` in `account_promo_eligibilities` or `account_entitlements` get the lifetime access variant.
- Vercel Cron also sends a TestFlight launch follow-up at 7:00 AM Central to signed-in TestFlight accounts recorded with `testflight_signup_2026_05`, using `BRAM_TESTFLIGHT_LAUNCH_OFFER_URL` when configured.
- Monitor PostHog onboarding/paywall funnels, Supabase support requests/error reports, Linear support issues, RevenueCat purchase state, and App Store/TestFlight feedback.

## TestFlight Distribution

1. Upload the processed App Store Connect build from Xcode Organizer.
2. Add yourself as an internal tester and install Bram through Apple's TestFlight app on your iPhone.
3. Verify fresh install, email auth, Apple sign-in, Google sign-in, RevenueCat products, sandbox purchase/restore, Apple offer-code redemption, reinstall/sign-in sync, and developer bypass on the App Review account.
4. Create an external group named `Reddit Beta` or `Bram TestFlight`, add the build, and submit it for Beta App Review.
5. After approval, enable a public TestFlight link and start with a `100-250` tester limit.
6. Reddit post should include the public TestFlight link, Apple offer-code redemption instructions, and a feedback ask: email `keegan@trybram.app` or comment on the Reddit post.

Beta review notes:

- Bram is a paid workout notes app with a hard paywall.
- Subscriptions use App Store purchases and RevenueCat.
- App Review demo account: `review@trybram.app` / `appstorereview498`.
- The demo account has Supabase developer access and bypasses payment.
- Testers may redeem Apple subscription offer codes for one month free app access.

## Promo Strategy

- Public one-month promos use Apple subscription offer codes created in App Store Connect. The app's `Redeem code` action opens Apple's official redemption sheet.
- TestFlight, waitlist/founder, and Product Hunt campaigns should distribute Apple offer-code links or codes by Resend/email/social copy.
- TestFlight users are identifiable only after they sign into Bram from a TestFlight build; Apple does not expose a public tester list to Bram. Those users are marked by the sandbox receipt signal and can receive a launch-day App Store offer email.
- Supabase promo tables remain for campaign attribution, email segmentation, and private account entitlements, but the reviewed app build does not expose Bram-owned public promo-code redemption.
- Friends/family: use `FRIENDS_DISCOUNT` or `FOUNDER_LIFETIME` in Supabase. These account entitlements bypass the paywall and can still subscribe from Settings if they want to support Bram.
- Referrals use Apple offer codes for paid access. The in-app share badge shares a Bram referral URL; the landing page sends the friend through Apple's offer-code redemption link, then back into Bram to attribute the referral after the friend has active Apple/RevenueCat access.
- Referral rewards are queued as Apple-offer-code rewards in Supabase audit rows. Bram must deliver the referrer's extra month through an Apple subscription offer code, not a Supabase entitlement extension.
- App Store review note: subscriptions and public offer codes are handled through Apple IAP; no Bram-owned in-app promo code unlocks paid features.

## In-App Event Nomination

Use this only if the build with the in-app challenge is submitted and visible before nomination.

- Event name: `Founding Lifters Week`
- Badge: `Challenge`
- Publish/announcement target: `2026-05-22`
- Date range: `2026-05-23` to `2026-05-30`
- In-app overlay: after onboarding/paywall access, signed-in users see a one-time dismissible Home overlay from May 23 through May 30 with `Founding Lifters Week`, `Log 4 workouts by May 30 and earn a limited launch badge.`, and CTA `I'm in`.
- Badge details: Streaks award tiles open a detail sheet. Unlocked badges can be shared through the native share sheet; the referral badge shares the user's referral URL.
- Short description: `Log 4 workouts and start your first strength history.`
- Long description:

```text
Founding Lifters Week is a limited-time launch challenge that helps new Bram users build their first week of training history.

Log four workouts in Bram, review your weekly progress, and start turning natural gym notes into PRs, set volume, streaks, and training insights.

Bram is built for lifters who already track in Notes, paper, or spreadsheets but want a cleaner iPhone-native way to remember their training. Write what you did. Bram tracks the rest.
```

- App Store nomination:
  - Nomination Type: `New Content`
  - Nomination Name: `Founding Lifters Week`
  - Do you intend to submit a new In-App Event: `Yes`

## Review Notes Checklist

- Demo account email and password, with Supabase developer access enabled.
- Clear note that subscriptions are auto-renewable, include a 3-day free trial, and are managed through App Store purchase/restore.
- Clear note that Bram requires an auto-renewable subscription after the 3-day free trial.
- Clear note that `Redeem code` opens Apple's official offer-code redemption sheet and no Bram-owned public promo code unlocks paid access.
- If subscription products are `Ready to Submit`, explain that they are submitted with this binary and visible on the Bram Premium screen.
- Support URL/email and privacy/terms links.
- Any AI processing disclosure in plain language: users write workout notes; Bram interprets them to calculate workout stats and suggestions.

## Setup

Use [App Store Connect setup](app-store-connect-setup.md) to create the app record and upload the first TestFlight build.
