# Bram Analytics Plan

## North Star

Weekly active workout note writers.

## Events

- `app_opened`
- `session_restored`
- `auth_succeeded`
- `auth_failed`
- `onboarding_started`
- `onboarding_step_viewed`
- `onboarding_step_completed`
- `onboarding_completed`
- `home_note_focused`
- `calendar_opened`
- `stats_opened`
- `settings_opened`
- `support_opened`
- `support_submitted`
- `crash_support_prompt_dismissed`
- `crash_support_submitted`
- `first_note_started`
- `note_saved`
- `note_parsed`
- `parse_edited`
- `nonfatal_error`
- `suggestion_viewed`
- `suggestion_accepted`
- `weekly_review_opened`
- `dashboard_opened`
- `paywall_viewed`
- `review_prompt_viewed`
- `review_prompt_accepted`
- `review_prompt_deferred`
- `review_prompt_disabled`
- `workout_reminders_permission_set`
- `trial_started`
- `subscription_started`
- `waitlist_joined`

## Privacy Standard

Never send raw workout note bodies, health notes, injury descriptions, or freeform user-entered training text to PostHog or other analytics systems.

Do not send raw Goals/profile values such as bodyweight, target weight, height, sex, self-description, calorie estimate, or freeform goal text to analytics. Product events may use coarse non-sensitive categories only when needed, such as `goals_saved` or `weekly_target_set`, without measurements or note content.

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
- PostHog iOS uses Supabase `user_id` as the identified user ID. Do not send email, name, raw Health values, body measurements, workout note bodies, or support message bodies to PostHog.
- PostHog exception autocapture is enabled for fatal crashes. Handled errors are captured as `nonfatal_error` with source/event metadata only.
- Supabase owns authenticated support and diagnostic intake through service-role-only `support_requests` and `app_error_reports` tables. Support messages are intentionally readable by Bram support; they are not workout note sync storage.
- iOS keeps a short local diagnostic event trail for support and crash follow-up prompts. Recent logs include event names and safe properties only, not workout note text or Health/body values.
- Linear issue creation is server-side only and optional. The support API mirrors requests into Linear when `LINEAR_API_KEY`, `LINEAR_TEAM_ID`, and optional support project/labels are configured.
- RevenueCat owns subscription analytics and custom native paywall impressions. Bram tracks impressions through RevenueCat's custom paywall impression API because the paywall UI is not RevenueCat-hosted.
- Apple Search Ads should be evaluated after App Store listing readiness.
- TikTok ads should wait until organic creative and conversion signals exist.

## Allowed iOS Analytics Properties

Allowed:

- account/subscription category: `account_tier`, `subscription_status`, `is_developer`
- onboarding step identifiers
- coarse choices: `primary_goal`, `unit_preference`, count buckets, boolean flags
- note metadata buckets: note length bucket, parsed exercise/set/cardio buckets, `has_pr`
- error metadata: feature source, internal event name, non-sensitive status/category

Not allowed:

- raw workout note text or interpreted line text
- raw bodyweight, target weight, height, calories, heart rate, distance, Health workout identifiers, or injury/medical notes
- first name, email address, support message text, or freeform user-entered training context
