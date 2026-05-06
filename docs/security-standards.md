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
- No names/emails in AI calls.
- Do not log request bodies for workout-note routes.

## Legal/Privacy

Privacy and terms pages live at `/privacy` and `/terms`. Support contact is `support@trybram.app`.
