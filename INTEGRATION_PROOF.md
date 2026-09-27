# RevenueCat and OneSignal device proof

The application-side integration is complete. Dashboard configuration and the
two physical-device proofs require the real service credentials and cannot be
represented by a source-code checkbox alone.

Updated September 22, 2026.

## Identifiers

These values are defined in `Offset/Configuration/Shared.xcconfig` and must be
created with exactly the same spelling in App Store Connect and RevenueCat:

| Purpose | Identifier |
| --- | --- |
| Monthly subscription | `com.sujal.Offset.premium.monthly` |
| Annual subscription | `com.sujal.Offset.premium.annual` |
| RevenueCat entitlement | `offset_pro` |

Both subscriptions must be in one App Store Connect subscription group. Import
them into the RevenueCat product catalog, attach both to the `offset_pro`
entitlement, and add monthly and annual packages to the current offering.

## Local configuration

1. Copy `Offset/Configuration/Secrets.example.xcconfig` to
   `Offset/Configuration/Secrets.xcconfig`.
2. Set `REVENUECAT_API_KEY` to the RevenueCat Apple public SDK key (`appl_…`),
   not a secret API key and not the RevenueCat Test Store key.
3. Set `ONESIGNAL_APP_ID` to the UUID from OneSignal Settings > Keys & IDs.
4. In the Apple Developer portal, enable Push Notifications for
   `com.sujal.Offset`, configure the APNs `.p8` key in OneSignal, and regenerate
   the development provisioning profile if automatic signing has not done so.

While the paid membership is activating, Debug uses
`Offset/Offset.Personal.entitlements`. It can install under a Personal Team and
the Integration proof screen can deliver a local test notification. Once the
paid team is ready, uncomment the `CODE_SIGN_ENTITLEMENTS` override in
`Secrets.xcconfig` to restore APNs/OneSignal for Debug builds. Release always
uses `Offset/Offset.entitlements`.

`Secrets.xcconfig` is ignored by Git. The Release configuration contains empty
SDK values, and neither SDK initializes until its production value is provided.

## RevenueCat sandbox proof

The shared `Offset` Debug scheme uses `Offset/Resources/Offset.storekit` for
fast local purchase testing. A local StoreKit transaction is not an Apple
sandbox proof. Select the shared **Offset-Sandbox** scheme for live testing; it
has no StoreKit configuration attached and automatically passes
`-use-live-store`.

1. Select **Offset-Sandbox** from Xcode's scheme menu. Do not attach a StoreKit
   configuration to this scheme.
2. Confirm the Debug build is using the production RevenueCat Apple public SDK
   key (`appl_…`) from `Secrets.xcconfig`, not the checked-in Test Store key.
3. Install the Debug build on a physical iPhone signed for
   `com.sujal.Offset` and sign in with a Sandbox Apple Account under Developer
   settings.
4. Open **Integration proof** from the onboarding navigation bar (or Settings
   after onboarding). Confirm both products show localized prices.
5. Buy monthly or annual and confirm Access changes to **Active**.
6. Delete/reinstall the app, return to **Integration proof**, tap **Restore
   purchases**, and confirm Access changes to **Active**.
7. Save the RevenueCat customer event/transaction and a screen recording as
   evidence, then check the two sandbox checklist items in `BUILD_PLAN.md`.

### Purchase-state matrix

Run this matrix before checking the sandbox/TestFlight item:

| Case | Action | Expected result |
| --- | --- | --- |
| Purchase | Buy either plan | Paywall closes and locked amounts, net price, checklist steps, and additional project creation unlock without relaunching. |
| Cancel | Cancel Apple's confirmation sheet | Paywall stays open and says that no charge was made. |
| Pending | Enable Ask to Buy or interrupted-purchase testing | Paywall explains that approval is pending; access remains locked until RevenueCat emits active CustomerInfo. |
| Restore | Reinstall, then Restore Purchases | Active entitlement and every gate return without relaunching. |
| No purchase | Restore with a fresh sandbox account | Paywall reports that no active purchase was found. |
| Expiration | Let the accelerated sandbox subscription expire | State becomes Expired and paid gates lock when the app becomes active or CustomerInfo updates. |
| Billing issue/grace | Exercise StoreKit billing retry if available | Settings reports a payment issue while access follows RevenueCat's active entitlement result. |
| Failure | Use StoreKit transaction-failure controls | A recoverable error is shown and the paywall remains usable. |
| Offer code | Redeem an App Store Connect sandbox offer code | Apple's redemption sheet accepts the code and the `offset_pro` entitlement refreshes without relaunching. |

Repeat purchase, restore, and expiration once from a TestFlight build because
the local `.storekit` file is not used there. Record the build number, sandbox
Apple Account, RevenueCat App User ID, product ID, entitlement transition, and
result for each row. Never include passwords or receipt contents in evidence.

## OneSignal device proof

1. Install the configured Debug build on a physical iPhone.
2. Open **Integration proof**, read the reminder explanation, and tap **Enable
   deadline reminders**. The app deliberately does not prompt at launch.
3. Tap **Refresh registration** until a Subscription ID is displayed. Find that
   same subscription in OneSignal Audience > Subscriptions.
4. Add it to a test subscription/segment and send a test push from OneSignal.
5. Confirm receipt with the app backgrounded and foregrounded, save evidence,
   and check the OneSignal device-proof item in `BUILD_PLAN.md`.

Offset logs in to OneSignal with the anonymous installation ID shown on this
screen. Only `journey_stage` and `premium_access` are synchronized remotely.
Saved-project details, matched program IDs and names, estimated savings,
deadlines, ZIP, utility, entered prices, and checklist progress remain on the
device. The richer in-memory retention plan is used solely to schedule local
notifications.

For a dashboard test message, put one of these pairs in **Additional Data**:

- `deep_link` = `offset://project/PROJECT_UUID`
- `deep_link` = `offset://program/PROGRAM_ID?project_id=PROJECT_UUID`

The equivalent separate keys `program_id` and `project_id` are also accepted.
Run the proof matrix with the app open, backgrounded, permission denied, and by
tapping a notification from a terminated launch. A program tap must open its
detail page and a saved-project tap must open that project's checklist context.

The app also reconciles device-local 30-, 14-, and 7-day alerts for every dated,
visible match with unfinished steps. Welcome, incomplete-onboarding, and
no-saved-project nudges are removed as soon as their state no longer applies.

The **Send local test in 3 seconds** button is available immediately and tests
iOS permission plus notification presentation without APNs. It is intentionally
not accepted as OneSignal registration or remote-delivery proof.

The release target includes a Notification Service Extension and shared App
Group for OneSignal rich-notification handling and confirmed-delivery support.
Confirm both entitlements in the signed archive before upload.
