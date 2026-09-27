import Foundation

struct AppConfiguration: Equatable, Sendable {
    enum Key: String {
        case revenueCatAPIKey = "RevenueCatAPIKey"
        case revenueCatMonthlyProductID = "RevenueCatMonthlyProductID"
        case revenueCatAnnualProductID = "RevenueCatAnnualProductID"
        case revenueCatEntitlementID = "RevenueCatEntitlementID"
        case oneSignalAppID = "OneSignalAppID"
        case privacyPolicyURL = "PrivacyPolicyURL"
        case supportURL = "SupportURL"
        case supabaseURL = "SupabaseURL"
        case supabasePublishableKey = "SupabasePublishableKey"
        case supabasePremiumCatalogFunction = "SupabasePremiumCatalogFunction"
    }

    let revenueCatAPIKey: String?
    let revenueCatMonthlyProductID: String
    let revenueCatAnnualProductID: String
    let revenueCatEntitlementID: String
    let oneSignalAppID: String?
    let privacyPolicyURL: URL?
    let supportURL: URL?
    let supabaseURL: URL?
    let supabasePublishableKey: String?
    let supabasePremiumCatalogFunction: String

    var revenueCatProductIDs: [String] {
        [revenueCatMonthlyProductID, revenueCatAnnualProductID]
    }

    init(bundle: Bundle = .main) {
        self.init(values: bundle.infoDictionary ?? [:])
    }

    init(values: [String: Any]) {
        revenueCatAPIKey = Self.configuredValue(values[Key.revenueCatAPIKey.rawValue])
        revenueCatMonthlyProductID = Self.requiredValue(
            values[Key.revenueCatMonthlyProductID.rawValue],
            key: .revenueCatMonthlyProductID
        )
        revenueCatAnnualProductID = Self.requiredValue(
            values[Key.revenueCatAnnualProductID.rawValue],
            key: .revenueCatAnnualProductID
        )
        revenueCatEntitlementID = Self.requiredValue(
            values[Key.revenueCatEntitlementID.rawValue],
            key: .revenueCatEntitlementID
        )
        oneSignalAppID = Self.configuredValue(values[Key.oneSignalAppID.rawValue])
        privacyPolicyURL = Self.configuredHTTPSURL(values[Key.privacyPolicyURL.rawValue])
        supportURL = Self.configuredHTTPSURL(values[Key.supportURL.rawValue])
        supabaseURL = Self.configuredSupabaseURL(values[Key.supabaseURL.rawValue])
        supabasePublishableKey = Self.configuredValue(values[Key.supabasePublishableKey.rawValue])
        supabasePremiumCatalogFunction = Self.configuredValue(
            values[Key.supabasePremiumCatalogFunction.rawValue]
        ) ?? "premium-catalog"
    }

    private static func requiredValue(_ rawValue: Any?, key _: Key) -> String {
        guard let value = configuredValue(rawValue) else {
            return ""
        }
        return value
    }

    private static func configuredValue(_ rawValue: Any?) -> String? {
        guard let value = rawValue as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("REPLACE_WITH_"),
              !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    private static func configuredHTTPSURL(_ rawValue: Any?) -> URL? {
        guard let value = configuredValue(rawValue),
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }

    private static func configuredSupabaseURL(_ rawValue: Any?) -> URL? {
        guard let url = configuredHTTPSURL(rawValue),
              url.path.isEmpty || url.path == "/",
              url.host?.hasSuffix(".supabase.co") == true else { return nil }
        return url
    }
}
