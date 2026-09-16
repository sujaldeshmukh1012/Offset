import Foundation

struct AppConfiguration: Equatable, Sendable {
    enum Key: String {
        case revenueCatAPIKey = "RevenueCatAPIKey"
        case revenueCatMonthlyProductID = "RevenueCatMonthlyProductID"
        case revenueCatAnnualProductID = "RevenueCatAnnualProductID"
        case revenueCatEntitlementID = "RevenueCatEntitlementID"
        case oneSignalAppID = "OneSignalAppID"
    }

    let revenueCatAPIKey: String?
    let revenueCatMonthlyProductID: String
    let revenueCatAnnualProductID: String
    let revenueCatEntitlementID: String
    let oneSignalAppID: String?

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
}
