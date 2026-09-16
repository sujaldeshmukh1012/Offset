# Offset Incentive Database Seed

Generated: 2026-09-13T18:04:00-04:00

## Files

- `offset_seed.json`: canonical normalized dataset bundled by the iOS target.
- `offset_schema.sql`: schema only.
- `OffsetDatabase.swift`: optional read-only SQLite wrapper retained for a future generated database.

The discovery handoff referenced `offset_incentives.sqlite` and `offset_seed.sql`, but neither
file is present in this folder. The current app therefore loads the complete JSON seed directly;
it does not depend on a missing generated database.

## Current contents

- Programs: 38
- Automatically match-enabled programs: 24
- Sources: 33
- Utilities/service territories: 19
- Eligibility rules: 37
- Incentive tiers: 42
- Claim steps: 19
- Stacking relationships: 5
- Coverage entries: 66

## Integration rule

The iOS app decodes and validates the complete normalized JSON seed, then adapts each category
association into an app project record. Only exact amounts whose blocking eligibility fields can
be resolved from the current local profile enter the savings total. Formula, range, tax,
non-cash, stale dynamic, and incompletely modeled records stay visible as verification advisories.

If a SQLite artifact is generated later, use the `active_match_programs` view for the initial
candidate query. It only includes records marked publishable, match-enabled, and currently
active/dynamic.

```sql
SELECT p.*
FROM active_match_programs p
JOIN program_categories pc ON pc.program_id = p.id
WHERE pc.category_id = ?
  AND (p.state_code = ? OR p.state_code IS NULL);
```

Then evaluate `eligibility_rules` and choose the applicable `incentive_tiers`. `value_json` and `conditions_json` are JSON encoded so the same seed works with Swift, TypeScript, Python, or a backend rule engine.

## Verification model

- `primary_verified`: exact rule/amount verified against a primary agency or utility source during this build.
- `primary_verified_dynamic`: official source verified, but the amount/funding/rule can change and must be rechecked before final display.
- `needs_reverify`: known program requiring current primary-source confirmation.
- `discovery_only`: source/program is known, but it is deliberately disabled for matching.

`match_enabled = 0` means Offset must not include the program in a savings total. This is used for expired federal credits, waitlisted California programs, and utility sources that have not yet been normalized.

## Important product behavior

Never interpret an unsupported or discovery-only territory as `$0 incentives`. Return `coverage_status` and tell the user that Offset has not verified complete coverage there.

## Data architecture

The database separates:

- program metadata and lifecycle status
- utility/service territory
- categories
- eligibility rules
- tier/formula amounts
- claim sequence
- stacking relationships
- source provenance
- coverage confidence

This lets Offset answer three separate questions correctly: **does the program exist, does this user qualify, and can it be safely included in the stack?**

## Refresh strategy

1. Use DSIRE/Rewiring America/ENERGY STAR/AFDC as candidate discovery and change detection.
2. Re-fetch the primary agency/utility source for any candidate change.
3. Update program/tier/rule records only after primary-source confirmation.
4. Set `last_verified_at` on each verified record.
5. Disable matching immediately when funding closes, a program moves to waitlist, or the source becomes ambiguous.

## Current scope limitations

- New York: major utility territories and major statewide programs are represented; most Clean Heat utility amounts remain dynamic by design.
- Florida: FPL and Duke are normalized; TECO/JEA/OUC/GRU are discovery-only.
- California: selected PG&E, SCE, LADWP, SMUD, SDG&E programs are normalized; CCA, REN, air-district, and long-tail regional programs remain incomplete.
- Federal clean-energy credits that expired before September 2026 are retained as date-aware records but excluded from matching.

## Safety / accuracy boundary

This seed is an engineering dataset, not tax/legal advice. Incentive funding, equipment lists, income thresholds, and utility rules can change without notice. The app should expose the official source URL and verification date for every matched program.

## iOS integration

`offset_seed.json` is included in Copy Bundle Resources. `IncentiveDatasetStore` performs schema,
uniqueness, foreign-key, URL, amount, and embedded-JSON checks before `ProgramStore` exposes any
records to the matching engine. A malformed seed fails closed into the app's existing data-load
error state.
