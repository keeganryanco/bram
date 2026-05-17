# Bram Account Architecture

## Intent

Bram uses Supabase Auth for identity and Supabase Postgres for user-owned backup/sync data. Native iOS subscriptions stay native/App Store-first, with RevenueCat as the subscription-state adapter.

The account model must make these operations simple:

- find a user by email
- see whether they came from the waitlist founder offer
- grant a manual lifetime premium pass
- enable developer-only app features
- keep normal users from modifying entitlement flags

## Auth Providers

Planned providers:

- Email/password
- Sign in with Apple
- Google Sign-In

Email confirmation should be disabled for the intended first-pass UX. Confirm this in the Supabase dashboard before app auth work:

`Authentication -> Providers -> Email -> Confirm email = off`

Apple and Google require provider/client configuration in the Supabase dashboard and native iOS URL handling. Do not commit OAuth secrets.

The iOS app uses the custom redirect scheme `app.trybram.Bram`. Add this redirect allowlist in Supabase before testing OAuth:

`app.trybram.Bram://**`

The iOS bundle may include the Supabase project URL and publishable key. It must never include the service-role key.

Password reset requests are sent through the website, not the generic Supabase email. The app posts to the website password-reset route; the website calls Supabase Auth Admin from a server route to generate a recovery token, sends a branded email through Resend, and links directly to `https://www.trybram.app/reset-password?token_hash=...&type=recovery` so the reset page can verify the token and let the user choose a new password. The website requires `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and a Resend API key in deployment. Keep `NEXT_PUBLIC_SITE_URL` set to `https://www.trybram.app`; add `https://www.trybram.app/reset-password` to the Supabase Auth redirect allowlist for fallback action-link flows.

## Tables

| Object | Purpose | Client access |
| --- | --- | --- |
| `profiles` | User-editable account profile and onboarding basics. | Authenticated users can read their own row and update approved profile columns only. |
| `training_profiles` | Goal, weekly target, session length, training styles, and equipment context. | Authenticated users can manage their own row. Future AI uses it as private personalization context. |
| `account_entitlements` | Service-role managed premium/dev/founder/subscription flags. | Authenticated users can read their own row only. No client writes. |
| `subscription_events` | Append-only purchase/subscription history for App Store, RevenueCat, or manual actions. | Authenticated users can read their own rows only. No client writes. |
| `account_grant_events` | Service-role audit history for TestFlight, Product Hunt, and founder grants. | No client access. |
| `ai_usage_events` | Server-side AI usage metadata and estimated cost by user/month/task/model. | No client access and never stores raw notes. |
| `account_snapshot` | Read-only joined account state for app startup/settings. | Authenticated users can read their own state through underlying RLS. |
| `waitlist_signups` | Landing-site waitlist and founder-offer eligibility. | No public client reads/writes. Website writes through the server route. |

Workout tables are identity-separated. They are keyed by Supabase `user_id` and must not duplicate email, display name, provider IDs, or other direct identity fields. Identity-adjacent data belongs in Supabase Auth and `profiles`; subscription/admin flags belong in `account_entitlements`; workout logs and derived metrics belong in workout tables.

## Onboarding Contract

The app stores onboarding in two places:

- `profiles`: identity-adjacent and body/unit fields: email, display name, preferred units, height, current bodyweight, target bodyweight, bodyweight source/logged timestamp, sex, optional sex self-description, optional daily calorie estimate, and `onboarding_completed_at`.
- `training_profiles`: training intent fields: primary goal, weekly training days, typical session length, training styles, and available equipment.
- `support_requests`: service-role-only support inbox keyed by `user_id`; iOS submits authenticated support requests through `/api/support/request`.
- `app_error_reports`: service-role-only diagnostic metadata keyed by `user_id` when authenticated; iOS submits handled nonfatal errors through `/api/telemetry/error`.

First-run onboarding collects first name, goal, weekly target, session length, training styles, equipment, preferred units, current weight, and optional target weight. It saves a local draft first, then syncs `profiles.display_name`, `profiles.onboarding_completed_at`, body/unit fields, and `training_profiles` after completion. `profiles.preferred_units` remains the startup unit source exposed through `account_snapshot`. `training_profiles` is fetched after account bootstrap and is editable from Settings. Both tables are private account data and must not be sent to analytics as raw values.

Product analytics identifies users by Supabase `user_id` only. PostHog should not receive email, first name, raw workout notes, raw body metrics, raw Health samples, or support message bodies.

## Subscription Entitlement Flow

iOS configures RevenueCat with the Supabase user UUID as the App User ID. The client can load offerings, purchase, restore purchases, and open Apple code redemption, but it never writes `account_entitlements`.

Trusted entitlement writes happen through:

