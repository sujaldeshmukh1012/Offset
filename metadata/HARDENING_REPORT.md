# Day 3 hardening evidence (superseded)

> Historical September 12 snapshot. See `RELEASE_READINESS.md` and the latest
> test/build results for the normalized New York launch catalog. The sample
> Massachusetts/federal examples below are retained only as earlier engine-test
> evidence and are not the catalog shipped by the Release target.

Date: September 12, 2026

## Representative rule calculations

The following checks use the exact `AmountType` calculation performed by
`MatchingEngine`: percentage of the current eligible price, fixed amount, or the
smaller of the percentage result and a published cap. They are estimates, not a
tax determination.

| Program rule | Representative input | Hand calculation | Expected result |
| --- | ---: | --- | ---: |
| Massachusetts renewable-energy credit | $12,000 | min($1,000, 15% × $12,000) | $1,000 savings; $11,000 remaining |
| Federal 25C heat pump | $10,000 | min($2,000, 30% × $10,000) | $2,000 savings; $8,000 remaining |
| Federal 25C insulation | $3,000 | min($1,200, 30% × $3,000) | $900 savings; $2,100 remaining |
| Federal 25C insulation cap | $5,000 | min($1,200, 30% × $5,000) | $1,200 savings; $3,800 remaining |
| Federal 25D solar | $20,000 | 30% × $20,000 | $6,000 savings; $14,000 remaining |
| Federal new clean vehicle | $50,000 | fixed maximum modeled value | $7,500 savings; $42,500 remaining |
| Federal used clean vehicle | $20,000 | min($4,000, 30% × $20,000) | $4,000 savings; $16,000 remaining |

The inputs match the published Massachusetts rule (15%, capped at $1,000), IRS
25C rules (30%, with $2,000 heat-pump and $1,200 general limits), IRS 25D solar
rule (30%), and the clean-vehicle limits represented in the catalog:

- https://www.mass.gov/info-details/massachusetts-residential-property-tax-credits
- https://www.mass.gov/regulations/830-CMR-6261-residential-energy-credit
- https://www.irs.gov/credits-deductions/energy-efficient-home-improvement-credit
- https://www.irs.gov/credits-deductions/residential-clean-energy-credit
- https://www.irs.gov/credits-deductions/credits-for-new-clean-vehicles-purchased-in-2023-or-after
- https://www.irs.gov/credits-deductions/used-clean-vehicle-credit

The federal programs are retained as closed history and are excluded from 2026
matches. Vehicle eligibility remains conditional on the specific VIN and all IRS
requirements. Massachusetts defines its base as net qualifying expenditure, so
other credits, grants, rebates, prior claims, and excluded costs can reduce the
actual result. The UI therefore labels every result estimated and links to the
administrator's rule.

## Privacy and premium-data audit

- Free result rows expose only federal names and amounts. Locked state/utility
  rows have only a generic level label and no exact savings or net price.
- Locked VoiceOver elements replace their children with a generic accessibility
  label and hint; blurred placeholder children are accessibility-hidden.
- App-state persistence contains the user-entered profile, saved sticker prices,
  and checklist IDs, but no calculated savings, paid net price, or program name.
- OneSignal tag construction filters non-federal matches for free users and
  removes previously synchronized premium tags when access/profile/project state
  changes.
- No profile or financial debug logging is present in the application target.

## Accessibility audit

- Primary and secondary actions have at least a 44-point target; checklist rows
  now enforce the same minimum.
- Main display headings use Dynamic Type text styles. Price totals reflow
  vertically for accessibility content sizes.
- Selection controls expose label, selected state, and action hint. Locked rows
  do not expose hidden descendants. Decorative icons are accessibility-hidden.
- Pricer currency input has a decimal keyboard and an explicit Done action.
- The reduced-motion path skips staged springs, countdown transitions, and
  haptics while showing the complete result immediately.
- Audited palette contrast ratios range from 6.42:1 to 17.17:1 for the primary
  text/accent combinations used on their normal surfaces, above WCAG AA normal
  text requirements.

## Runtime and static audit

- Performance coverage repeatedly decodes and validates the bundled JSON while
  collecting clock, CPU, and memory metrics; the simulator test completed in
  0.108 seconds. A 5,000 × six-project matching workload completed in 1.089
  seconds. These are regression signals, not physical-device launch targets.
- The UI suite includes `XCTApplicationLaunchMetric`; physical-device Instruments
  traces remain part of the release-candidate pass. A warmed iOS 26.5 Simulator
  run averaged 2.525 seconds to first responsive frame (high simulator variance,
  so this is not treated as a device launch target).
- Program JSON is decoded once per pricer view model and reused for calculations.
- No application-target force unwraps, forced casts, `try!`, `fatalError`, or
  debug print calls remain. Missing SDK configuration degrades to unavailable
  integration state instead of asserting.
- Dead-link review covers every `NavigationLink`, sheet, tab jump, notification
  route, deleted-project fallback, and missing-program fallback.

## Automated verification

- All 54 unit/performance tests pass on the iOS 26.5 simulator.
- Focused UI coverage passes for onboarding and profile editing, production
  pricing, dark mode, reduced motion, Dynamic Type accessibility sizing,
  checklist/project CRUD, free-tier project limits, premium-data leakage,
  paywall purchase simulation, and restore simulation.
- The launch-performance UI test passes; the latest warmed simulator sample was
  approximately 2.55 seconds to responsive UI, with expected simulator variance.
- The Release app target builds with `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`.
  A quiet static-analysis build also completes successfully.
- `git diff --check` is clean, and the application-target static scan finds no
  force unwraps, forced casts, `try!`, fatal/assertion traps, or debug printing.

## Remaining external verification

- RevenueCat sandbox purchase/restore/expiration matrix on a signed device or
  TestFlight build.
- OneSignal APNs registration, foreground/background receipt, denied permission,
  and cold notification-tap routing on a signed physical device.
- Final physical-device Instruments traces for launch, animation hitches,
  allocations, and leaks.
