# Offset production data plan

> Historical planning document. The shipped catalog is now
> `Data/offset_seed.json`; `Offset/Resources/programs.json` is legacy test/sample
> material and is excluded from the app target. See `RELEASE_READINESS.md` and
> `NEW_YORK_SOURCE_VERIFICATION.md` for the current release boundary.

## What the app has today

`Offset/Resources/programs.json` is now a small production-backed catalog, not yet a launch-ready national catalog. It currently contains fourteen records:

- one active Massachusetts solar tax credit;
- one active New York residential solar tax credit;
- six active, utility-scoped New York heat-pump water-heater incentives;
- six closed federal programs retained as history;

`location_catalog.json` maps ZIP codes to states and user-selected utilities. It does not itself contain rebate rules. A New York profile using National Grid and an EV charger still correctly produces no match because the current catalog does not yet contain a verified active residential charger program for that territory.

## What customers pay for

Public program pages are not the product by themselves. Offset's paid value is a maintained, auditable layer over those sources:

- normalized eligibility rules;
- correct caps and incentive stacking order;
- location and utility matching;
- verified dates, deadlines, and change monitoring;
- project-specific claim steps and direct source links;
- reminders and saved progress.

Never market a result as complete unless the user's state, utility, and project category are covered by the catalog version on the device.

## Source hierarchy

Use primary sources to establish every sellable record:

1. IRS statutes, credit pages, forms, and instructions for federal tax credits.
2. U.S. Department of Energy Home Energy Rebates status pages, then the linked state energy office or program administrator.
3. Official state tax, energy, housing, or environmental agency pages.
4. Official utility rebate pages, tariffs, program manuals, and application PDFs.
5. ENERGY STAR's Rebate Finder for discovery and cross-checking; verify the rule against the administering utility before publishing it.
6. A licensed DSIRE data export may accelerate discovery if its commercial terms and update frequency work for Offset. Do not use the deprecated NLR incentives API: its database is frozen at 2017.

Aggregators should locate candidates, not serve as final authority for money calculations.

## Minimum record required for publication

Each program needs:

- stable internal ID and official name;
- administering organization and program level;
- covered states, ZIPs or utility territories;
- eligible project/equipment types and occupancy rules;
- income, equipment, vehicle, and project-cost thresholds;
- amount formula, per-item and annual caps, and interaction/stacking rules;
- effective date, application or installation deadline, and status;
- plain-language eligibility summary and ordered claim steps;
- official source URL plus any supporting form or program-manual URLs;
- `lastVerifiedDate`, reviewer, and a checksum or snapshot reference for the reviewed source.

If an important rule cannot be represented by the current schema, extend the schema and tests before approximating it.

## Publishing workflow

1. Discover a candidate program.
2. Read the official rule and any current application guide.
3. Encode it in a review branch with source evidence.
4. Have a second reviewer check the amount, caps, dates, eligibility, and claim order.
5. Run schema validation and calculation fixtures at boundary values.
6. Publish a signed/versioned catalog and record the verification date.
7. Recheck dated programs weekly and undated programs monthly; immediately review programs when an administrator announces a change.
8. Mark uncertain or expired records paused/closed rather than returning a possibly wrong savings amount.

## Practical MVP scope

Launch one state deeply before claiming nationwide coverage. New York is the logical first market for the current test profile. Build a reviewed catalog across the six existing project categories for the major New York utilities, then add a visible coverage screen and catalog update mechanism. A small, accurate market is more defensible than sparse national data.

The next implementation milestone should be a New York source inventory, followed by schema-backed records and calculation fixtures. Actual eligibility decisions remain with the program administrator; the app should state that near every estimate.
