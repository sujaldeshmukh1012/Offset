# Offset App Review Operations

Use this checklist for the production App Store submission. The identifiers below must match exactly.

## 1. Release inputs

1. Replace every `SUPPORT_EMAIL` placeholder in `docs/` and `APP_STORE_SUBMISSION.md` with a monitored address.
2. Publish only `docs/` to an HTTPS website. This repository contains the
   private authoring copy of the paid catalog in `Data/offset_seed.json`, so
   never make the complete repository public. Use a private repository's Pages
   deployment or copy only `docs/` into a separate public site repository.
   Confirm the support page and `privacy.html` load without authentication.
3. Add the public URLs to the ignored `Offset/Configuration/Secrets.xcconfig`. xcconfig files require the extra `$()` between the URL slashes:

   ```xcconfig
   PRIVACY_POLICY_URL = https:/$()/example.com/privacy.html
   SUPPORT_URL = https:/$()/example.com/
   ```

4. In App Store Connect, put the privacy URL in **App Information > Privacy Policy URL** and the support URL in the version's **Support URL** field.
5. Keep the AI generator records and provider commercial-use terms supporting every `DOCUMENTED` row in `ASSET_PROVENANCE.md`.
6. Run `./scripts/release_preflight.sh`. Do not submit while it reports a failure.

## 2. Complete the App Store subscriptions

Before configuring products, open **App Store Connect > Business** and confirm the Paid Applications Agreement is active and banking and tax setup have no outstanding actions.

Under **Apps > Offset > Monetization > Subscriptions**:

1. Create one subscription group named `Offset Premium`.
2. Create the monthly subscription:
   - Reference name: `Offset Premium Monthly`
   - Product ID: `com.sujal.Offset.premium.monthly`
   - Duration: 1 month
   - US price: USD 4.99
   - English display name: `Offset Premium Monthly`
   - English description: `Full savings, checklists, unlimited projects.`
3. Create the annual subscription in the same group:
   - Reference name: `Offset Premium Annual`
   - Product ID: `com.sujal.Offset.premium.annual`
   - Duration: 1 year
   - US price: USD 39.99
   - English display name: `Offset Premium Annual`
   - English description: `Full savings, checklists, unlimited projects.`
4. Select the intended storefront availability for both products. Offset's current incentive data and review positioning are US-specific, so use US availability unless the product and metadata are deliberately localized for other regions.
5. Add the subscription-group localization and the required App Review screenshot. Use `AppStoreAssets/Offset-Premium-Review.png` after confirming it matches the submitted build.
6. Put monthly and annual at the same subscription level because they unlock identical content and differ only by duration. Apple treats movement between equal-content durations at the same level as a crossgrade.
7. For the first subscription submission, open the new app version and add both subscriptions under **In-App Purchases and Subscriptions** before submitting the version for review.

## 3. Configure RevenueCat

1. Confirm the RevenueCat Apple app bundle ID is `com.sujal.Offset`.
2. Under its store credentials, configure an App Store Connect API key, an Apple In-App Purchase key (`.p8`, Key ID, and Issuer ID), and any App Store Server Notification item RevenueCat flags as incomplete.
3. Import these products into **Product Catalog > Products**:
   - `com.sujal.Offset.premium.monthly`
   - `com.sujal.Offset.premium.annual`
4. Confirm the entitlement identifier `offset_pro` and attach both products.
5. Create an offering such as `default`, make it **Current**, and add:
   - Package `$rc_monthly` -> `com.sujal.Offset.premium.monthly`
   - Package `$rc_annual` -> `com.sujal.Offset.premium.annual`
6. Put only the RevenueCat public Apple SDK key beginning with `appl_` in `Secrets.xcconfig`. Never add a RevenueCat secret key to the app.
7. Complete `SUPABASE_CATALOG_SETUP.md`: keep `offset-catalogs` private, deploy
   `premium-catalog`, put the RevenueCat secret key only in Edge Function
   secrets, and enable anonymous Supabase sign-ins.