- `POST /api/revenuecat/refresh`: authenticated by the user's Supabase bearer token, fetches the RevenueCat subscriber, and updates `account_entitlements` with the service-role key.
- `POST /api/revenuecat/webhook`: protected by `REVENUECAT_WEBHOOK_AUTH_HEADER`, appends `subscription_events`, then refreshes `account_entitlements` from RevenueCat's current subscriber state.

RevenueCat defaults are entitlement `premium`, current/default offering, and product IDs `app.trybram.Bram.premium.monthly` and `app.trybram.Bram.premium.year`. The iOS app uses the public `BramRevenueCatAPIKey` build setting and tracks custom paywall impressions because Bram renders its own native paywall. App Store/RevenueCat dashboard setup owns the 3-day trial, pricing, promo codes, and future cancellation/winback offers.

RevenueCat sync maps active paid access to `PREMIUM`, active trials to `TRIAL`, cancellation-with-remaining-access to `CANCELED`, billing issues to `BILLING_RETRY`, and expired subscriptions to `EXPIRED`. Expired RevenueCat state must not overwrite active manual/founder/developer grants; expired one-month grants fall back to `FREE`.

### Admin grants

Server grants use `POST /api/admin/account-grants`, protected by `BRAM_ADMIN_GRANT_TOKEN`. The route accepts a `userId` or account email, `grantKind` (`TESTFLIGHT_1MONTH`, `PRODUCT_HUNT_1MONTH`, `FOUNDER_1MONTH`, `FOUNDER_LIFETIME`, or `FRIENDS_DISCOUNT`), optional expiration, and optional AI budget caps. Legacy `TESTFLIGHT` and `PRODUCT_HUNT` inputs are normalized to the one-month grant kinds.

- TestFlight, Product Hunt, and first-month founder grants default to one month of `FREE_PREMIUM`.
- Founder lifetime grants use `entitlement_source = FOUNDER_OFFER` and `premium_expires_at = null`.
- Friends discount grants use `FREE_PREMIUM` with `premium_expires_at = null`, `entitlement_source = MANUAL`, and the promo/founder AI budget policy so access is lifetime but model costs stay capped.
- Every grant writes an `account_grant_events` audit row.
- `POST /api/account/redeem-promo` lets the iOS paywall submit a code, but Supabase still decides eligibility. TestFlight/Product Hunt codes require a row in `account_promo_eligibilities`; founder codes require the account or matching waitlist email to be founder eligible.
- Apple/RevenueCat offer codes remain the public App Store campaign path later; Bram-owned grants are the controllable prelaunch path.

### Promo/founder AI budget

Founder and manual free-premium accounts use a lower server-side AI budget policy. At `$0.50` estimated monthly AI spend, server AI calls downgrade strong/premium tasks to the fast model until the next month. At `$2.00`, premium AI calls are blocked until the next month. Paid subscribers keep the normal paid model policy. Developer accounts are not budget-downgraded by this policy.

## Automatic Signup Flow

The trigger `on_auth_user_created_create_bram_account` runs after `auth.users` insert.

It creates:

- `profiles` row with lowercased email and best-effort display name from OAuth/email metadata
- `account_entitlements` row with default `FREE` access
- founder offer linkage when the signup email matches `waitlist_signups.email`
- one free founder month auto-applied when that waitlist row is founder eligible

If a waitlist match exists, the user gets:

- `account_entitlements.founder_offer_eligible = true`
- `account_entitlements.entitlement_source = 'FOUNDER_OFFER'`
- `account_entitlements.founder_offer_waitlist_signup_id = waitlist_signups.id`
- `waitlist_signups.founder_offer_redeemed_by_user_id = auth.users.id`

This does not automatically grant premium. It only marks eligibility so the founder discount can be issued later.

## Manual Admin Snippets

Run these from the Supabase SQL editor or any service-role backend path. Replace the email.

Find an account:

```sql
select *
from public.account_snapshot
where email = lower('person@example.com');
```

Grant lifetime premium:

```sql
update public.account_entitlements e
set
  account_tier = 'FREE_PREMIUM',
  subscription_status = 'FREE_PREMIUM',
  entitlement_source = 'MANUAL',
  premium_expires_at = null,
  manual_reason = 'Lifetime pass granted by founder.',
  updated_at = now()
from public.profiles p
where p.user_id = e.user_id
  and p.email = lower('person@example.com');
```

Enable developer mode:

```sql
update public.account_entitlements e
set
  is_developer = true,
  entitlement_source = 'DEV',
  manual_reason = 'Developer access.',
  updated_at = now()
from public.profiles p
where p.user_id = e.user_id
  and p.email = lower('person@example.com');
```

Remove manual premium/dev access:

```sql
update public.account_entitlements e
set
  account_tier = 'FREE',
  subscription_status = 'NONE',
  entitlement_source = 'NONE',
  is_developer = false,
  premium_expires_at = null,
  manual_reason = null,
  updated_at = now()
from public.profiles p
where p.user_id = e.user_id
  and p.email = lower('person@example.com');
```

