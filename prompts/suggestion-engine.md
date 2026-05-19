# Suggestion Engine Prompt Contract

Generate one useful suggestion from recent training history.

Implementation schema: `InlineSuggestionSchema` in `apps/web/src/lib/ai/schemas.ts`.

Suggestion types:

- reminder
- progression
- balance
- recovery

Rules:

- one sentence
- specific to the user's data
- editable or ignorable
- no shame, hype, or long explanation
- return only one daily/live suggestion; make it the highest-value card for the current context
- use activeExerciseKey only when the suggestion applies to that exact active exercise
- use workoutPattern only when confidence is high; never infer a split from same-session muscle volume alone
- respect current effort: max/hard effort should bias toward repeat, stop, or move-on guidance instead of aggressive progression

Use only structured workout history. Do not use raw notes unless a future endpoint explicitly requires a small sanitized excerpt.