### RevenueCat acceptance test

1. On a physical device, run the `Offset-Sandbox` scheme or install through TestFlight.
2. Open premium. Both products must show localized prices returned by StoreKit.
3. Buy monthly with a Sandbox Apple Account. In RevenueCat **Customers**, confirm the environment is Sandbox, the monthly product is present, and entitlement `offset_pro` is active.
   Confirm the RevenueCat App User ID is the same UUID shown for the anonymous
   Supabase user, then verify protected rebate data loads.
4. Delete and reinstall, choose **Restore Purchases**, and confirm premium access returns.
5. Repeat with annual, then test sandbox renewal, cancellation, and expiration.

## 4. Configure APNs and OneSignal

### Apple Developer setup

1. In **Certificates, Identifiers & Profiles > Identifiers**, enable Push Notifications for `com.sujal.Offset`.
2. Confirm app group `group.com.sujal.Offset.onesignal` is assigned to the main app and notification-service extension identifiers.
3. Under **Keys**, create an APNs key, download the `.p8` once, and record its Key ID and the developer Team ID. Keep it outside the repository.
4. Regenerate provisioning profiles if their capabilities are stale.

### OneSignal setup

1. Open **OneSignal > App > Settings > Push & In-App > Apple iOS APNs**.
2. Upload the APNs `.p8` and enter its Key ID, Team ID, and bundle ID `com.sujal.Offset`.
3. Put the OneSignal App ID UUID in `ONESIGNAL_APP_ID` in `Secrets.xcconfig`.
4. Use automatic signing for both targets with the same paid team. For a physical Debug build, ensure `CODE_SIGN_ENTITLEMENTS = Offset/Offset.entitlements` is enabled in Debug; Release already uses production APNs.

### Push acceptance test

1. Delete Offset from a physical device, reinstall, and launch it.
2. Reach the reminder value prompt, enable reminders, and accept the system permission.
3. In OneSignal **Audience > Users & Subscriptions**, find the device and confirm it is `Subscribed`, platform iOS, with a push token.
4. Mark it as a test subscription and send a test notification.
5. Verify receipt while foregrounded, backgrounded, and terminated, and verify tapping opens the app.
6. Test project routing with notification additional data:
   - `deep_link`: `offset://project/PROJECT_UUID`
   - `deep_link`: `offset://program/PROGRAM_ID?project_id=PROJECT_UUID`
7. Deny permission on a clean install and confirm Settings explains how to re-enable it.
8. Repeat with TestFlight. The in-app three-second notification test is local-only and does not prove APNs delivery.

## 5. Device QA and review recording

Use a supported physical device on the latest public iOS release and the exact submitted build.

1. Cold launch Offset.
2. Complete onboarding and the normal project-estimate flow.
3. Open an incentive result and its checklist.
4. Open premium; clearly show monthly and annual title, duration, localized price, Terms of Use, and Privacy Policy.
5. Complete a sandbox purchase, demonstrate premium access, and demonstrate Restore Purchases.
6. Show notification permission and receipt of a real OneSignal test push.
7. Open Settings and show privacy, support, terms, and restore links.
8. Upload the recording somewhere reviewers can open without requesting access. Put the link and Apple's requested answers in both the Resolution Center reply and App Review Notes.

## Official references

- Apple: [Configure in-app purchases](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases)
- Apple: [Test in-app purchases in sandbox](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox)
- RevenueCat: [iOS products, entitlements, and offerings](https://www.revenuecat.com/docs/getting-started/entitlements/ios-products)
- RevenueCat: [Apple In-App Purchase key](https://www.revenuecat.com/docs/service-credentials/itunesconnect-app-specific-shared-secret/in-app-purchase-key-configuration)
- OneSignal: [iOS SDK setup](https://documentation.onesignal.com/docs/en/ios-sdk-setup)
- OneSignal: [APNs p8 setup](https://documentation.onesignal.com/docs/en/ios-p8-token-based-connection-to-apns)
