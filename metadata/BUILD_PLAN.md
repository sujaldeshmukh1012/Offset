# Offset — Four-Day Build Plan

> Historical implementation plan. The production launch decision is now New
> York first, with California and Florida explicitly marked partial. Current
> release status and remaining external work live in `RELEASE_READINESS.md`.

**Build window:** September 10–13, 2026
**Current day:** Day 1 — September 10
**Platform:** Native iOS 16+ (SwiftUI)
**Goal:** A polished, submission-ready vertical slice with the complete planned MVP feature set.

This is the living source of truth for the build. Update it after each verified work block. A task is checked only when its definition of done is met—not merely when code exists.

## Status legend

- `[x]` Complete and verified
- `[ ]` Not complete
- `[-]` In progress
- `[!]` Blocked; add the reason under **Blockers and decisions**

## Scope lock

### Included

- Federal programs: Energy Efficient Home Improvement Credit, Residential Clean Energy Credit, and new/used Clean Vehicle Credits
- FuelEconomy.gov federal EV eligibility data
- Approximately 15 hand-curated utility rebates across CA, TX, NY, MA, CO, and NC
- DOE HOMES/HEAR rollout status for all 50 states
- Heat pumps, EV purchases, EV chargers, insulation/weatherization, solar, and water heaters
- Onboarding, project pricer, program detail, aggregated claim checklist, paywall, saved projects, profile/settings, and notifications
- RevenueCat monthly and annual subscriptions
- OneSignal registration, program deadline tags, 30/14/7-day alerts, and welcome nudges
- Light mode, dark mode, accessibility, error/empty states, analytics-ready event boundaries, and submission assets

### Excluded until after submission

- Backend or user accounts
- Unclaimed-property lookup
- Full utility-rebate depth outside the six target states
- DSIRE integration
- Complex optimization or project-comparison solver
- Android app or Google Play submission

## Non-negotiable quality bar

- [ ] Every displayed incentive has a source URL and verified date.
- [ ] Monetary calculations use deterministic, tested stacking rules and never produce a negative net price.
- [ ] Locked content does not leak premium values through totals, accessibility labels, or navigation.
- [ ] The primary journey works from a clean install: onboarding → pricer → detail/paywall → checklist → saved project.
- [ ] RevenueCat purchase and restore work in sandbox with real configured product identifiers.
- [ ] Notification permission is requested only after value has been demonstrated.
- [ ] Core screens work in light/dark mode, Dynamic Type, VoiceOver, and reduced-motion mode.
- [ ] No placeholder copy, sample incentives, test URLs, debug controls, or test credentials ship in the release build.
- [ ] Unit tests pass, the app builds without errors, and the release candidate is exercised on a real device.

---

## Day 1 — Foundation, integrations, and production data

**Outcome:** The app has a stable architecture, verified local dataset, deterministic pricing engine, persistence foundation, and both third-party SDKs proven independently.

### Project foundation

- [x] Initialize the Xcode project and Git repository.
- [x] Convert the app target to native iOS 16+.
- [x] Add the RevenueCat Swift package and configure the SDK at launch.
- [x] Establish `Models`, `Services`, `Resources`, and unit-test structure.
- [x] Add Codable `Program`, `AmountType`, `UserProfile`, and `MatchResult` models.
- [x] Add optional income to the profile for income-cap filtering.
- [x] Add a bundled JSON loader with ISO-8601 date decoding.
- [x] Implement the first deterministic matching/stacking engine.
- [x] Add matching-engine coverage for geography, utility, project type, income, ordering, caps, running price, and free-tier locks.
- [x] Confirm the app target compiles and bundled program JSON is copied into the app.
- [x] Replace the starter `ContentView` with the app navigation/state shell.
- [x] Add local profile, saved-project, checklist, and onboarding persistence.

### Production data

