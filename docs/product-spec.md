# Bram Product Spec

## Positioning

Bram is a notes-first strength tracker for lifters who already know how they train and want their workout notes to become progress history.

Primary public name: `Bram: Workout Notes`.

Core line: `Write your workout. Bram tracks the rest.`

## V1 Product Loop

1. User opens Bram.
2. Today is ready for writing.
3. User writes a natural workout note.
4. Bram parses exercises, sets, reps, load, effort, and training context.
5. Bram attaches quiet interpretation to the note with exercise anchors, PR badges, and compact metrics.
6. Bram updates progress history.
7. Bram provides one useful suggestion when it adds clarity.

Interpretation should be layered: local heuristics provide the immediate draft while typing, and the server AI pass resolves ambiguous/freeform notes in the background. A future correction layer should let users fix an exercise match or set interpretation once and have Bram remember it.

Suggestions should stay in calm category-labeled cards rather than being auto-inserted into the user's note. The home screen should show at most one daily suggestion, while exercise and cardio detail sheets can show more specific recommendations. Suggestion quality should come primarily from structured context: exercise history, current muscle volume, cardio, goals, readiness/equipment hints, and feedback signals.

For MVP readiness, Bram must understand cardio as first-class workout data, not as leftover text. Notes like `1 mile run`, `ran 5k`, `bike 20 min`, and `walk 30 minutes` should create cardio entries with activity type, distance or duration, and an estimated duration when Health data is unavailable. When a user logs more than one workout on the same day, headings such as `Morning run` and `Evening lift` should become quiet session boundaries so stats and future Apple Health matching can attach to the right workout.

## Launch Surfaces

- Onboarding: account creation, first name, primary goal, desired weekly training frequency, typical session length, training styles, equipment, preferred units, current weight, optional target weight, a quick note-parsing preview, baseline recap, and premium paywall.
- Daily home: weekly date strip and note editor.
- Inline interpretation: exercise anchors, PR badges, sets, cardio, Health-linked chips when they attach cleanly.
- Progress: PRs, weekly target completion, muscle set volume, bodyweight trend, consistency, streak repairs, and recent exercise history, with energy as supporting Health context.
- Weekly review: one chart, one insight, one suggested adjustment.
- Onboarding permissions: first-run onboarding asks for Apple Health and notifications near the end of setup, after the note-parsing preview and before the recap/paywall.
- Notifications: V1 uses local workout reminders only. Users opt in during onboarding or from Settings; after a workout-like note is saved, Bram schedules one contextual reminder based on recent progress and weekly training cadence. No push provider, server-side notification targeting, or AI-generated notification copy is required for V1.
- Settings: Goals, privacy, subscription, export/delete, contact.
- Landing site: waitlist, privacy, terms, contact.
- Account state: Supabase-backed profile, founder-offer eligibility, native subscription entitlement, one-month TestFlight/Product Hunt grants, manual lifetime premium, and developer-mode flags.
- Analytics and support: PostHog tracks onboarding, usage, paywall, and nonfatal error events under Supabase user ID only. Supabase stores authenticated support requests and app error reports in service-role-only tables, with optional server-side Linear issue mirroring. Analytics must use coarse event properties and never include raw workout notes, Health values, body measurements, support message bodies, or freeform training text.

## Exclusions

No social feed, public profiles, comments, full routine marketplace, macro tracking, wearable-first interface, AI chat coach, or aggressive notifications in v1.

## Goals Surface

Bram has one user-facing `Goals` surface in Settings. It combines training intent and light profile context so the app can personalize progress without feeling like a medical form.

The local-first Goals profile should include primary goal, weekly workout target, typical session length, training styles, equipment context, preferred units, height, current weight, optional target weight, optional sex, bodyweight source/logged timestamp, and optional daily calorie estimate. Supabase stores identity/body/unit fields in `profiles` and training intent/equipment fields in `training_profiles`.