List founder-offer eligible accounts:

```sql
select
  p.email,
  p.display_name,
  e.account_tier,
  e.founder_offer_eligible,
  w.created_at as waitlist_joined_at
from public.account_entitlements e
join public.profiles p on p.user_id = e.user_id
left join public.waitlist_signups w on w.id = e.founder_offer_waitlist_signup_id
where e.founder_offer_eligible = true
order by w.created_at nulls last, p.created_at;
```

## App Consumption

At app startup after login:

1. Restore the Supabase Auth session from the iOS keychain-backed client.
2. Read `account_snapshot` for the current user.
3. Fetch `training_profiles`; if missing, create a default row for the authenticated user.
4. If `account_snapshot.onboarding_completed_at` is null, show onboarding before the normal home surface.
5. Treat `account_tier in ('PREMIUM', 'FREE_PREMIUM')` as premium.
6. Treat `is_developer = true` as the switch for dev-only UI.
7. If onboarding is complete but the account is not premium/free-premium/developer, show the hard RevenueCat paywall.
8. Keep App Store subscription state synced to `account_entitlements` through `/api/revenuecat/refresh` and the RevenueCat webhook.

Workout data bootstrap must be bidirectional. On sign-in/session restore, iOS first uploads local pending rows for the account-scoped SQLite store, then pulls Supabase `workout_notes`, `daily_workout_metrics`, `strength_entries`, `cardio_entries`, `workout_prs`, `health_daily_metrics`, and `health_workout_matches` back into SQLite. This is required so a fresh install signed into the same account has notes, goal settings, calendar markers, stats, history, and suggestions context.

Encrypted note bodies are decrypted on-device before import when the local/iCloud Keychain note-body key is available. New keys are stored as iCloud-Keychain-syncable items so future same-Apple-ID devices can restore note bodies without Bram storing the plaintext or decryption key in Supabase. If the key is not available on a device, derived metrics can still sync because structured workout rows remain queryable, but the encrypted raw note body cannot be recovered by Bram admins.
9. Use server grants only through the admin route; iOS never writes entitlement or grant tables.
9. Upload pending local workout notes and derived account data after bootstrap and after note saves.

Do not let the SwiftUI client update `account_entitlements` directly.

Local SQLite data is scoped by Supabase user UUID. The app opens an account-specific database after authentication, so notes, onboarding drafts, goals settings, Health summaries, and derived metrics from one signed-in account do not appear under another account on the same device.

## Account Deletion

The iOS Settings delete action calls `POST /api/account/delete` with the current Supabase bearer token. The website validates the token with Supabase Auth, then uses the service-role key server-side to delete only that authenticated `auth.users` row. User-owned public tables reference `auth.users(id) on delete cascade`, so profile, entitlement, subscription event, workout, goal, and Health-derived rows are removed by the database. Waitlist founder redemption links use `on delete set null`.

After the server confirms deletion, iOS clears the current account-scoped SQLite database and signs out locally. The service-role key stays server-only and is never shipped in the app.

## Workout Sync

Bram's workout log is local-first. SQLite remains the immediate write path for the note editor, parser output, charts, Health-derived summaries, and settings-driven goals. Once the user is authenticated, the iOS app uploads pending user-owned workout data to Supabase:

- `workout_notes`
- `strength_entries`
- `cardio_entries`
- `daily_workout_metrics`
- `workout_prs`
- `health_daily_metrics`
- `health_workout_matches`

The upload path is triggered at account bootstrap and after note saves. Empty local placeholder notes are not uploaded. The client writes only rows owned by the authenticated user under RLS, using the publishable Supabase key.

For V1, free-text workout note bodies are encrypted on-device before upload. `workout_notes.body` is a legacy/plaintext compatibility column and V1 clients write an empty string there. The encrypted body package is stored in `workout_notes.body_ciphertext` with `body_nonce`, `body_key_version`, and `body_encryption_alg`. The encryption key is generated per Supabase user UUID and stored in the iOS Keychain with this-device-only accessibility; the key is not stored in Supabase and is removed from the device after account deletion.

Derived workout data remains plaintext and queryable in Supabase: sets, reps, cardio summaries, PRs, daily metrics, and Health-derived summaries. This keeps charts, entitlement-gated features, and future server-side summaries possible without exposing raw free-text note bodies to database admins or service-role tooling.

Not yet implemented: remote-to-local restore/merge for a new device, syncing standalone Health workout samples, syncing interpreted line rows into `workout_note_lines`, and server-generated exercise history summaries. Those should remain local-first until the conflict model is explicit.

Every user-owned table must use RLS with `auth.uid()` and indexes on foreign keys used by RLS. The SwiftUI client must not write `account_entitlements`, server-only AI usage rows, or any service-role-only table.

See `docs/workout-data-architecture.md` for the local-first SQLite shape and the Supabase table contract.
