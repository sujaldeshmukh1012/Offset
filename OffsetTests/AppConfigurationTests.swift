import Testing
@testable import Offset

struct AppConfigurationTests {
    @Test func readsIntegrationValuesFromInfoDictionary() {
        let configuration = AppConfiguration(values: [
            "RevenueCatAPIKey": "appl_public_key",
            "RevenueCatMonthlyProductID": "com.example.monthly",
            "RevenueCatAnnualProductID": "com.example.annual",
            "RevenueCatEntitlementID": "premium",
            "OneSignalAppID": "11111111-1111-1111-1111-111111111111"
        ])

        #expect(configuration.revenueCatAPIKey == "appl_public_key")
        #expect(configuration.revenueCatProductIDs == ["com.example.monthly", "com.example.annual"])
        #expect(configuration.revenueCatEntitlementID == "premium")
        #expect(configuration.oneSignalAppID == "11111111-1111-1111-1111-111111111111")
    }

    @Test func rejectsPlaceholderSDKValues() {
        let configuration = AppConfiguration(values: [
            "RevenueCatAPIKey": "REPLACE_WITH_REVENUECAT_PUBLIC_SDK_KEY",
            "RevenueCatMonthlyProductID": "com.example.monthly",
            "RevenueCatAnnualProductID": "com.example.annual",
            "RevenueCatEntitlementID": "premium",
            "OneSignalAppID": "REPLACE_WITH_ONESIGNAL_APP_ID"
        ])

        #expect(configuration.revenueCatAPIKey == nil)
        #expect(configuration.oneSignalAppID == nil)
    }
}
