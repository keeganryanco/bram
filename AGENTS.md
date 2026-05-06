# Bram Agent Instructions

Bram is a monorepo for a SwiftUI iOS app and a Vercel-hosted waitlist site.

## Product center

- Public name: `Bram: Workout Notes`.
- Promise: write your workout naturally; Bram tracks the rest.
- Tone: calm, strong, grounded, specific.
- AI should be invisible in positioning. Do not lead product copy with AI.

## Repo rules

- Keep app code under `apps/ios` and web code under `apps/web`.
- Keep product, privacy, analytics, and architecture notes under `docs/`.
- Keep prompt contracts under `prompts/`.
- Keep SwiftUI views small and feature-scoped; do not create large files that mix UI, services, analytics, persistence, and business logic.
- Put reusable iOS UI in `Components` or `DesignSystem`, app/domain state in `Models` or `AppState`, service seams in `Services`, and preview fixtures in `Fixtures`.
- Do not send raw workout note content to analytics.
- Do not expose Supabase service-role keys, Resend keys, RevenueCat keys, or OpenAI keys to client code.
- RevenueCat and PostHog MCP connections are intentionally not trusted yet; document integration points without calling those tools.

## Validation

- Web: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build`.
- iOS: `pnpm ios:generate`, then `pnpm ios:build` when a simulator matching the script is available.