First-run onboarding sets the baseline for Goals but is not the full Goals editor. It should feel like classic product onboarding: one action per screen, a fixed bottom continue control, motivating but specific copy, a fast moment showing that natural workout notes become structured progress, and then a hard premium gate. Settings keeps the fuller editable Goals surface, including advanced optional fields such as sex and daily calorie estimate.

Weekly consistency should eventually use the user's desired weekly workout target. Planned rest days should not feel like broken streaks; missing the intended weekly target is the meaningful consistency signal.

Streaks should be goal-aware, not only daily. A week is `on track` when the user hits their desired workout count with real workouts: recognizable lifting or cardio, not bodyweight-only notes. Daily streaks can still be shown as a fun secondary signal, but they should not punish planned rest days.

Awards should be simple progress markers that can later receive Rive animation treatment: weekly target hit, PRs, balanced muscle coverage, bodyweight check-ins, cardio consistency, and comeback/repair moments. Names should feel calm and branded, not noisy game mechanics.

## Progress

Progress should stay calm and glanceable. The main stats surface should prioritize:

- a progress-first top card with period PRs, workouts completed against the weekly target, progression trend, and set-volume change versus the prior comparable period
- muscle set volume defaulting to macro groups: arms, legs, chest, back, shoulders, and abs
- tap-to-expand detailed muscle groups such as biceps, triceps, forearms, quads, hamstrings, glutes, calves, lats, traps, rhomboids, erectors, shoulders, abs, and chest
- a quiet set-volume value toggle between set counts and percentages, independent from macro/detail grouping
- one period-level insight card that is specific and useful, not generic
- bodyweight trend against the user's optional target weight
- weekly target completion, calm streak awards, and simple streak repair state

Energy, duration, heart rate, and strength volume remain useful, but they should support the progress story in chart details and Health-backed context rather than become the headline concept. Muscle colors should be stable by group, with related shades for smaller subgroups. For example, biceps, triceps, and forearms may share a green family while remaining visually distinct. Streak repairs should repair single missed-day gaps between logged workouts; they should not turn planned rest days into failures.

## Apple Health

Apple Health is a premium/trial-backed surface. Bram must not request Health permissions on launch; the request should happen only when a user opens a Health-backed settings, stats, or onboarding surface.

The first Health implementation is read-only. Bram reads workouts, active energy, heart rate, distance, duration, and bodyweight to improve progress stats and match Health workouts to Bram notes. Energy is supporting workout-load context in Progress details. Strength volume stays available as secondary strength context in details and history.

HealthKit does not expose a reliable app-side read-permission status. Bram should remember that Health access was requested on-device, then verify connection by attempting read queries and handling empty results as `connected, no recent data` instead of a permission failure.

If Health energy is unavailable, Bram estimates energy locally from workout duration, cardio cues, bodyweight from Goals, and a generic fallback bodyweight. Estimated values must be labeled `est.` and must not be presented as medical-grade measurements.

Workout duration should be resolved from the best available source, not treated as one fixed estimate. Source priority is: matched Apple Health workout duration, Apple Health daily workout duration, plausible in-app tracking time from note creation to latest edit, explicit cardio duration, then a local set-count/session-length estimate. Implausibly short tracking windows, such as a pasted workout completed in about a minute, should fall back to estimated duration. Future AI should help classify whether the user logged live during the workout or entered the note afterward.

Bodyweight can update Goals from either Apple Health, workout notes, or manual settings. Bram should synthesize these into one current bodyweight using the newest known logged timestamp. Note-derived bodyweight should require explicit language like `body weight 162 lb`, `162 lbs current weight`, or a standalone weight close to the user's existing bodyweight, so exercise loads are not mistaken for profile data. Apple Health bodyweight should update the current value when its logged date is newer, but it should not overwrite a same-day manual/settings value that has a later timestamp.

Auto-logging or inserting Health-derived text into the note is a future feature. This pass should not edit user-authored notes automatically.
