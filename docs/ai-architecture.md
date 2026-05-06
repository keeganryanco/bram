# Bram AI Architecture

## Role

AI is an invisible interpretation layer. Bram should not feel like an AI chat product.

## Output Shapes

AI outputs must be one of:

- structured workout summary
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

## Runtime Guardrails

- `BRAM_AI_ENABLED` defaults to `false`.
- `OPENAI_API_KEY` is required only when AI is enabled.
- `BRAM_AI_PSEUDONYM_SALT` is required only when AI is enabled.
- `BRAM_AI_MAX_NOTE_CHARS` caps raw note context before model calls.
- `BRAM_AI_DAILY_USER_REQUEST_LIMIT` and `BRAM_AI_MONTHLY_ACTIVE_USER_BUDGET_CENTS` are policy values for the future rate-limit table.

## Cost Controls

The target remains `$0.20-$0.40` per active paid user per month. Keep most work on the fast model and reserve stronger models for weekly synthesis, onboarding, and explicit paid-user questions.

Future Supabase rate-limit tables should track:

- pseudonymous user ID
- task
- model
- request count
- estimated input/output tokens
- estimated cents
- day and month buckets

## OpenAI Data Handling

OpenAI states that API data is not used to train or improve models by default unless explicitly opted in, and abuse-monitoring logs may be retained for up to 30 days by default. Bram should still minimize workout-note context because the notes are private training data.
