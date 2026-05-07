# App Store Connect Setup

This is the path for making Bram appear in your Apple Developer/App Store Connect account.

## Bram Values

- App name: `Bram: Workout Notes`
- Platform: iOS
- Bundle ID: `app.trybram.Bram`
- SKU: `app.trybram.Bram`
- Primary language: English
- Privacy policy: `https://trybram.app/privacy`
- Terms: `https://trybram.app/terms`
- Support email: `support@trybram.app`

## What Xcode Can And Cannot Do

Xcode signing and capabilities can create or manage local signing assets and developer portal identifiers, but the App Store Connect app listing is a separate app record.

The app appears in App Store Connect after you create a new app record in App Store Connect and select Bram's bundle ID. After that, archived builds uploaded from Xcode will appear under TestFlight once Apple finishes processing them.

## Create The App Record

1. Go to App Store Connect.
2. Open **My Apps**.
3. Click **+** and choose **New App**.
4. Fill in:
   - Platforms: iOS
   - Name: `Bram: Workout Notes`
   - Primary language: English
   - Bundle ID: `app.trybram.Bram`
   - SKU: `app.trybram.Bram`
   - User access: Full Access unless you want to restrict access later
5. Create the app record.

If the bundle ID does not appear, confirm the identifier exists in the Apple Developer portal and that Xcode is signed into the same Apple Developer team.

## Upload A Build

From the repo root:

```bash
pnpm ios:generate
pnpm ios:archive
pnpm ios:open-archive
```

Then in Xcode Organizer:

1. Select the Bram archive.
2. Click **Distribute App**.
3. Choose App Store Connect distribution.
4. Upload.

The build may take several minutes to process before it appears in App Store Connect/TestFlight.

## API Automation Later

App Store Connect can be automated with an App Store Connect API key, but do not commit the key. Required secrets would be:

- Issuer ID
- Key ID
- Private `.p8` key

Use API automation only after the app metadata and release process settle.
