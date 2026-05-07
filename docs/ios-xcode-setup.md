# iOS Xcode Setup

The canonical Xcode project is generated from `apps/ios/project.yml`.

Use `apps/ios/Bram.xcodeproj` when opening the app. Do not edit project settings directly in Xcode unless the same change is also reflected in `apps/ios/project.yml`, because XcodeGen will overwrite generated project files.

## First-Time Setup

From the repo root:

```bash
pnpm install
pnpm ios:setup
pnpm ios:open
```

`pnpm ios:setup` regenerates the project, resolves Swift packages, and confirms the app builds for the default simulator destination.

## Everyday Xcode Workflow

```bash
pnpm ios:generate
pnpm ios:open
```

In Xcode:

- Select the `Bram` scheme.
- Select an iPhone simulator, preferably `iPhone 17 Pro` while that is the repo default.
- Press `Cmd+R` to run the app.
- Press `Cmd+U` to run the unit tests.

## Command-Line Checks

```bash
pnpm ios:build
pnpm ios:test
```

Run these before committing iOS feature work.

## App Store Archive

After the App Store Connect app record exists:

```bash
pnpm ios:archive
pnpm ios:open-archive
```

Use Xcode Organizer to upload the archive to App Store Connect/TestFlight.

## Project Rules

- `apps/ios/project.yml` is the source of truth for targets, bundle identifiers, packages, fonts, and build settings.
- `apps/ios/Bram.xcodeproj/project.pbxproj` is generated output and should only change after `pnpm ios:generate`.
- Reusable app images belong in `apps/ios/Bram/Assets.xcassets` as named image sets, then load through SwiftUI with `Image("AssetName")`.
- Brand-critical images should have a small SwiftUI wrapper with a text or system fallback, as `BramLogoMark` does for the header mark.
- Rive is currently included as a future-ready Swift package dependency, but no real `.riv` asset is wired yet.
- Supabase, RevenueCat, PostHog, Apple Health, and OpenAI calls should stay behind service protocols until production integration work begins.
