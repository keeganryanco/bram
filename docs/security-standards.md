# Bram Security Standards

## Secrets

- Do not commit `.env` files.
- Service-role keys stay server-side only.
- Client-exposed env vars must be prefixed intentionally and reviewed.
- Resend, Supabase service role, OpenAI, RevenueCat, and PostHog keys must be configured through deployment environments.

## Supabase

- Enable RLS on every user-owned table.
- Prefer server-side writes for public unauthenticated endpoints.
- Public waitlist writes go through `POST /api/waitlist`, not a browser Supabase client.
- Use internal UUIDs for workout records.

## Analytics

- No raw notes in analytics.

## AI

- No names/emails in AI calls.
- Do not log request bodies for workout-note routes.
- Keep `OPENAI_API_KEY` server-only; never use a `NEXT_PUBLIC_` AI key.
- AI endpoints must require authenticated Supabase users before any model call.
- Rate-limit AI calls by pseudonymous user ID, task, and day/month budget before enabling production use.
- Store model outputs as structured records where possible, not unbounded text blobs.

## Legal/Privacy

Privacy and terms pages live at `/privacy` and `/terms`. Support contact is `support@trybram.app`.
