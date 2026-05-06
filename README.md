# Bram

`Bram: Workout Notes` is a notes-first strength tracker for lifters who want Apple Notes simplicity with real progress memory.

Write your workout naturally. Bram tracks the rest.

## Repo Structure

```txt
apps/
  ios/       SwiftUI app scaffold generated with XcodeGen
  web/       Next.js waitlist site deployed on Vercel
docs/        Product, brand, privacy, analytics, security, and launch docs
prompts/     AI prompt contracts for parsing, reviews, and suggestions
supabase/    SQL migrations and local database notes
```

## Quick Start

```bash
pnpm install
pnpm dev
```

The web app runs from `apps/web`. The iOS app project is generated from `apps/ios/project.yml`.

```bash
pnpm ios:generate
pnpm ios:build
```

## Environment

Copy `.env.example` into `apps/web/.env.local` for local web development. The waitlist API needs Supabase and Resend credentials before it can persist signups or send email.

## Deployment

Production target: `https://www.trybram.app`.

```bash
pnpm build
pnpm vercel:deploy
```

The global Vercel CLI is not required; deployment uses `npx vercel` and the `bram` Vercel project points at `apps/web`.

## Core Docs

- [Business plan](docs/business-plan.md)
- [Brand system](docs/brand-system.md)
- [Product spec](docs/product-spec.md)
- [Design system](docs/design-system.md)
- [AI architecture](docs/ai-architecture.md)
- [Account architecture](docs/account-architecture.md)
- [Analytics plan](docs/analytics-plan.md)
- [Privacy data map](docs/privacy-data-map.md)
- [Security standards](docs/security-standards.md)
- [Testing plan](docs/testing-plan.md)
- [Deployment plan](docs/deployment-plan.md)
- [App Store plan](docs/app-store-plan.md)
