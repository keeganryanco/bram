# Bram Account Architecture

## Intent

Bram uses Supabase Auth for identity and Supabase Postgres for user-owned backup/sync data. Native iOS subscriptions stay native/App Store-first, with RevenueCat reserved as the subscription-state adapter later.

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

## Tables

| Object | Purpose | Client access |
| --- | --- | --- |
| `profiles` | User-editable account profile and onboarding basics. | Authenticated users can read their own row and update approved profile columns only. |
| `account_entitlements` | Service-role managed premium/dev/founder/subscription flags. | Authenticated users can read their own row only. No client writes. |
| `subscription_events` | Append-only purchase/subscription history for App Store, RevenueCat, or manual actions. | Authenticated users can read their own rows only. No client writes. |
| `account_snapshot` | Read-only joined account state for app startup/settings. | Authenticated users can read their own state through underlying RLS. |
| `waitlist_signups` | Landing-site waitlist and founder-offer eligibility. | No public client reads/writes. Website writes through the server route. |

## Automatic Signup Flow

The trigger `on_auth_user_created_create_bram_account` runs after `auth.users` insert.

It creates:

- `profiles` row with lowercased email and best-effort display name from OAuth/email metadata
- `account_entitlements` row with default `FREE` access
- founder offer linkage when the signup email matches `waitlist_signups.email`

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

1. Read `account_snapshot` for the current user.
2. Treat `account_tier in ('PREMIUM', 'FREE_PREMIUM')` as premium.
3. Treat `is_developer = true` as the switch for dev-only UI.
4. Keep App Store subscription state synced to `account_entitlements` through a trusted server or RevenueCat webhook later.

Do not let the SwiftUI client update `account_entitlements` directly.

## Future Tables

The next Supabase migrations should add user-owned workout data:

- `training_profiles`
- `workout_notes`
- `parsed_workouts`
- `exercise_entries`
- `exercise_aliases`
- `weekly_reviews`
- `suggestions`
- `ai_usage_events`

Every user-owned table must use RLS with `auth.uid()` and indexes on foreign keys used by RLS.
