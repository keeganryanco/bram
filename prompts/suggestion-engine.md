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

Use only structured workout history. Do not use raw notes unless a future endpoint explicitly requires a small sanitized excerpt.
