#!/bin/bash

set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
failures=0
warnings=0

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }
warn() { printf 'WARN  %s\n' "$1"; warnings=$((warnings + 1)); }

screenshot_set_is_valid() {
    local directory="$1"
    local expected_width="$2"
    local expected_height="$3"
    local count=0
    local screenshot actual_width actual_height
    [ -d "$directory" ] || return 1
    for screenshot in "$directory"/*.png; do
        [ -f "$screenshot" ] || continue
        actual_width="$(sips -g pixelWidth "$screenshot" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
        actual_height="$(sips -g pixelHeight "$screenshot" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
        [ "$actual_width" = "$expected_width" ] && [ "$actual_height" = "$expected_height" ] || return 1
        count=$((count + 1))
    done
    [ "$count" -ge 4 ]
}

info_plist="$repo_root/Offset/Info.plist"
privacy_manifest="$repo_root/Offset/PrivacyInfo.xcprivacy"
seed="$repo_root/Data/offset_seed.json"
public_seed="$repo_root/Offset/Resources/offset_seed.json"
release_config="$repo_root/Offset/Configuration/Release.xcconfig"
secrets_config="$repo_root/Offset/Configuration/Secrets.xcconfig"
icon_manifest="$repo_root/Offset/Assets.xcassets/AppIcon.appiconset/Contents.json"
app_entitlements="$repo_root/Offset/Offset.entitlements"
nse_entitlements="$repo_root/OneSignalNotificationServiceExtension/OneSignalNotificationServiceExtension.entitlements"
nse_source="$repo_root/OneSignalNotificationServiceExtension/NotificationService.swift"
project_file="$repo_root/Offset.xcodeproj/project.pbxproj"
submission_packet="$repo_root/APP_STORE_SUBMISSION.md"
storekit_config="$repo_root/Offset/Resources/Offset.storekit"
shared_config="$repo_root/Offset/Configuration/Shared.xcconfig"
support_page="$repo_root/docs/index.html"
privacy_page="$repo_root/docs/privacy.html"
iphone_screenshot_dir="$repo_root/AppStoreAssets/Storefront/iPhone"
ipad_screenshot_dir="$repo_root/AppStoreAssets/Storefront/iPad"

if plutil -lint "$info_plist" >/dev/null; then pass "Info.plist is valid"; else fail "Info.plist is invalid"; fi
if plutil -lint "$privacy_manifest" >/dev/null; then pass "PrivacyInfo.xcprivacy is valid"; else fail "PrivacyInfo.xcprivacy is invalid"; fi

if jq -e '.meta.schema_version == "1" and (.programs | length > 0) and (.coverage | length > 0)' "$seed" >/dev/null; then
    pass "Normalized incentive catalog is present"
else
    fail "Normalized incentive catalog is missing or malformed"
fi

if jq -e '[.programs[] | select(.match_enabled == 1 and .publishable != 1)] | length == 0' "$seed" >/dev/null; then
    pass "Every match-enabled program is publishable"
else
    fail "Catalog contains a match-enabled, non-publishable program"
fi

if jq -e '[.programs[] | select(.match_enabled == 1 and (.last_verified_at == null or .source_url == null))] | length == 0' "$seed" >/dev/null; then
    pass "Every match-enabled program has a source and verification date"
else
    fail "A match-enabled program lacks provenance"
fi

dynamic_cutoff="$(date -v-30d '+%Y-%m-%d')"
standard_cutoff="$(date -v-45d '+%Y-%m-%d')"
if jq -e --arg dynamic_cutoff "$dynamic_cutoff" --arg standard_cutoff "$standard_cutoff" '
    [.programs[]
      | select(.match_enabled == 1)
      | select(
          (.status == "dynamic" and .last_verified_at[0:10] < $dynamic_cutoff)
          or (.status != "dynamic" and .last_verified_at[0:10] < $standard_cutoff)
        )
    ] | length == 0
  ' "$seed" >/dev/null; then
    pass "Every match-enabled program is inside its verification window"
else
    fail "A match-enabled program is outside its 30/45-day verification window"
fi

if rg -q 'Resources/programs.json' "$repo_root/Offset.xcodeproj/project.pbxproj"; then
    pass "Legacy sample catalog is excluded from the app target"
else
    fail "Legacy sample catalog may be copied into the release bundle"
fi

if rg -q 'Configuration/Secrets.xcconfig' "$project_file"; then
    pass "Local secrets file is excluded from the app target"
else
    fail "Local secrets file may be copied into the release bundle"
fi

if rg -q 'ITSAppUsesNonExemptEncryption' "$info_plist"; then pass "Export-compliance key is declared"; else fail "Export-compliance key is missing"; fi

if [ -f "$secrets_config" ] && rg -q '^ONESIGNAL_APP_ID[[:space:]]*=[[:space:]]*[0-9a-fA-F-]{36}[[:space:]]*$' "$secrets_config"; then
    pass "OneSignal App ID is configured"
else
    warn "OneSignal App ID is not configured in ignored Secrets.xcconfig"
fi

if [ -f "$secrets_config" ] && rg -q '^REVENUECAT_API_KEY[[:space:]]*=[[:space:]]*appl_' "$secrets_config"; then
    pass "Production RevenueCat iOS public SDK key is configured"
else
    warn "Production RevenueCat iOS public SDK key is not configured"
fi

if rg -q '^REVENUECAT_API_KEY[[:space:]]*=[[:space:]]*test_' \
    "$repo_root/Offset/Configuration"; then
    fail "A checked-in RevenueCat Test Store key is still configured"
else
    pass "No checked-in RevenueCat Test Store key is configured"
fi

if rg -q 'StoreKitConfigurationFileReference|use-live-store' \
    "$repo_root/Offset.xcodeproj/xcshareddata/xcschemes"; then
    fail "A shared launch scheme still overrides the official App Store purchase path"
else
    pass "Shared launch schemes use the official App Store purchase path"
fi

if plutil -lint "$app_entitlements" "$nse_entitlements" >/dev/null \
   && rg -q 'group\.com\.sujal\.Offset\.onesignal' "$app_entitlements" \
   && rg -q 'group\.com\.sujal\.Offset\.onesignal' "$nse_entitlements" \
   && rg -q 'OneSignalExtension\.didReceiveNotificationExtensionRequest' "$nse_source" \
   && rg -q 'OneSignalNotificationServiceExtension\.appex in Embed Foundation Extensions' "$project_file" \
   && rg -q 'kind = exactVersion;' "$project_file" \
   && rg -q 'version = 5\.5\.1;' "$project_file"; then
    pass "OneSignal 5.5.1 push infrastructure is complete"
else
    fail "OneSignal extension, App Group, or exact SDK pin is incomplete"
fi

if jq -e '[.images[] | select(.idiom == "ios-marketing" and .size == "1024x1024" and (.filename | length > 0))] | length > 0' "$icon_manifest" >/dev/null 2>&1; then
    pass "Final 1024×1024 App Store icon is configured"
else
    warn "Final iOS app icon is still required"
fi

if rg -q '^SWIFT_TREAT_WARNINGS_AS_ERRORS[[:space:]]*=[[:space:]]*YES' "$release_config"; then
    pass "Release warnings are treated as errors"
else
    fail "Release warnings are not treated as errors"
fi

if jq -e '
    [.subscriptionGroups[].subscriptions[]
      | { productID, recurringSubscriptionPeriod }
    ] as $subscriptions
    | ($subscriptions | length == 2)
      and ($subscriptions | any(
        .productID == "com.sujal.Offset.premium.monthly"
        and .recurringSubscriptionPeriod == "P1M"
      ))
      and ($subscriptions | any(
        .productID == "com.sujal.Offset.premium.annual"
        and .recurringSubscriptionPeriod == "P1Y"
      ))
  ' "$storekit_config" >/dev/null \
  && rg -q '^REVENUECAT_MONTHLY_PRODUCT_ID[[:space:]]*=[[:space:]]*com\.sujal\.Offset\.premium\.monthly[[:space:]]*$' "$shared_config" \
  && rg -q '^REVENUECAT_ANNUAL_PRODUCT_ID[[:space:]]*=[[:space:]]*com\.sujal\.Offset\.premium\.annual[[:space:]]*$' "$shared_config" \
  && rg -q '^REVENUECAT_ENTITLEMENT_ID[[:space:]]*=[[:space:]]*offset_pro[[:space:]]*$' "$shared_config"; then
    pass "StoreKit, RevenueCat product IDs, durations, and entitlement agree"
else
    fail "StoreKit and RevenueCat subscription configuration has drifted"
fi

if rg -q 'PUBLIC_(SUPPORT|PRIVACY)_URL|SUPPORT_EMAIL' \
    "$submission_packet" "$support_page" "$privacy_page"; then
    fail "Public support/privacy URLs and contact email still require owner values"
else
    pass "Public support and privacy metadata is complete"
fi

if rg -q '\| UNKNOWN \|' "$repo_root/ASSET_PROVENANCE.md"; then
    fail "Document or replace every asset marked UNKNOWN in ASSET_PROVENANCE.md"
else
    pass "Bundled opportunity assets have recorded provenance"
fi

if [ -f "$secrets_config" ] \
   && rg -q '^PRIVACY_POLICY_URL[[:space:]]*=[[:space:]]*https:' "$secrets_config" \
   && rg -q '^SUPPORT_URL[[:space:]]*=[[:space:]]*https:' "$secrets_config"; then
    pass "Public privacy and support URLs are configured for the app"
else
    fail "Set PRIVACY_POLICY_URL and SUPPORT_URL in ignored Secrets.xcconfig"
fi

if [ -f "$secrets_config" ] \
   && rg -q '^SUPABASE_URL[[:space:]]*=[[:space:]]*https:' "$secrets_config" \
   && rg -q '^SUPABASE_PUBLISHABLE_KEY[[:space:]]*=[[:space:]]*(sb_publishable_|eyJ)' "$secrets_config" \
   && rg -q '<key>SupabaseURL</key>' "$info_plist" \
   && rg -q '<key>SupabasePublishableKey</key>' "$info_plist"; then
    pass "Supabase backend identity is configured"
else
    fail "Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in ignored Secrets.xcconfig"
fi

if jq -e '.programs | length == 0' "$public_seed" >/dev/null \
   && ! rg -q 'Data/offset_seed\.json in Resources' "$project_file" \
   && rg -q 'CONFIGURATION.*Debug.*offset_seed_debug\.json' "$project_file" \
   && rg -q 'public[[:space:]]*=[[:space:]]*false' "$repo_root/supabase/migrations/20260925010000_lock_premium_catalog.sql" \
   && rg -q 'Offset catalogs are server only' "$repo_root/supabase/migrations/20260925010000_lock_premium_catalog.sql" \
   && rg -q 'api\.revenuecat\.com/v1/subscribers' "$repo_root/supabase/functions/premium-catalog/index.ts"; then
    pass "Premium catalog is excluded from the app and server-gated"
else
    fail "Premium catalog must remain private, unbundled, and entitlement-gated"
fi

if rg -q 'Supabase' "$privacy_page" \
   && [ -x "$repo_root/scripts/prepare_supabase_catalog.sh" ]; then
    pass "Supabase disclosure and catalog staging helper are present"
else
    fail "Supabase catalog disclosure or staging helper is missing"
fi


if screenshot_set_is_valid "$iphone_screenshot_dir" 1320 2868; then
    pass "iPhone storefront screenshots are present at 1320×2868"
else
    warn "At least four 1320×2868 iPhone storefront screenshots are required"
fi

if screenshot_set_is_valid "$ipad_screenshot_dir" 2064 2752; then
    pass "iPad storefront screenshots are present at 2064×2752"
else
    warn "At least four 2064×2752 iPad storefront screenshots are required for the universal target"
fi

printf '\nPreflight: %d failure(s), %d warning(s).\n' "$failures" "$warnings"
if [ "$failures" -ne 0 ]; then exit 1; fi
