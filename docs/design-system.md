# Bram Design System

## Brand Feel

Calm, strong, grounded, premium, notes-first, quietly intelligent.

## Color Tokens

Light mode:

- App background: `#F4EFE7`
- Elevated surface: `#FFFCF7`
- Card surface: `#FFFFFF`
- Primary text: `#23262C`
- Secondary text: `#444852`
- Tertiary text: `#6C7078`
- Brand violet: `#5D5AF7`
- Violet deep: `#4742D9`
- Energy: `#E77A4B`
- Recovery: `#7E977E`

Dark mode:

- App background: `#1B1B1B`
- Deep background: `#0F1012`
- Elevated surface: `#222326`
- Primary text: `#F7F2EA`
- Secondary text: `#C9C4BB`
- Brand violet: `#5D5AF7`

## Usage Rules

- Use violet for wordmark, CTA, selected state, active date, and intelligent highlights.
- Use orange for PRs and effort only.
- Use sage for recovery and balance only.
- Use cream for paper/editorial surfaces.
- Keep most screens to one neutral foundation and one violet moment.

## Typography

Use Suisse Int'l for product UI and Adobe Caslon Pro for the Bram wordmark and rare brand moments.

Implementation:

- Web fonts live in `apps/web/src/assets/fonts/`.
- iOS fonts live in `apps/ios/Bram/Resources/Fonts/` and are registered through `UIAppFonts`.
- Font filenames intentionally omit `Trial`; the embedded PostScript names in the supplied Suisse files still include `Trial`, so iOS maps those names in `BramFont`.
