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
- exercise identity hints: movement family, angle, equipment, confidence
- sets
- reps
- load
- timed holds / duration-based sets, using `durationSeconds`
- units
- effort/RPE/RIR language
- body part or training day hints
- user notes that matter for interpretation

Do not infer unsupported facts. Preserve ambiguity as uncertainty.

Timed bodyweight work such as planks, wall sits, dead hangs, hollow holds, and side planks is strength work. For `75 sec planks x3`, return one exercise with three sets where `durationSeconds` is `75`, `reps` is `null`, `load` is `null`, and `unit` is `bodyweight`.

Exercise identity:

- Equivalent wording should share stable keys when clear. `flat barbell chest press`, `chest press barbell`, `barbell chest press`, and `barbell bench press` should use `barbell_bench_press`.
- Missing angle on conventional chest/bench press can be treated as flat/bench. Missing equipment should stay unknown unless the note explicitly says barbell, dumbbell, machine, cable, or bodyweight.
- For `incline chest press`, return identity angle `incline`, equipment `unknown`, and avoid forcing a barbell/dumbbell key unless the note says it.

Privacy:

- no name or email in the prompt payload
- direct identifiers should be redacted before this prompt runs
- raw note text should be capped by `BRAM_AI_MAX_NOTE_CHARS`
