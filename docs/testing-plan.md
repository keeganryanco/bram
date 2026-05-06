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
- Privacy and terms pages load.
- Contact link opens `mailto:support@trybram.app`.

## iOS

Required before feature work lands:

```bash
pnpm ios:generate
pnpm ios:build
```

Manual checks:

- App launches in simulator.
- Tab shell works.
- App icon asset is present.
- Legal/support links point to production URLs.