- [x] Finalize a versioned JSON schema and add schema validation tests.
- [x] Encode and verify federal home-energy programs and category-specific annual caps.
- [x] Encode and verify new and used Clean Vehicle Credit rules, including income and vehicle-price caps.
- [ ] Import the eligible federal EV dataset in a compact offline format.
- [ ] Encode DOE HOMES/HEAR rollout status for all 50 states.
- [ ] Curate and verify approximately 15 utility programs across CA, TX, NY, MA, CO, and NC.
- [ ] Add utility-provider and ZIP-prefix mappings for the six launch states.
- [x] Add homeowner/renter and other program-specific eligibility fields required by the real dataset.
- [x] Clearly distinguish rebates, point-of-sale discounts, and nonrefundable tax credits in data and copy.
- [x] Remove the four development-only sample records before the release candidate.

### RevenueCat and OneSignal proof

- [x] Move SDK keys and product/entitlement identifiers into build configuration rather than source literals.
- [ ] Configure monthly and annual StoreKit/RevenueCat products and the production entitlement identifier.
- [ ] Complete a sandbox purchase and restore flow on a real device.
- [x] Add the OneSignal SDK and required push-notification capabilities.
- [ ] Confirm OneSignal registration and receipt of a test push on a real device.

### Day 1 exit gate

- [x] Production data loads without decoding errors.
- [ ] Pricing tests cover representative projects in all six target states.
- [ ] RevenueCat sandbox purchase/restore and OneSignal test push are proven on-device.
- [ ] No unresolved model or architecture changes are expected before UI work.

---

## Day 2 — Complete product experience

**Outcome:** Every user-facing MVP screen is implemented and connected in one polished end-to-end journey.

### App state and onboarding

- [x] Add the app coordinator/root state and first-launch routing.
- [x] Build home-status selection.
- [x] Build ZIP entry with validation and state derivation.
- [x] Build utility selection using the bundled ZIP/provider mapping, including “not listed.”
- [x] Build accessible multi-select project selection.
- [x] Persist onboarding and profile edits locally.
- [x] Add concise trust and privacy copy explaining local-only profile storage.

### Project pricer hero

- [x] Build project selection and sticker-price input with currency validation.
- [x] Connect onboarding/profile data to the production matching engine.
- [x] Show sticker price, ordered incentive applications, total savings, and final net price.
- [x] Build staged spring animation, number countdown, prior-price strike-through, and tasteful haptics.
- [x] Add a reduced-motion equivalent that preserves clarity and delight.
- [x] Blur/tease locked state and utility rows without leaking exact savings or paid net price.
- [x] Add the “Unlock full savings” entry point.
- [x] Handle no-match, incomplete-profile, invalid-price, and data-load failure states.

### Details, checklist, and saved projects

- [x] Build program detail with amount explanation, plain-language eligibility, source link, deadline, and verified date.
- [x] Build program-specific claim steps.
- [x] Build the aggregated project checklist with correct cross-program ordering and persistent completion state.
- [x] Gate premium checklist details consistently.
- [x] Add saved-project creation, editing, deletion, and free-tier one-project limit.
- [x] Build settings/profile editing and notification preferences.

### Visual system

- [x] Establish semantic colors, typography, spacing, cards, buttons, inputs, and icon conventions.
- [x] Complete light and dark appearances as screens are built.
- [ ] Add loading, empty, success, error, and offline-safe states.
- [x] Verify layouts at small and large Dynamic Type sizes.

### Day 2 exit gate

- [x] The complete clean-install journey works using production data.
- [x] All screens render correctly in light/dark mode and with reduced motion.
- [x] The price-collapse sequence is demo-quality and financially understandable.

---

## Day 3 — Monetization, retention, and hardening

**Outcome:** Paid access and notification loops work end to end, and the application survives focused product, data, and accessibility testing.

### RevenueCat production flow

