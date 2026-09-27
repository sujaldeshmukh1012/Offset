import Foundation
import Testing
@testable import Offset

struct AppConfigurationTests {
    @Test func readsIntegrationValuesFromInfoDictionary() {
        let configuration = AppConfiguration(values: [
            "RevenueCatAPIKey": "appl_public_key",
            "RevenueCatMonthlyProductID": "com.example.monthly",
            "RevenueCatAnnualProductID": "com.example.annual",
            "RevenueCatEntitlementID": "offset_pro",
            "OneSignalAppID": "11111111-1111-1111-1111-111111111111",
            "PrivacyPolicyURL": "https://example.com/privacy",
            "SupportURL": "https://example.com/support",
            "SupabaseURL": "https://project.supabase.co",
            "SupabasePublishableKey": "sb_publishable_example",
            "SupabasePremiumCatalogFunction": "premium-catalog"
        ])

        #expect(configuration.revenueCatAPIKey == "appl_public_key")
        #expect(configuration.revenueCatProductIDs == ["com.example.monthly", "com.example.annual"])
        #expect(configuration.revenueCatEntitlementID == "offset_pro")
        #expect(configuration.oneSignalAppID == "11111111-1111-1111-1111-111111111111")
        #expect(configuration.privacyPolicyURL == URL(string: "https://example.com/privacy"))
        #expect(configuration.supportURL == URL(string: "https://example.com/support"))
        #expect(configuration.supabaseURL == URL(string: "https://project.supabase.co"))
        #expect(configuration.supabasePublishableKey == "sb_publishable_example")
        #expect(configuration.supabasePremiumCatalogFunction == "premium-catalog")
    }

    @Test func rejectsPlaceholderSDKValues() {
        let configuration = AppConfiguration(values: [
            "RevenueCatAPIKey": "REPLACE_WITH_REVENUECAT_PUBLIC_SDK_KEY",
            "RevenueCatMonthlyProductID": "com.example.monthly",
            "RevenueCatAnnualProductID": "com.example.annual",
            "RevenueCatEntitlementID": "offset_pro",
            "OneSignalAppID": "REPLACE_WITH_ONESIGNAL_APP_ID"
        ])

        #expect(configuration.revenueCatAPIKey == nil)
        #expect(configuration.oneSignalAppID == nil)
    }

    @Test func rejectsMissingOrInsecureBackendConfiguration() {
        let configuration = AppConfiguration(values: [
            "RevenueCatMonthlyProductID": "com.example.monthly",
            "RevenueCatAnnualProductID": "com.example.annual",
            "RevenueCatEntitlementID": "offset_pro",
            "PrivacyPolicyURL": "http://example.com/privacy",
            "SupportURL": "REPLACE_WITH_SUPPORT_URL",
            "SupabaseURL": "http://project.supabase.co",
            "SupabasePublishableKey": "REPLACE_WITH_SUPABASE_PUBLISHABLE_KEY"
        ])

        #expect(configuration.privacyPolicyURL == nil)
        #expect(configuration.supportURL == nil)
        #expect(configuration.supabaseURL == nil)
        #expect(configuration.supabasePublishableKey == nil)
    }
}
