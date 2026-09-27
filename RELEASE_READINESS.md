# Offset release readiness

Updated September 25, 2026.

## Product/data boundary

- The full normalized catalog is stored in private Supabase Storage and is not
  bundled in the release app. New York is the launch market with verified
  major-territory coverage. California and Florida remain explicitly partial.
- Only publishable, match-enabled, currently verified records can produce exact calculations. Dynamic records age out after 30 days; other active records age out after 45 days and become advisory instead of displaying an exact amount.
- Unknown eligibility answers, unresolved formulas, incomplete tiers, unsupported coverage, unverified stacking, and stale records fail closed. The UI never treats “no verified match” as proof that no incentive exists.
- The app creates an anonymous Supabase identity, binds its UUID to RevenueCat,
  and installs validated catalogs only after the server verifies `offset_pro`.
  The bundled bootstrap contains no incentive records. Do not extend freshness
  windows to avoid maintaining the data.
- Supabase activation requires the production project URL and publishable key
  in ignored `Secrets.xcconfig`, a private bucket, and the deployed
  `premium-catalog` Edge Function documented in `SUPABASE_CATALOG_SETUP.md`.

## Code-complete safeguards

- Deterministic calculation, caps, running-price order, conflict resolution, and verified explicit stacking order.
- Profile-derived eligibility questions and local persistence migrations.
- Coverage confidence shown before calculation, including partial/unsupported warnings.
- Premium values excluded from free UI, accessibility output, notification tags, logs, and persisted snapshots.
- Reactive RevenueCat entitlement state and OneSignal/local-reminder orchestration.
- Notification authorization is requested only from the post-calculation value
  primer or the explicit Settings toggle; SDK registration never displays UI.
- The semantic color system follows the device appearance in light and dark
  mode instead of forcing a fixed appearance.
- OneSignal 5.5.1 is pinned exactly, centralized behind `OneSignalManager`, and
  includes the required notification service extension, remote-notification
  background mode, and shared App Group entitlements.
- Privacy manifest for the app's own `UserDefaults` access and export-compliance declaration for exempt encryption.
- Legacy sample catalogs excluded from the application target.

## Verification evidence

Release candidate 1.0 (build 2) was archived, exported with Cloud Managed Apple
Distribution signing, and uploaded successfully to App Store Connect on
September 22, 2026. Apple accepted the package for processing. Build 2 includes
the final full-bleed app icon and matching in-app branding; build 1 is
superseded and should not be selected for review.

The current resubmission source is version 1.0 (build 3). It replaces build 2
with the official RevenueCat App Store key and entitlement, public policy and
support links, and owner-confirmed AI-generated opportunity artwork. Build 3
must complete physical-device IAP and push acceptance testing before upload.

Verified September 25, 2026 for the secure-catalog candidate:

- 76 unit/performance tests passed, covering catalog decoding and validation,
  calculations, caps, stacking conflicts/order, coverage, persistence migrations,
  entitlement state, notification retention, the zero-program Release bootstrap,
  and premium-data boundaries.
- The previous 12 end-to-end UI journeys and 4 launch variants passed on an
  iPhone 16 / iOS 18.6 simulator. Re-run them after the live Supabase environment
  is configured; deterministic UI tests use the Debug-only full-catalog fixture.
- The signed Release archive and App Store Connect export succeeded with Swift
  warnings treated as errors and embedded the notification service extension.
  The exported IPA uses cloud-managed Apple Distribution profiles,
  `get-task-allow = false`, production APNs for the app, and the same OneSignal
  App Group for both targets.
- A fresh Release simulator build succeeded with warnings treated as errors.
  Bundle inspection confirmed the zero-program bootstrap `offset_seed.json` is
  present and the Debug fixture and known premium program identifiers are absent.
  The final archive must repeat the broader privacy-manifest and secrets checks.
- All 24 match-enabled official source URLs returned HTTP 200. This verifies
  link availability, not that an administrator has left every program term
  unchanged.
- Four 1320×2868 iPhone screenshots and four 2064×2752 iPad screenshots were
  captured from passing deterministic UI journeys under `AppStoreAssets/Storefront`.
- `scripts/release_preflight.sh` currently reports one failure and no warnings:
  the production Supabase project URL and publishable key still need to be added
  to the ignored local secrets file after the backend is deployed.

## External release blockers

These cannot be completed in source code:

1. Make `offset-catalogs` private, enable anonymous Supabase Auth, deploy the
   `premium-catalog` Edge Function, configure its RevenueCat secret, and add the
   project URL/publishable key to ignored `Secrets.xcconfig`.
2. Finish the monthly App Store subscription and complete both subscriptions'
   availability, localization, pricing, and review metadata. The annual product,
   subscription group, app record, and review screenshot already exist.
3. Configure the RevenueCat `offset_pro` entitlement and current offering with both
   exact product IDs.
4. Upload or confirm the APNs `.p8` key in OneSignal. App Store provisioning,
   production push entitlement, the shared App Group, and physical-device
   OneSignal registration are already confirmed.
5. Complete the sandbox/TestFlight purchase, cancellation, pending, expiration,
   restore, and live entitlement-refresh matrix.
6. Complete on-device foreground/background/denied/cold-tap notification tests.
7. Publish privacy/support URLs and add App Store privacy answers and review
   notes. The final app icon and iPhone/iPad storefront screenshot sets are ready.
8. Run Xcode's privacy report and confirm the RevenueCat, OneSignal, and
   anonymous Supabase Auth disclosures against the App Store Connect privacy answers.

## Release commands

Run the deterministic preflight first:

```sh
./scripts/release_preflight.sh
```

Then run unit tests and build Release for a generic device:

```sh
xcodebuild test -project Offset.xcodeproj -scheme Offset \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:OffsetTests

xcodebuild build -project Offset.xcodeproj -scheme Offset \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -scmProvider system

xcodebuild archive -project Offset.xcodeproj -scheme Offset \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/Offset-v1-build2.xcarchive -scmProvider system

xcodebuild -exportArchive -archivePath /tmp/Offset-v1-build2.xcarchive \
  -exportPath /tmp/Offset-AppStore-build2-export \
  -exportOptionsPlist scripts/AppStoreExportOptions.plist \
  -allowProvisioningUpdates
```

Production integration values remain outside version control in
`Offset/Configuration/Secrets.xcconfig`.
