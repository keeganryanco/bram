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

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RESEND_API_KEY` or `RESEND_API`
- `RESEND_FROM_EMAIL`
- `WAITLIST_NOTIFY_EMAIL` optional
- `NEXT_PUBLIC_SITE_URL`

Current status: production has `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API`, `RESEND_FROM_EMAIL`, and `NEXT_PUBLIC_SITE_URL` configured. `WAITLIST_NOTIFY_EMAIL` is still optional.

## Domain

Current status: `www.trybram.app` is assigned to the `bram` project and serving the waitlist site. `https://trybram.app` redirects to `https://www.trybram.app`.
