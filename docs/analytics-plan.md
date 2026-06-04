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
- `onboarding_permission_set`
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
- TikTok App Events is prepared for paid acquisition. The iOS app initializes TikTok's App Events SDK from the website runtime config endpoint only when Vercel TikTok env vars are present, so installs and in-app conversion signals can be attributed in TikTok Events Manager after ads setup.
- RevenueCat webhooks mirror trial starts, paid subscription starts, and subscription renewals to TikTok Events API when TikTok server env vars are present. This keeps recurring subscription conversion signals flowing even when the app is not open.
- TikTok receives only funnel and subscription event metadata. Do not send raw workout notes, Health data, body measurements, email, first name, support messages, or freeform onboarding/profile text to TikTok.

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

## Onboarding A/B Measurement

Experiment key: `onboarding_fitbod_v1`

Variants:

- `a`: current Bram onboarding.
- `b`: lean story onboarding that pulls note-to-progress value forward before the paywall.

PostHog setup:

1. Create a funnel:
   - `auth_succeeded`
   - `onboarding_started`
   - `onboarding_completed`
   - `paywall_viewed`
   - `purchase_started`
   - `subscription_access_confirmed`
2. Add breakdown: `onboarding_variant`.
3. Add filter: `onboarding_experiment_key = onboarding_fitbod_v1`.
4. Review conversion windows:
   - same day
   - 7 days
   - 30 days

Step dropoff insight:

- Event: `onboarding_step_viewed`
- Group by: `step_key`
- Breakdown: `onboarding_variant`
- Pair with `onboarding_step_completed` grouped by `step_key` to identify the step where each variant stalls.

Rageclick/context review:

- Use PostHog rageclick/session events only as UI friction signals.
- Cross-reference by `onboarding_variant` and nearby `step_key`.
- Do not add raw onboarding text, raw body values, Health values, or workout note text to analytics for debugging.

## TikTok Ads Measurement

TikTok event mapping:

- iOS SDK automatic events: install and app launch, owned by TikTok App Events SDK.
- `onboarding_completed` -> TikTok `CompleteTutorial`.
- `subscription_access_confirmed` with `subscription_status = TRIAL` -> TikTok `StartTrial`.
- `subscription_access_confirmed` with `subscription_status = ACTIVE` -> TikTok `Subscribe`.
- RevenueCat webhook `INITIAL_PURCHASE` with `period_type = TRIAL` -> TikTok `StartTrial`.
- RevenueCat webhook `INITIAL_PURCHASE`, `NON_RENEWING_PURCHASE`, or `RENEWAL` outside trial -> TikTok `Subscribe`.

Attribution notes:

- The TikTok iOS SDK is the install-attribution path. A Vercel-only server event cannot prove that an App Store install came from a TikTok ad.
- Server-side RevenueCat events use the Supabase user UUID as a pseudonymous external ID, hashed before leaving Vercel.
- The iOS SDK identifies with the same hashed Supabase user UUID used by server-side RevenueCat events. No email, name, phone, workout, Health, support, or body/profile measurement data is sent.
