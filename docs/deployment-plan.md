# Bram Deployment Plan

## Website

Framework: Next.js App Router under `apps/web`.

Production target: `https://trybram.app`.

Initial production deployment:

- URL: `https://web-j8qbu3ojp-keegan-ryans-projects.vercel.app`
- Inspector: `https://vercel.com/keegan-ryans-projects/web/BJBDqvVYA2cgHZhuFLDLd6PsT2F1`
- SSO deployment protection: disabled for the public waitlist site.

Deploy with:

```bash
pnpm build
pnpm vercel:deploy
```

The repo does not require a global Vercel CLI. The script uses `npx vercel`.

## Required Vercel Environment Variables

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RESEND_API_KEY`
- `RESEND_FROM_EMAIL`
- `WAITLIST_NOTIFY_EMAIL` optional
- `NEXT_PUBLIC_SITE_URL`

Current status: no Vercel environment variables are configured yet, so production waitlist submissions will return the intentional `503` configuration response until Supabase and Resend values are added.

## Domain

Attach `trybram.app` after the Vercel project is linked and DNS ownership is available.

Current status: `trybram.app` exists in the Vercel team but is already assigned to another project. Vercel reports current nameservers as Cloudflare (`macy.ns.cloudflare.com`, `rayden.ns.cloudflare.com`) while intended Vercel nameservers are `ns1.vercel-dns.com` and `ns2.vercel-dns.com`. Do not force-move the domain without confirming the target project.
