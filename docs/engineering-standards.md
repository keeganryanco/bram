# Bram Engineering Standards

## Codebase Shape

Bram should stay easy to navigate as features grow. Prefer small, purposeful files over screens or services that accumulate unrelated responsibilities.

Core rules:

- Keep feature UI under feature folders.
- Keep reusable UI under `Components` or `DesignSystem`.
- Keep domain models in `Models`.
- Keep external integrations behind protocols in `Services`.
- Keep sample/preview data in `Fixtures`.
- Avoid files that mix layout, networking, analytics, persistence, and business logic.

SwiftUI should default to native state and simple model-driven views. Add view models only when there is real orchestration complexity that cannot stay cleanly in values, services, or view-local state.

## Feature Boundaries

The iOS app should grow through clear boundaries:

- `Home`: daily note, interpreted workout summary, inline suggestion, load bar.
- `Calendar`: date selection and workout completion markers.
- `Stats`: workout load, volume, PRs, streaks, Apple Health-derived insights.
- `Settings`: account, subscription, preferences, privacy, export/delete, support.
- `Services`: Supabase, RevenueCat, PostHog, Apple Health, OpenAI backend clients.

No feature should call a third-party SDK directly from a SwiftUI body. Route integration work through services and inject mock/sample data for previews.

## Security And Cost Controls

Before production AI or analytics:

- no raw workout notes in PostHog, RevenueCat, TikTok, or ad-platform events
- no OpenAI, Supabase service-role, RevenueCat, Resend, or PostHog secret in client code
- no unauthenticated AI endpoints
- AI calls must be rate-limited by user, task, and budget
- API usage must be observable by task/model/user bucket before scale
- account entitlement writes must be server/admin-only

## Integrations Roadmap

Planned but not active in the current app scaffold:

- PostHog for product analytics with numeric/categorical event properties only.
- RevenueCat for App Store subscription entitlement sync.
- Apple Health for bodyweight, recovery-adjacent, and activity context.
- OpenAI through Bram backend endpoints only.
- Rive for rare Bram mascot/reward moments.
- Framer/Motion for future web or prototype UI motion, not native iOS.
- Apple Search Ads after App Store listing readiness.
- TikTok ads only after organic creative and conversion signals exist.

## Quality Bar

Before feature work lands:

- build and tests pass
- previews exist for meaningful UI states
- dark and light mode are checked when UI changes
- empty/loading/error states are represented when async behavior exists
- docs are updated when architecture, integrations, or privacy posture changes
