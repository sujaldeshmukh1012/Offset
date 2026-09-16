# Offset release readiness

Updated September 16, 2026.

## Product/data boundary

- The bundled normalized catalog is the production source used by the app. New York is the launch market with verified major-territory coverage. California and Florida remain explicitly partial markets.
- Only publishable, match-enabled, currently verified records can produce exact calculations. Dynamic records age out after 30 days; other active records age out after 45 days and become advisory instead of displaying an exact amount.
- Unknown eligibility answers, unresolved formulas, incomplete tiers, unsupported coverage, unverified stacking, and stale records fail closed. The UI never treats “no verified match” as proof that no incentive exists.
- A catalog refresh is a release operation for v1: update `Data/offset_seed.json`, run the tests and preflight, then ship an app update. Do not extend the freshness windows to avoid maintaining the data.

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

Verified September 16, 2026:

- 75 unit/performance tests passed, covering catalog decoding and validation,
  calculations, caps, stacking conflicts/order, coverage, persistence migrations,
  entitlement state, notification retention, and premium-data boundaries.
- 11 end-to-end UI journeys and 4 launch variants passed on an iPhone 16 / iOS
  18.6 simulator, including clean install, reduced motion, large Dynamic Type,
  paywall purchase/restore refresh, saved-project limits, profile editing, and
  representative New York and Florida calculations.
- The signed Release device build succeeded with Swift warnings treated as errors and
  embedded the notification service extension. Generated signing entitlements
  include Push Notifications for the app and the same OneSignal App Group for
  both targets.
- Release-bundle inspection confirmed `PrivacyInfo.xcprivacy`, RevenueCat's
  privacy manifest, and `offset_seed.json` are present, while the legacy catalog,
  StoreKit test configuration, local secrets, and Debug integration screen are
  absent.
- `scripts/release_preflight.sh` reports zero failures. Its remaining warning is
  limited to owner-supplied public support/privacy URLs and contact email. Both
  production SDK identifiers are configured in the ignored local secrets file.

## External release blockers

These cannot be completed in source code:

1. Finish the monthly App Store subscription and complete both subscriptions'
   availability, localization, pricing, and review metadata. The annual product,
   subscription group, app record, and review screenshot already exist.
2. Configure the RevenueCat `premium` entitlement and current offering with both
   exact product IDs.
3. Confirm the shared App Group and Push Notifications capabilities on the paid
   Apple team, upload the APNs `.p8` key to OneSignal, and refresh production
   provisioning for the app and extension. Physical-device OneSignal registration
   is already confirmed.
4. Complete the sandbox/TestFlight purchase, cancellation, pending, expiration,
   restore, and live entitlement-refresh matrix.
5. Complete on-device foreground/background/denied/cold-tap notification tests.
6. Publish privacy/support URLs and add App Store privacy answers,
   screenshots, and review notes. The final app icon is configured.
7. Run Xcode's privacy report and confirm the RevenueCat and OneSignal SDK
   manifests against the App Store Connect privacy answers.

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
```

Production integration values remain outside version control in
`Offset/Configuration/Secrets.xcconfig`.
