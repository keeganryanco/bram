# Bram Analytics Plan

## North Star

Weekly active workout note writers.

## Events

- `app_opened`
- `onboarding_started`
- `onboarding_completed`
- `home_note_focused`
- `calendar_opened`
- `stats_opened`
- `settings_opened`
- `first_note_started`
- `note_saved`
- `note_parsed`
- `parse_edited`
- `suggestion_viewed`
- `suggestion_accepted`
- `weekly_review_opened`
- `dashboard_opened`
- `paywall_viewed`
- `trial_started`
- `subscription_started`
- `waitlist_joined`

## Privacy Standard

Never send raw workout note bodies, health notes, injury descriptions, or freeform user-entered training text to PostHog or other analytics systems.

Allowed event properties should be categorical or numeric, such as:

- source
- platform
- parse_success
- exercise_count
- set_count
- unit_preference
- subscription_status

## Growth Integrations

- PostHog owns product analytics only; never send raw workout note bodies.
- RevenueCat will own subscription/paywall metrics once trusted integration is wired.
- Apple Search Ads should be evaluated after App Store listing readiness.
- TikTok ads should wait until organic creative and conversion signals exist.
