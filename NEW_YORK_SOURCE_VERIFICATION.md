# New York source verification — Milestone 2

> Historical September 13 milestone snapshot. Several programs listed below as
> “not published yet” were subsequently enabled only after typed eligibility
> questions, fail-closed formula handling, and coverage warnings were added.
> `Data/offset_seed.json`, `RELEASE_READINESS.md`, and the current automated
> tests are authoritative for the release candidate.

Verified on September 13, 2026. Only primary administrator sources were used for catalog publication.

## Conflict resolution

The IRS OBBB FAQ gives the controlling termination dates used by Offset:

- Section 25C: no property placed in service after December 31, 2025.
- Section 25D: no expenditures after December 31, 2025; installation completed later does not qualify.
- Sections 25E and 30D: no vehicle acquired after September 30, 2025.
- Section 30C: no property placed in service after June 30, 2026.

The existing federal records therefore remain closed for a new project evaluated in September 2026.

## Published in this catalog

### New York Solar Energy System Equipment Credit

- Source: New York State Department of Taxation and Finance.
- Rule encoded: 25% of qualified expenditure, up to $5,000.
- Location: principal residence in New York State.
- Form: IT-255.
- Status: active.

### NYS Clean Heat heat-pump water-heater incentives

- Source: NYS Clean Heat Statewide Heat Pump Program Manual for 2026–2030.
- Central Hudson: $1,250 customer incentive.
- Con Edison: $1,000 customer incentive through the eligible retail/midstream channel.
- National Grid: $1,250 customer incentive.
- NYSEG: $1,250 customer incentive.
- RG&E: $1,250 customer incentive.
- Orange & Rockland: $1,250 customer incentive.
- Status: active, subject to program funding and rule changes.

The app's generic “Water heater” category was renamed “Heat pump water heater” so conventional equipment cannot accidentally receive these matches.

## Deliberately not published yet

- **Drive Clean:** the rebate depends on an eligible vehicle/model, MSRP, and all-electric range. Offset currently collects only price and new/used status.
- **Clean Heat space heating:** the amount depends on ASHP/AWHP/GSHP category, full- or partial-load design, decommissioning, building type/size, utility, and DAC status.
- **Geothermal tax credit:** verified at 25% up to $10,000 for systems placed in service after June 30, 2025, but the current “Heat pump” selection does not distinguish geothermal from air-source equipment.
- **EmPower+/HEAR:** eligibility and awards require household-size/location income rules and project-measure coordination that the current profile and stacking model cannot represent safely.
- **NY-Sun installation incentives:** ordinary residential incentives are now limited primarily to Affordable Solar eligibility, and rates/availability depend on block and project attributes not currently collected.
- **Sales/property-tax exemptions and net metering:** these do not translate reliably into a fixed reduction from sticker price and need a separate non-cash-benefit model.
- **PSEG Long Island programs:** PSEG Long Island is now selectable in the location catalog, but no amount will ship until its separate current manuals and eligibility rules are encoded.

## Required schema/profile milestone

Before the excluded programs can be priced, add typed project details: vehicle make/model/year/range/MSRP; heat-pump technology, load coverage, fuel replacement/decommissioning and building units; DAC/census-tract result; household size and income basis; solar ownership/lease/PPA and system size. Add explicit compatibility/exclusivity rules rather than applying all matching programs blindly.
