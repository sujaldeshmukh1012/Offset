#!/bin/bash

set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
failures=0
warnings=0

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }
warn() { printf 'WARN  %s\n' "$1"; warnings=$((warnings + 1)); }

info_plist="$repo_root/Offset/Info.plist"
privacy_manifest="$repo_root/Offset/PrivacyInfo.xcprivacy"
seed="$repo_root/Data/offset_seed.json"
release_config="$repo_root/Offset/Configuration/Release.xcconfig"
secrets_config="$repo_root/Offset/Configuration/Secrets.xcconfig"
icon_manifest="$repo_root/Offset/Assets.xcassets/AppIcon.appiconset/Contents.json"
app_entitlements="$repo_root/Offset/Offset.entitlements"
nse_entitlements="$repo_root/OneSignalNotificationServiceExtension/OneSignalNotificationServiceExtension.entitlements"
nse_source="$repo_root/OneSignalNotificationServiceExtension/NotificationService.swift"
project_file="$repo_root/Offset.xcodeproj/project.pbxproj"
submission_packet="$repo_root/APP_STORE_SUBMISSION.md"
support_page="$repo_root/docs/index.html"
privacy_page="$repo_root/docs/privacy.html"

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

if rg -q 'PUBLIC_(SUPPORT|PRIVACY)_URL|SUPPORT_EMAIL' \
    "$submission_packet" "$support_page" "$privacy_page"; then
    warn "Public support/privacy URLs and contact email still require owner values"
else
    pass "Public support and privacy metadata is complete"
fi

printf '\nPreflight: %d failure(s), %d warning(s).\n' "$failures" "$warnings"
if [ "$failures" -ne 0 ]; then exit 1; fi
