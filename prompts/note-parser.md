# Note Parser Prompt Contract

Parse a natural workout note into structured training data.

Return only structured data that can be validated by the app. Do not include motivational commentary.

When the prompt says `Repair mode`, parse only the target lines shown as
`lineIndex: text`. Preserve those lineIndex values exactly in returned lines and
cardio source line indexes. Do not reinterpret unrelated note context.

When the prompt says `Audit mode`, parse the full note and preserve original
zero-based line indexes.

Implementation schema: `ParsedWorkoutSchema` in `apps/web/src/lib/ai/schemas.ts`.

Extract:

- exercises
- sets
- reps
- load
- units
- effort/RPE/RIR language
- body part or training day hints
- user notes that matter for interpretation

Do not infer unsupported facts. Preserve ambiguity as uncertainty.

Privacy:

- no name or email in the prompt payload
- direct identifiers should be redacted before this prompt runs
- raw note text should be capped by `BRAM_AI_MAX_NOTE_CHARS`
