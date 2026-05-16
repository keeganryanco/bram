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
- `REVENUECAT_SECRET_API_KEY`
- `REVENUECAT_WEBHOOK_AUTH_HEADER`
- `BRAM_ADMIN_GRANT_TOKEN`
- `LINEAR_API_KEY`
- `LINEAR_TEAM_ID`
- `LINEAR_SUPPORT_PROJECT_ID` optional
- `LINEAR_SUPPORT_LABEL_IDS` optional

Current status: production has `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API`, `RESEND_FROM_EMAIL`, `NEXT_PUBLIC_SITE_URL`, `LINEAR_TEAM_ID`, and `LINEAR_SUPPORT_PROJECT_ID` configured. `NEXT_PUBLIC_SITE_URL` should be `https://www.trybram.app` so password recovery links do not lose auth fragments through the apex-domain redirect. `LINEAR_API_KEY` is still required before support requests can mirror into Linear. `WAITLIST_NOTIFY_EMAIL` is still optional.

Linear support intake:

- Team: `Bram-workout-notes`
- Team ID: `4aa33b91-ad1b-499c-b2ac-db3a09744282`
- Project: `Support Inbox`
- Project ID: `d5d9a5ee-768e-44f5-a91c-862969c76744`
- Create a Linear API key in Linear settings, add it to Vercel as `LINEAR_API_KEY` for Production, then redeploy the website so serverless functions read the new env.

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
- `BRAM_AI_PROMO_FOUNDER_SOFT_CAP_CENTS` defaults to `50`
- `BRAM_AI_PROMO_FOUNDER_HARD_CAP_CENTS` defaults to `200`
- `BRAM_AI_FALLBACK_REQUEST_COST_CENTS` defaults to `1`

Current status: AI is scaffolded in code but should remain disabled in production until authenticated app endpoints, Supabase user-owned workout tables, and per-user rate limits are implemented.

## Domain

Current status: `www.trybram.app` is assigned to the `bram` project and serving the waitlist site. `https://trybram.app` redirects to `https://www.trybram.app`.
