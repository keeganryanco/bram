# Bram Deployment Plan

## Website

Framework: Next.js App Router under `apps/web`.

Production target: `https://www.trybram.app`, with `https://trybram.app` redirecting to the `www` host.

Vercel project:

- Project: `keegan-ryans-projects/bram`
- Framework preset: Next.js
- Root directory: `apps/web`
- Output directory: Next.js default
- Latest deployment: `https://bram-ipe2z8gtm-keegan-ryans-projects.vercel.app`
- Inspector: `https://vercel.com/keegan-ryans-projects/bram/FLCN1np21G6eYvMHxz36FtS1roDN`
- Deployment protection: generated Vercel URLs may require Vercel login, but the custom domain is public.

Deploy with:

```bash
pnpm build
pnpm vercel:deploy
```

The repo does not require a global Vercel CLI. The script uses `npx vercel` from the repository root and relies on the `bram` project Root Directory setting.

## Required Vercel Environment Variables

Waitlist:

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RESEND_API_KEY` or `RESEND_API`
- `RESEND_FROM_EMAIL`
- `WAITLIST_NOTIFY_EMAIL` optional
- `NEXT_PUBLIC_SITE_URL`

Current status: production has `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API`, `RESEND_FROM_EMAIL`, and `NEXT_PUBLIC_SITE_URL` configured. `WAITLIST_NOTIFY_EMAIL` is still optional.

AI, when enabled:

- `BRAM_AI_ENABLED`
- `OPENAI_API_KEY`
- `BRAM_AI_PSEUDONYM_SALT`
- `BRAM_AI_FAST_MODEL`
- `BRAM_AI_STRONG_MODEL`
- `BRAM_AI_PREMIUM_MODEL`
- `BRAM_AI_MAX_NOTE_CHARS`
- `BRAM_AI_REQUEST_TIMEOUT_MS`
- `BRAM_AI_DAILY_USER_REQUEST_LIMIT`
- `BRAM_AI_MONTHLY_ACTIVE_USER_BUDGET_CENTS`

Current status: AI is scaffolded in code but should remain disabled in production until authenticated app endpoints, Supabase user-owned workout tables, and per-user rate limits are implemented.

## Domain

Current status: `www.trybram.app` is assigned to the `bram` project and serving the waitlist site. `https://trybram.app` redirects to `https://www.trybram.app`.