- [x] Add a reactive entitlement service using `getCustomerInfo()` and customer-info updates.
- [x] Build a branded monthly/annual paywall with value comparison, trial copy if applicable, legal links, and restore.
- [x] Gate state/utility amounts, paid net price, full checklists, and unlimited saved projects.
- [x] Handle purchase success, cancellation, pending state, failure, expiration, and restore.
- [x] Verify locked/unlocked state changes without restarting the app.
- [ ] Verify purchase and restore again using sandbox/TestFlight configuration.

### OneSignal retention flow

- [x] Present a value-explanation screen after the first pricer result, then request notification permission.
- [x] Assign a stable local external user identifier without requiring an account.
- [x] Tag matched program IDs, names, savings, and deadlines.
- [x] Configure 30-day, 14-day, and 7-day deadline reminders with specific copy.
- [x] Configure welcome/incomplete-onboarding and no-project-selected nudges.
- [x] Update or remove tags when projects/profile/checklist state changes.
- [x] Deep-link notification taps to the relevant saved project or program.
- [ ] Verify foreground, background, denied-permission, and notification-tap behavior on-device.

### Test and hardening pass

- [x] Expand unit tests for all amount types, caps, ties, missing data, malformed JSON, and premium totals.
- [x] Add tests for ZIP/state/utility mapping and persisted state migrations.
- [x] Add focused UI tests for onboarding, pricing, paywall entry, checklist, and saved-project limit.
- [x] Validate representative calculations manually against cited source rules.
- [x] Audit premium-data leakage through UI, VoiceOver, logs, and persisted state.
- [x] Audit VoiceOver labels/order, touch targets, contrast, keyboard behavior, and Dynamic Type.
- [-] Profile launch, animation smoothness, memory, and JSON loading. Simulator XCTest metrics pass; final physical-device Instruments pass remains.
- [x] Remove crashes, warnings, force unwraps, dead navigation, and debug logging.

### Day 3 exit gate

- [ ] Purchase, restore, entitlement refresh, and every gate pass the sandbox test matrix.
- [ ] Notification registration, tagging, delivery, and deep link pass on a real device.
- [x] Automated tests pass and no severity-one or severity-two defects remain.

---

## Day 4 — Release candidate, presentation, and submission

**Outcome:** A signed release candidate and every hackathon/App Store submission artifact are finished and submitted.

### Final product polish

- [x] Run a consistency pass on copy, currency, dates, spacing, typography, transitions, and haptics.
- [x] Add the final 1024×1024 app icon and launch presentation.
- [ ] Validate all source links, verified dates, deadlines, and disclaimer copy.
- [-] Test clean install, upgrade/persistence, offline launch, dark mode, reduced motion, and denied permissions. Simulator coverage passes; final denied-permission and physical-device passes remain.
- [ ] Test the release build on at least one physical iPhone.
- [ ] Archive and validate the release candidate with no placeholder/test configuration.

### App Store and judge readiness

- [ ] Complete App Store Connect metadata, privacy details, subscription disclosures, review notes, and support/privacy URLs.
- [ ] Capture final App Store screenshots, led by the project-pricer result.
- [ ] Create a reviewer path or sandbox instructions that expose the full paid experience.
- [ ] Upload and submit the iOS build for App Review.
- [ ] Record and edit the two-minute demo: price collapse first, brief onboarding, detail/checklist, paywall, notification.
- [ ] Prepare Devpost copy for Keep Them Coming Back, HAMM, Peace Prize, and RevenueCat Design Award.
- [ ] Cite official sources for affordability and lower-income impact claims.
- [ ] Submit the hackathon entry and independently verify every required link and permission.

### Day 4 exit gate

- [ ] The release candidate is archived, uploaded, and submitted for review.
- [ ] The demo video and all category materials are uploaded and viewable.
- [ ] The Devpost entry is submitted and confirmation is saved.

> App Review completion is outside the four-day engineering window. Submission is the Day 4 deliverable; review status must be monitored afterward without changing the release candidate unless Apple identifies a blocking issue.

---

## Critical path

1. Production schema and verified data
2. Matching/stacking correctness
3. End-to-end free experience
4. RevenueCat entitlement and gates
5. OneSignal deadline loop
6. Release hardening and submission

