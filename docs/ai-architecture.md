# Bram AI Architecture

## Role

AI is an invisible interpretation layer. Bram should not feel like an AI chat product.

## Output Shapes

AI outputs must be one of:

- structured workout summary
- structured note line segments
- same-day workout session boundaries
- exercise normalization suggestion
- cardio entry interpretation
- one-line suggestion
- weekly plain-language insight
- progression recommendation
- recovery adjustment
- exercise-history explanation

No long paragraphs. No generic coaching essays. No motivational slop.

## Privacy Rules

- Use pseudonymous user/session IDs in model calls.
- Do not send name or email to AI providers.
- Minimize note context to the task.
- Store raw notes separately from identity metadata where practical.
- Keep prompts in `prompts/` and update them when behavior changes.
- Never expose OpenAI keys to SwiftUI or browser clients.
- Do not log raw workout-note request bodies.
- Do not show model confidence in normal app UI.

## Model Routing

- Note parsing: `BRAM_AI_FAST_MODEL`.
- Exercise normalization: `BRAM_AI_FAST_MODEL` plus deterministic mapping.
- Inline suggestion: `BRAM_AI_FAST_MODEL`.
- Weekly review: `BRAM_AI_STRONG_MODEL`.
- Onboarding training profile: `BRAM_AI_STRONG_MODEL`.
- Explicit complex user request: `BRAM_AI_PREMIUM_MODEL`, only when paid/eligible.

The default model names are configured in `apps/web/src/lib/ai/config.ts`, not hardcoded into feature code. The current planned defaults are:

| Variable | Default | Use |
| --- | --- | --- |
| `BRAM_AI_FAST_MODEL` | `gpt-5.4-mini` | parsing, normalization, one-line suggestions |
| `BRAM_AI_STRONG_MODEL` | `gpt-5.4` | weekly review and onboarding profile synthesis |
| `BRAM_AI_PREMIUM_MODEL` | `gpt-5.5` | explicit complex training-history questions |

## Server Architecture

The web app owns the server-side OpenAI boundary under `apps/web/src/lib/ai/`.

| File | Purpose |
| --- | --- |
| `config.ts` | Reads and validates server-only AI environment variables. |
| `client.ts` | Creates the OpenAI SDK client only after runtime config is valid. |
| `requests.ts` | Builds task-specific Responses API request payloads and selects the model tier. |
| `schemas.ts` | Defines Zod contracts for parsed workouts, suggestions, weekly reviews, and onboarding profiles. |
| `privacy.ts` | Redacts direct identifiers and creates pseudonymous user IDs. |
| `prompts.ts` | Keeps the implementation prompts aligned with `prompts/`. |

Do not add unauthenticated public AI API routes. iOS should eventually call authenticated Bram backend endpoints, and those endpoints should:

1. Load the authenticated Supabase user.
2. Create a pseudonymous AI user ID using `BRAM_AI_PSEUDONYM_SALT`.
3. Fetch only the workout context required for the task.
4. Sanitize direct identifiers before building the AI request.
5. Enforce per-user rate and budget limits before calling OpenAI.
6. Persist the structured output to user-owned Supabase tables.
7. Log only metadata: task, model, latency, token usage, success/failure, and pseudonymous IDs.

Exercise matching should stay hybrid. Deterministic normalization and user aliases run first; AI should propose canonical matches or alias merges only when the app cannot confidently resolve a name locally.

## Interpretation Layers

Bram should use layered interpretation instead of relying on one parser:

1. **Instant heuristic draft:** runs locally while the user types so obvious exercise anchors, sets, PR badges, and simple metrics appear quickly.
2. **AI background pass:** runs through authenticated server endpoints for unresolved, ambiguous, or freeform notes. It returns structured data only and may improve exercise matching, set parsing, supersets, cardio, and training context.
3. **User correction layer (TBD):** lets the user fix an exercise match, alias, set interpretation, or superset grouping once. Corrections should create user-owned aliases/rules so Bram remembers them.

The correction layer is not a chat surface. It should feel like quietly fixing the notebook.

## MVP Interpretation Requirements

The MVP must handle both strength and cardio notes. Local interpretation should already catch common cardio like `1 mile run`, `ran 5k`, `bike 20 min`, `walk 30 minutes`, and distance-only entries. When duration is missing, Bram may estimate a conservative duration for energy calculations until Apple Health or AI context improves it.

Same-day workouts should be represented explicitly. If a user writes headings such as `Morning run` and `Evening lift`, the parser should keep the cardio and strength work attached to separate session segments for future Health matching and progress details. This does not require extra UI chrome on the note surface.

The backend AI parser contract includes:

- `sessions`: coarse workout segments for the same calendar day
- `cardioEntries`: activity type, duration, distance, unit, optional pace, session index, and source line
- `exercises`: normalized strength/bodyweight exercise blocks
- `lines`: display-safe note segments for anchors, badges, and compact metrics

AI should resolve ambiguity the local parser cannot, especially unclear cardio wording, mixed cardio/strength days, freeform equipment/readiness constraints, and multiple workouts logged after the fact. It should still return structured JSON, not prose.

## Suggestion Context

Suggestion calls should be grounded in structured context, not generic model intuition. The iOS app should build a privacy-safe context from local data before calling the backend: current workout metrics, muscle set volume, exercise history summaries, cardio history summaries, Goals categories, readiness/equipment/time hints, and categorical feedback. The backend schema should remain typed and should reject loose raw-note payloads for suggestions.

Visible suggestions should stay as category-labeled cards. Auto-inserted `Bram:` note text is disabled for now; if it returns later, it must be rare, editable, and feedback-gated.

## Runtime Guardrails

- `BRAM_AI_ENABLED` defaults to `false`.
- `OPENAI_API_KEY` is required only when AI is enabled.
- `BRAM_AI_PSEUDONYM_SALT` is required only when AI is enabled.
- `BRAM_AI_ROUTE_TOKEN` temporarily protects the AI interpretation endpoint until Supabase Auth is wired into iOS.
- `BRAM_AI_MAX_NOTE_CHARS` caps raw note context before model calls.
- `BRAM_AI_DAILY_USER_REQUEST_LIMIT` and `BRAM_AI_MONTHLY_ACTIVE_USER_BUDGET_CENTS` are policy values for the production rate-limit table.
- `BRAM_AI_PROMO_FOUNDER_SOFT_CAP_CENTS` defaults to `50`; founder/manual free-premium users downgrade to the fast model after this monthly estimated spend.
- `BRAM_AI_PROMO_FOUNDER_HARD_CAP_CENTS` defaults to `200`; founder/manual free-premium users are blocked from premium AI after this monthly estimated spend.

## Cost Controls

The target remains `$0.20-$0.40` per active paid user per month. Keep most work on the fast model and reserve stronger models for weekly synthesis, onboarding, and explicit paid-user questions.

Supabase AI usage tables track:

- pseudonymous user ID
- task
- model
- request count
- estimated input/output tokens
- estimated cents
- day and month buckets

The usage ledger stores metadata only. It must not store raw workout notes, prompt bodies, names, or emails.

## OpenAI Data Handling

OpenAI states that API data is not used to train or improve models by default unless explicitly opted in, and abuse-monitoring logs may be retained for up to 30 days by default. Bram should still minimize workout-note context because the notes are private training data.
