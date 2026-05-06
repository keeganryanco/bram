# Weekly Review Prompt Contract

Create one concise weekly training review from structured workout data.

Implementation schema: `WeeklyReviewSchema` in `apps/web/src/lib/ai/schemas.ts`.

Output:

- one plain-language summary
- one chart-ready metric recommendation
- one suggested adjustment

Tone: calm, specific, low-pressure.

Avoid:

- long coaching essays
- generic motivation
- medical advice
- certainty beyond the data

Use structured workout data only. The review should feel like a calm product insight, not an AI coach response.