If schedule pressure appears, defer only work already listed under **Excluded**. Do not hide defects, ship unverified incentive data, weaken accessibility, or remove committed MVP features to make the checklist appear complete.

## Blockers and decisions

- **Resolved September 11:** The complete XCTest suite now runs in the iPhone 16 simulator; all 17 tests pass.
- **Resolved September 11:** RevenueCat and OneSignal SDK values plus product/entitlement identifiers now come from `.xcconfig` build settings. Empty Release values prevent accidental initialization, and local overrides live in an ignored `Secrets.xcconfig`.
- **September 11:** The connected iPhone is available, but device signing is blocked because the selected Apple Personal Team does not support Push Notifications. Select a paid Apple Developer Program team for `com.sujal.Offset`, enable Push Notifications, and regenerate its provisioning profile.
- **September 11:** RevenueCat dashboard/App Store Connect configuration and Apple sandbox proof remain blocked until the real `appl_` public SDK key is supplied and the two documented subscription IDs are created and attached to the `premium` entitlement.
- **September 11:** OneSignal device proof remains blocked until a OneSignal App ID and APNs `.p8` configuration are supplied, plus the paid-team signing blocker above is resolved.
- **September 11:** Personal-Team Debug builds use an entitlement-free signing path and a local-notification fallback until paid-team activation completes. This keeps device development moving but does not count as OneSignal/APNs proof.
- **Decision:** The original three-week document mentioned Google Play, but the authoritative product brief explicitly limits this build to native iOS. Android is therefore excluded from this four-day plan.

## Progress log

### September 10, 2026 — Day 1

- Corrected the starter project from macOS to iOS 16+.
- Added the core Codable models and stable JSON representation for associated-value amount types.
- Added bundled sample data and the program loader.
- Implemented deterministic matching, eligibility filtering, stacking, running-price calculations, and free-tier lock flags.
- Added five focused matching-engine tests and verified the core calculation path independently.
- Replaced the starter screen with onboarding routing and Projects, Checklist, and Settings navigation stacks.
- Added a versioned `UserDefaults` snapshot for the profile, onboarding status, saved projects, and claim-step completion.
- Added safe load/save failure handling, input normalization, project/checklist cleanup, and persistence tests.
- Verified the iOS app and test bundles compile and independently verified a real `UserDefaults` encode/decode round trip.
- Replaced the flat sample array with versioned program-catalog schema v1, a formal JSON Schema, semantic validation, and focused catalog tests.
- Verified current IRS termination dates and encoded six sourced federal home-energy and clean-vehicle records as closed historical programs so 2026 estimates cannot promise expired credits.
- Added explicit benefit type, availability, occupancy, filing-status income caps, vehicle condition/category price caps, annual-cap groups, and plain-language eligibility metadata.
- Removed all four development-only sample records; validated the production JSON with a native decoding harness and rebuilt the iOS app successfully.

### September 11, 2026 — Day 2

- Moved RevenueCat, OneSignal, subscription product, and entitlement values into Debug/Release `.xcconfig` files with ignored local overrides.
- Added monthly and annual StoreKit products and a shared Debug scheme for local StoreKit testing.
- Added reactive RevenueCat entitlement state, direct monthly/annual purchasing, cancellation/error handling, and restore support.
- Added OneSignal 5.6.1 initialization, deferred notification permission, registration status, Push Notifications entitlement, and remote-notification background mode.
- Added a Debug-only Integration proof screen for localized product lookup, purchase, restore, permission, and OneSignal subscription-ID verification.
- Added a Personal-Team Debug signing path and a three-second local-notification proof so device work can continue while paid-team APNs activation is pending.
- Verified Debug and Release simulator builds, verified integration values in the processed Info.plist, excluded configuration/catalog files from the app bundle, and passed all 17 tests.
- Produced a successfully signed Debug build for the connected iPhone using the Personal-Team configuration; installation awaits the device becoming available/unlocked.
