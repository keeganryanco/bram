# Bram Privacy Data Map

## Data Categories

- Waitlist email: Supabase, Resend.
- Account info: Supabase Auth, `profiles`, `account_entitlements`.
- Purchases: RevenueCat, App Store.
- Product analytics: PostHog.
- Workout notes: Supabase user-owned tables.
- Parsed workouts: Supabase user-owned tables.
- Goals/profile context: primary training goal, weekly target, session length, training styles, equipment context, body basics, preferred units, and optional calorie estimate.
- Apple Health data: workouts, active energy, heart rate, distance, duration, and bodyweight when the user connects Health.
- AI processing: OpenAI Platform or selected model provider.
- Support messages: support inbox.

## Commitments

- Bram does not sell workout data.
- Bram does not use workout notes for advertising.
- Analytics must not include raw workout notes.
- Analytics must not include raw goals/profile freeform text, body measurements, target weight, sex, or calorie estimates.
- Onboarding body basics and goal settings are private account data in Supabase `profiles` and `training_profiles`. Product analytics may record completion or coarse UI actions, but not raw measurements, sex, calorie estimates, target weight, or freeform self-description.
- HealthKit data must not be used for advertising, marketing, analytics profiling, or ad attribution.
- Analytics must not include raw Health samples, heart-rate values, bodyweight values, distances, or Health workout identifiers.
- User-owned tables must use Supabase RLS.
- App must provide deletion and export paths before App Store submission.
- Entitlement/admin flags must be service-role managed, not user editable.

## App Store Copy Anchor

Bram uses your workout notes to structure your training history, generate progress insights, and provide suggestions. We do not sell workout data or use it for ads.

Bram uses Goals data to personalize progress framing, streak interpretation, and future suggestions. Goals/profile data is private account context and should not be sent to ad platforms or product analytics as raw user-entered data.

Bram uses Apple Health only after the user explicitly connects it. Health data powers energy, heart rate, duration, cardio distance, bodyweight context, and workout-note matching. Health data is private account data and must not be sent to advertising platforms or product analytics as raw values.
