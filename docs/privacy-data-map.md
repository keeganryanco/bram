# Bram Privacy Data Map

## Data Categories

- Waitlist email: Supabase, Resend.
- Account info: Supabase Auth, `profiles`, `account_entitlements`.
- Purchases: RevenueCat, App Store.
- Product analytics: PostHog.
- Workout notes: Supabase user-owned tables.
- Parsed workouts: Supabase user-owned tables.
- AI processing: OpenAI Platform or selected model provider.
- Support messages: support inbox.

## Commitments

- Bram does not sell workout data.
- Bram does not use workout notes for advertising.
- Analytics must not include raw workout notes.
- User-owned tables must use Supabase RLS.
- App must provide deletion and export paths before App Store submission.
- Entitlement/admin flags must be service-role managed, not user editable.

## App Store Copy Anchor

Bram uses your workout notes to structure your training history, generate progress insights, and provide suggestions. We do not sell workout data or use it for ads.
