# Bram Privacy Data Map

## Data Categories

- Waitlist email: Supabase, Resend.
- Account info: Supabase Auth, `profiles`, `account_entitlements`.
- Purchases: RevenueCat, App Store.
- Product analytics: PostHog, identified by Supabase user ID only.
- Paid acquisition measurement: TikTok App Events / Events API, identified by install/app signals and pseudonymous Supabase user ID only.
- Workout notes: local SQLite and Supabase user-owned tables. Raw free-text note bodies are encrypted on-device before Supabase upload.
- Parsed workouts: Supabase user-owned tables.
- Goals/profile context: primary training goal, weekly target, session length, training styles, equipment context, body basics, preferred units, and optional calorie estimate.
- Apple Health data: workouts, active energy, heart rate, distance, duration, and bodyweight when the user connects Health.
- AI processing: OpenAI Platform or selected model provider.
- Support messages: Supabase service-role-only support inbox, optionally mirrored to Linear.
- Diagnostics: PostHog fatal exception events, service-role-only Supabase app error reports, and optional Linear support issues.

## Commitments

- Bram does not sell workout data.
- Bram does not use workout notes for advertising.
- Analytics must not include raw workout notes.
- Ad attribution must not include raw workout notes, Health data, body measurements, support messages, email, first name, or freeform user-entered training text.
- Supabase workout tables must store notes under `user_id` only and must not duplicate direct identity fields such as email or display name.
- Free-text workout note bodies are highly sensitive private data. V1 clients encrypt note bodies before Supabase upload and keep derived workout metrics queryable separately.
- Analytics must not include raw goals/profile freeform text, body measurements, target weight, sex, or calorie estimates.
- Onboarding body basics and goal settings are private account data in Supabase `profiles` and `training_profiles`. Product analytics may record completion or coarse UI actions, but not raw measurements, sex, calorie estimates, target weight, or freeform self-description.
- HealthKit data must not be used for advertising, marketing, analytics profiling, or ad attribution.
- Analytics must not include raw Health samples, heart-rate values, bodyweight values, distances, or Health workout identifiers.
- Analytics and error reports must not include raw workout notes, support message bodies, Health samples, body measurements, or freeform user-entered training text.
- Support requests are user-submitted customer support content and may be linked to account email so Bram can reply.
- User-owned tables must use Supabase RLS.
- App must provide deletion and export paths before App Store submission.
- Entitlement/admin flags must be service-role managed, not user editable.
- RevenueCat purchase state may be linked to the Supabase user ID for entitlement sync. The app must not write entitlement flags directly; webhook/server refresh routes update Supabase with service-role privileges.

## App Store Copy Anchor

Bram uses your workout notes to structure your training history, generate progress insights, and provide suggestions. We do not sell workout data or use it for ads.

Bram uses Goals data to personalize progress framing, streak interpretation, and future suggestions. Goals/profile data is private account context and should not be sent to ad platforms or product analytics as raw user-entered data.

Bram uses Apple Health only after the user explicitly connects it. Health data powers energy, heart rate, duration, cardio distance, bodyweight context, and workout-note matching. Health data is private account data and must not be sent to advertising platforms or product analytics as raw values.

## App Store Privacy Label Guidance

For App Store Connect, treat app analytics as linked to identity once PostHog identifies by Supabase user ID. User ID, Device ID, Product Interaction, Crash Data, and Performance Data should be marked linked to the user and used for Analytics/App Functionality.

Health and Fitness data should not be marked as used for advertising or marketing. If Bram only stores Health/Fitness values for app functionality and never sends raw Health/Fitness values to analytics, list Health and Fitness as App Functionality. Because those records are stored under the user's account, assume linked to identity unless Apple confirms the client-side encryption model qualifies as de-identified before collection.

Name and Email should be linked to identity. Name is used for App Functionality unless Bram uses it in lifecycle marketing or analytics. Email is used for App Functionality and customer communication; mark Developer's Advertising or Marketing only if Bram sends promotional email or marketing campaigns to app account emails.

Customer Support is linked to identity and used for App Functionality. Mark Analytics only if support categories/messages are analyzed for product analytics; do not send support message bodies to PostHog.
