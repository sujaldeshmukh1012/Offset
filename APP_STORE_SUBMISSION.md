# Offset App Store submission packet

Updated September 15, 2026 for version 1.0 (build 1).

## App record

- App Store name: `Offset: Home Incentives`
- Subtitle: `Price clean-energy upgrades`
- Primary language: English (U.S.)
- Bundle ID: `com.sujal.Offset`
- SKU: `OFFSET-IOS-001`
- Primary category: Finance
- Secondary category: Lifestyle
- Age rating: Complete the questionnaire truthfully; expected result is 4+
- Copyright: `2026 Sujal Bhakare`
- Content rights: Offset contains or links to third-party government and utility
  information and has the necessary right to display those links and factual data.

Confirm that the proposed App Store name is available before creating the app
record. The installed app name remains `Offset`.

## Version metadata

### Promotional text

See verified incentives in the order they apply, estimate your real project
price, and keep every claim deadline and step organized.

### Description

Offset helps homeowners and renters understand the real price of clean-energy
upgrades after available incentives.

Enter a project and sticker price, then see verified programs applied in a clear,
deterministic order. Offset explains the source, eligibility requirements,
deadline, and claim steps behind each result so you can decide what to verify
before spending.

Features:

- Estimate incentives for heat pumps, insulation, solar, EVs, EV chargers, and
  efficient water heaters
- See the running price as eligible incentives are applied
- Review official source links and verification dates
- Save projects and track a combined claim checklist
- Receive optional reminders for upcoming deadlines
- Keep your profile and saved-project details on your device

New York is Offset's verified launch market. California and Florida coverage is
currently partial and is labeled clearly before calculation.

Offset provides estimates for planning purposes, not tax, legal, or financial
advice. Program administrators determine final eligibility and benefit amounts.

Offset Premium is available as a monthly or annual auto-renewable subscription.
Premium reveals matched state and utility values, the complete application order,
the estimated final price, full checklist details, and unlimited saved projects.
Payment is charged to your Apple Account. Subscriptions renew automatically
unless canceled at least 24 hours before the end of the current period. You can
manage or cancel your subscription in your Apple Account settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: `PUBLIC_PRIVACY_URL`

### Keywords

`rebates,incentives,heat pump,solar,EV,energy,tax credit,home upgrade,savings`

### URLs

- Support URL: `PUBLIC_SUPPORT_URL`
- Privacy Policy URL: `PUBLIC_PRIVACY_URL`
- Marketing URL (optional): `PUBLIC_SUPPORT_URL`

Replace these values with the deployed pages under `docs/` before submission.

## Auto-renewable subscriptions

Subscription group:

- Reference name: `Offset Premium`
- Display name (English U.S.): `Offset Premium`

Products:

| Duration | Reference name | Product ID | Localized display name | Description | Intended U.S. price |
| --- | --- | --- | --- | --- | ---: |
| 1 month | Offset Premium Monthly | `com.sujal.Offset.premium.monthly` | Offset Premium Monthly | Full incentive results, claim checklists, and unlimited saved projects. | $4.99 |
| 1 year | Offset Premium Annual | `com.sujal.Offset.premium.annual` | Offset Premium Annual | Full incentive results, claim checklists, and unlimited saved projects. | $39.99 |

Set availability, tax category, localization, and the subscription-group
localization. Do not advertise a free trial unless an introductory offer is
actually configured in App Store Connect. Add both products to the first app
version's review submission.

RevenueCat configuration must match exactly:

- App: bundle ID `com.sujal.Offset`
- Entitlement: `premium`
- Offering: create a current offering, with monthly and annual packages
- Products: use the two product IDs above
- Public Apple SDK key: copy the `appl_` key into ignored
  `Offset/Configuration/Secrets.xcconfig`

## App privacy answers

These answers are based on the actual Release bundle and should be confirmed
against Xcode's generated privacy report before publishing:

- Tracking: No
- Data linked to the user: No, assuming the generated pseudonymous notification
  identifier is not combined with account or directly identifying data
- User ID: collected for App Functionality (OneSignal push subscription/external
  identifier), not used for tracking
- Product Interaction: collected for Analytics (notification interactions), not
  used for tracking
- Purchase History: collected for App Functionality (RevenueCat entitlement) and
  Analytics (SDK declaration), not used for tracking
- Other Data / Other Financial Info: not collected by Offset. Program IDs,
  deadlines, and estimated savings are not sent to OneSignal.

Offset does not transmit the user's ZIP, utility, residence type, entered income,
project sticker price, saved project name, or checklist text. OneSignal receives
a random local identifier plus lifecycle-stage and Premium-access tags.
RevenueCat receives purchase and entitlement information. Apple processes
payment-card details.

## App Review information

### Review notes

Offset does not require an account. On first launch, complete the short local
profile, then select a project and enter a sticker price. New York ZIP `10001`
provides the broadest representative catalog path. Results include links to the
official program sources and clearly label estimates.

To review Premium, tap **Unlock full savings** on a calculated result. The paywall
contains monthly and annual subscriptions and Restore Purchases. Both products
are included with this version's review submission and attached to RevenueCat's
`premium` entitlement. A successful purchase updates every gate without an app
restart.

Notification permission is not requested at launch. It is offered only after a
calculation explains reminder value. Notification deep links open the relevant
saved project or program.

No demo account is required. Add a review contact name, phone number, and email
directly in App Store Connect.

### Reviewer attachment

Attach a screenshot of the paywall showing both subscription choices. If Apple
requests it for either subscription product, reuse the same screenshot as the
IAP review screenshot.

## Required dashboard order

1. Re-authenticate the Apple ID in Xcode Settings > Accounts.
2. In Certificates, Identifiers & Profiles, enable Push Notifications for
   `com.sujal.Offset`.
3. Let Xcode manage signing and regenerate/download development and distribution
   profiles.
4. Complete Paid Apps agreements, tax, and banking in App Store Connect.
5. Create the app record and both subscriptions, including localization,
   availability, prices, and review screenshots.
6. Connect the App Store Connect app and products to RevenueCat; attach both to
   the `premium` entitlement and current offering.
7. Create/configure the OneSignal iOS app and upload an APNs `.p8` key.
8. Add production SDK values locally and run the sandbox/device verification
   matrix in `INTEGRATION_PROOF.md`.
9. Archive, validate, upload, attach both subscriptions to version 1.0, complete
   privacy/age-rating/export-compliance questions, and submit for review.
