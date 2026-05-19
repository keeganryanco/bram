# Bram Workout Data Architecture

## Intent

The app is local-first. A workout note must feel as reliable as Notes: typing saves silently on device, then syncs to Supabase once account sync is wired.

## Local Store

iOS uses SQLite first for explicit sync control. Every note stores:

- local ID
- future remote ID
- optional user ID
- workout date
- timezone
- raw note body
- created/updated/deleted timestamps
- sync state
- last sync error

The local store now persists the raw note plus derived structured rows:

- `workout_daily_metrics`
- `workout_strength_sets`
- `workout_cardio_entries`
- `workout_pr_events`
- `health_daily_metrics`
- `health_workout_samples`
- `health_workout_matches`

The app still re-renders inline interpretation from the note body, but calendar markers and progress stats should read from the structured SQLite tables. This keeps the UI local-first while creating a clean bridge to the future Supabase tables.

Progress stats derive from local structured rows:

- muscle set volume uses deterministic exercise-to-muscle mapping and should prefer useful subgroups over broad buckets when obvious, such as biceps, triceps, forearms, shoulders, abs, chest, back, and legs.
- cardio entries store activity type, duration, distance, unit, source line, and optional session label so runs, rides, walks, rows, and other cardio can contribute to daily stats and future Health matching.
- bodyweight trend combines Apple Health bodyweight samples with the latest Goals/profile bodyweight value.
- streak repairs count single missed-day gaps between logged workout days. Weekly consistency should use the user's weekly target from Goals.

## Interpretation Shape

Bram should not display AI as the product. Interpretation should attach to the note itself through tappable exercise names, quiet badges, and compact metrics.

Normal app UI should not show confidence meters. Apple Health workout matching may use match confidence internally, but any user-facing wording should be plain language such as `strong match`, `possible match`, or `manual match`.

The model boundary is structured:

- interpreted note line segments
- interpreted note lines
- same-day workout session boundaries
- normalized exercises
- user exercise aliases
- strength entries
- cardio entries
- daily workout aggregates
- PR events
- exercise history summaries
- Apple Health daily metrics
- Apple Health workout matches
- suggestions
- AI usage metadata

## Supabase Shape

The migration `20260507120000_workout_data_foundation.sql` adds user-owned workout tables for the future sync layer:

- `training_profiles`
- `exercise_catalog`
- `user_exercise_aliases`
- `workout_notes`
- `workout_note_lines`
- `strength_entries`
- `cardio_entries`
- `daily_workout_metrics`
- `workout_prs`
- `exercise_history_summaries`
- `health_daily_metrics`
- `health_workout_matches`
- `suggestions`
- `ai_usage_events`

The migration `20260512160000_cardio_sessions_shape.sql` extends `cardio_entries` with session/source metadata so cardio can be linked to the correct workout segment on days with more than one workout.

All tables use RLS with `auth.uid() = user_id`. Normal workout rows may eventually be written directly by the authenticated iOS client. Entitlements and subscription state remain admin/server managed.

Exercise matching uses a hybrid path:

- deterministic cleanup first
- user-owned aliases next
- backend AI interpretation only for workout-like lines that local parsing leaves unresolved

The first PR rule uses Epley estimated 1RM:

`estimated1RM = load * (1 + reps / 30)`

Cardio parsing uses the same layered rule. Local parsing should catch obvious text immediately, including distance-only entries like `1 mile run` and combined duration/distance notes like `15 min jog 1 mile`. The AI background pass should handle ambiguous cases, multiple workouts logged together, and after-the-fact notes where the local duration estimate may be weak.

## Apple Health Local Foundation

Apple Health is read-only in the first implementation. The iOS app stores imported Health summaries locally before any Supabase sync work:

- `HealthDailyMetric`: active energy, average/max heart rate, bodyweight, workout minutes, source timestamp.
- `HealthWorkoutSample`: HealthKit UUID, activity type, start/end, duration, active energy, distance, heart rate.
- `HealthWorkoutMatch`: Bram note ID/date, Health workout ID, and user-facing match quality: `strong match`, `possible match`, or `manual match`.

Matching stays local first. It uses calendar day, note update time proximity, workout duration, cardio type/distance hints, and activity type. The app should not show confidence percentages in normal UI.

Energy is the primary visible workout-load metric. Source priority:

1. Matched Health workout energy.
2. Health daily active energy.
3. Local MET estimate using duration, workout type/cardio cues, and Goals bodyweight.
4. Generic 180 lb / 82 kg fallback if bodyweight is missing.

Duration is resolved before local energy estimation. Source priority:

1. Matched Health workout duration.
2. Health daily workout duration.
3. Plausible in-app tracking window from note creation to latest edit.
4. Explicit parsed cardio duration.
5. Local estimate from set count and the user's typical session length.

The in-app tracking window is used only when it looks like live logging. Implausibly short windows, such as a pasted workout entered in about a minute, are ignored and estimated from the workout contents instead. Future AI should classify live logging versus after-the-fact logging for ambiguous notes.

Estimated values must be labeled `est.`. Strength volume remains stored for PR/history and chart details, but it is not the primary visible load number.

## Premium Boundary

Free users get the notes log. Premium or trial users get interpretation, stats, Apple Health, suggestions, weekly reviews, and progress history.

Apple Health permissions should be requested only after trial/premium starts or when the user explicitly opens a Health-backed premium feature.

## Privacy Rules

- Do not send raw note bodies to PostHog, TikTok, RevenueCat, or ad platforms.
- Do not store raw notes in `ai_usage_events`.
- Do not expose OpenAI keys or Supabase service-role keys in iOS.
- AI endpoints must be authenticated and rate-limit-ready before production use.
