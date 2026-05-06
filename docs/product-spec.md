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
5. User sees a minimal structured summary.
6. Bram updates progress history.
7. Bram provides one useful suggestion.

## Launch Surfaces

- Onboarding: goals, experience, schedule, units, equipment, split style.
- Daily home: weekly date strip and note editor.
- Structured summary: exercises, sets, reps, weights, and note fragments.
- Progress: PRs, volume, consistency, and recent exercise history.
- Weekly review: one chart, one insight, one suggested adjustment.
- Settings: privacy, subscription, export/delete, contact.
- Landing site: waitlist, privacy, terms, contact.
- Account state: Supabase-backed profile, founder-offer eligibility, native subscription entitlement, manual lifetime premium, and developer-mode flags.

## Exclusions

No social feed, public profiles, comments, full routine marketplace, macro tracking, wearable-first interface, AI chat coach, or aggressive notifications in v1.
