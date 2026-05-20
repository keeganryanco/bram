# Bram Testing Plan

## Web

Required before deploy:

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

Manual checks:

- Landing page fits normal desktop and mobile viewports without page scroll.
- Waitlist accepts valid email.
- Invalid email returns a clear error.
- Duplicate email returns a clear already-on-waitlist message.
- New waitlist signup sends the branded Resend welcome email and records `welcome_email_sent_at`.
- TestFlight welcome email sends once, includes Apple offer-code redemption language, and records `account_email_events`.
- TestFlight account bootstrap records `testflight_signup_2026_05`, and the TestFlight launch-offer cron sends the App Store offer email once.
- Launch-day waitlist cron rejects missing/wrong `CRON_SECRET`, sends the correct waitlist or friends/family variant, and marks rows with `launch_email_sent_at`.
- Privacy and terms pages load.
- Contact link opens `mailto:support@trybram.app`.

## iOS

Required before feature work lands:

```bash
pnpm ios:generate
pnpm ios:build
pnpm ios:test
```

Manual checks:

- App launches in simulator.
- Home workspace is the first screen.
- Daily note editor is immediately writable.
- Calendar, stats, and settings panels open as sheets.
- Dark and light mode use brand tokens cleanly.
- App icon asset is present.
- Legal/support links point to production URLs.
