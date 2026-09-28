import Foundation

enum SupabaseCatalogError: LocalizedError, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case payloadTooLarge
    case catalogRollback
    case incompatibleUtilityCatalog([String])
    case premiumRequired
    case invalidCatalogEnvelope

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Supabase returned an invalid response."
        case .httpStatus(let status):
            "Supabase returned HTTP \(status)."
        case .payloadTooLarge:
            "The remote catalog exceeded the allowed size."
        case .catalogRollback:
            "The remote incentive catalog is older than the installed catalog."
        case .incompatibleUtilityCatalog(let utilityIDs):
            "The location catalog is missing supported utilities: \(utilityIDs.joined(separator: ", "))."
        case .premiumRequired:
            "An active Offset Premium subscription is required for live catalog updates."
        case .invalidCatalogEnvelope:
            "The secure catalog service returned an invalid response."
        }
    }
}

enum SupabaseCatalogCache {
    static let maximumPayloadBytes = 2_000_000
    private static let directoryName = "VerifiedSupabaseCatalogs"
    private static let incentiveFilename = "offset_seed.json"
    private static let locationFilename = "location_catalog.json"

    static func cachedIncentiveData(fileManager: FileManager = .default) throws -> Data? {
        try cachedData(named: incentiveFilename, fileManager: fileManager)
    }

    static func cachedLocationData(fileManager: FileManager = .default) throws -> Data? {
        try cachedData(named: locationFilename, fileManager: fileManager)
    }

    static func removePremiumData(fileManager: FileManager = .default) throws {
        let directory = try cacheDirectory(fileManager: fileManager)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        for filename in [incentiveFilename, locationFilename] {
            let url = directory.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    @discardableResult
    static func installIncentiveData(
        _ data: Data,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) throws -> Bool {
        let current = try IncentiveDatasetStore.loadCurrent(bundle: bundle, fileManager: fileManager)
        guard try validatedIncentiveUpdate(data, comparedWith: current) != nil else { return false }
        return try install(data, named: incentiveFilename, fileManager: fileManager)
    }

    static func validatedIncentiveUpdate(
        _ data: Data,
        comparedWith current: IncentiveDataset
    ) throws -> IncentiveDataset? {
        try validateSize(data)
        let incoming = try IncentiveDatasetStore.decode(data)
        guard let incomingDate = parseISO8601(incoming.meta.generatedAt),
              let currentDate = parseISO8601(current.meta.generatedAt),
              incomingDate >= currentDate else {
            throw SupabaseCatalogError.catalogRollback
        }
        return incomingDate == currentDate ? nil : incoming
    }

    static func validateRelease(incentiveData: Data, locationData: Data) throws {
        try validateSize(incentiveData)
        try validateSize(locationData)
        let incentives = try IncentiveDatasetStore.decode(incentiveData)
        let locations = try LocationService.validatedCatalog(from: locationData)
        let knownUtilityIDs = Set(locations.utilityProviders.map(\.id))
        let requiredUtilityIDs = Set(
            incentives.utilities
                .filter { $0.supported == 1 }
                .map { IncentiveDatasetStore.appUtilityID($0.id) }
        )
        let missingUtilityIDs = requiredUtilityIDs.subtracting(knownUtilityIDs).sorted()
        guard missingUtilityIDs.isEmpty else {
            throw SupabaseCatalogError.incompatibleUtilityCatalog(missingUtilityIDs)
        }
    }

    @discardableResult
    static func installLocationData(
        _ data: Data,
        fileManager: FileManager = .default
    ) throws -> Bool {
        try validateSize(data)
        _ = try LocationService.decode(data)
        return try install(data, named: locationFilename, fileManager: fileManager)
    }

    private static func cachedData(named filename: String, fileManager: FileManager) throws -> Data? {
        let url = try cacheDirectory(fileManager: fileManager).appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    private static func install(_ data: Data, named filename: String, fileManager: FileManager) throws -> Bool {
        let directory = try cacheDirectory(fileManager: fileManager)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var directoryURL = directory
        try? directoryURL.setResourceValues(resourceValues)

        let destination = directory.appendingPathComponent(filename)
        if let existing = try? Data(contentsOf: destination), existing == data { return false }
        try data.write(to: destination, options: .atomic)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destination.path
        )
        return true
    }

    private static func cacheDirectory(fileManager: FileManager) throws -> URL {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return base.appendingPathComponent("Offset", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func validateSize(_ data: Data) throws {
        guard !data.isEmpty, data.count <= maximumPayloadBytes else {
            throw SupabaseCatalogError.payloadTooLarge
        }
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

@MainActor
final class SupabaseCatalogService: ObservableObject {
    enum State: Equatable {
        case restricted
        case cached
        case refreshing
        case current(Date)
        case unavailable(String)
    }

    @Published private(set) var revision = 0
    @Published private(set) var state: State

    private let configuration: AppConfiguration
    private let session: URLSession
    private let identityService: SupabaseIdentityService
    private let defaults: UserDefaults
    private let refreshInterval: TimeInterval
    private let retryInterval: TimeInterval
    private let successfulRefreshKey = "offset.supabase-catalog.last-success.v1"
    private let refreshAttemptKey = "offset.supabase-catalog.last-attempt.v1"

    init(
        configuration: AppConfiguration,
        session: URLSession = .shared,
        identityService: SupabaseIdentityService? = nil,
        defaults: UserDefaults = .standard,
        refreshInterval: TimeInterval = 6 * 60 * 60,
        retryInterval: TimeInterval = 15 * 60
    ) {
        self.configuration = configuration
        self.session = session
        self.identityService = identityService ?? SupabaseIdentityService(
            configuration: configuration,
            session: session
        )
        self.defaults = defaults
        self.refreshInterval = refreshInterval
        self.retryInterval = retryInterval
        // Never trust a catalog left by an earlier process before the server has
        // reverified the current RevenueCat entitlement for this launch.
        try? SupabaseCatalogCache.removePremiumData()
        defaults.removeObject(forKey: successfulRefreshKey)
        state = .restricted
    }

    var statusDescription: String {
        switch state {
        case .restricted: "Using the included verified catalog. Premium unlocks complete details and saved projects."
        case .cached: "Using the latest entitlement-verified catalog saved for this session."
        case .refreshing: "Verifying Premium and checking for rebate updates…"
        case .current(let date): "Premium rebate data verified \(date.formatted(date: .abbreviated, time: .shortened))."
        case .unavailable: "The live catalog update could not be verified. The included catalog remains available."
        }
    }

    func prepareIdentity() async -> String? {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing-") }) {
            return nil
        }
#endif
        do {
            return try await identityService.authenticatedSession().userID.uuidString.lowercased()
        } catch {
            state = .unavailable(error.localizedDescription)
            return nil
        }
    }

    func refreshIfNeeded(
        hasPremiumAccess: Bool,
        force: Bool = false,
        now: Date = Date()
    ) async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing-") }) { return }
#endif
        guard hasPremiumAccess else {
            let hadCatalog = (try? SupabaseCatalogCache.cachedIncentiveData()) != nil
            try? SupabaseCatalogCache.removePremiumData()
            defaults.removeObject(forKey: successfulRefreshKey)
            state = .restricted
            if hadCatalog { revision += 1 }
            return
        }
        guard configuration.supabaseURL != nil,
              configuration.supabasePublishableKey != nil else {
            state = .unavailable(SupabaseIdentityError.notConfigured.localizedDescription)
            return
        }

        if !force {
            if let success = defaults.object(forKey: successfulRefreshKey) as? Date,
               now.timeIntervalSince(success) < refreshInterval { return }
            if let attempt = defaults.object(forKey: refreshAttemptKey) as? Date,
               now.timeIntervalSince(attempt) < retryInterval { return }
        }

        defaults.set(now, forKey: refreshAttemptKey)
        state = .refreshing
        do {
            let authenticated = try await identityService.authenticatedSession()
            let (incentiveData, locationData) = try await downloadPremiumReleaseWithRetry(
                accessToken: authenticated.accessToken
            )

            // Validate the complete release before installing either half, including
            // the relationship between supported incentives and selectable utilities.
            try SupabaseCatalogCache.validateRelease(
                incentiveData: incentiveData,
                locationData: locationData
            )
            let current = try IncentiveDatasetStore.loadCurrent()
            _ = try SupabaseCatalogCache.validatedIncentiveUpdate(incentiveData, comparedWith: current)
            _ = try LocationService.decode(locationData)

            var changed = false
            changed = try SupabaseCatalogCache.installLocationData(locationData) || changed
            changed = try SupabaseCatalogCache.installIncentiveData(incentiveData) || changed
            if changed { revision += 1 }
            defaults.set(now, forKey: successfulRefreshKey)
            state = .current(now)
        } catch {
            state = .unavailable(error.localizedDescription)
        }
    }

    private struct PremiumCatalogEnvelope: Decodable {
        let incentiveCatalogBase64: String
        let locationCatalogBase64: String
    }

    private func downloadPremiumReleaseWithRetry(accessToken: String) async throws -> (Data, Data) {
        var lastError: Error = SupabaseCatalogError.premiumRequired
        for attempt in 0..<3 {
            do {
                return try await downloadPremiumRelease(accessToken: accessToken)
            } catch SupabaseCatalogError.premiumRequired {
                lastError = SupabaseCatalogError.premiumRequired
                guard attempt < 2 else { break }
                try await Task.sleep(for: .seconds(attempt == 0 ? 2 : 4))
            } catch {
                throw error
            }
        }
        throw lastError
    }

    private func downloadPremiumRelease(accessToken: String) async throws -> (Data, Data) {
        guard let baseURL = configuration.supabaseURL,
              let publishableKey = configuration.supabasePublishableKey else {
            throw SupabaseIdentityError.notConfigured
        }
        let url = baseURL
            .appendingPathComponent("functions/v1")
            .appendingPathComponent(configuration.supabasePremiumCatalogFunction)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("{}".utf8)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SupabaseCatalogError.invalidResponse
        }
        if response.statusCode == 402 || response.statusCode == 403 {
            throw SupabaseCatalogError.premiumRequired
        }
        guard response.statusCode == 200 else {
            throw SupabaseCatalogError.httpStatus(response.statusCode)
        }
        guard data.count <= SupabaseCatalogCache.maximumPayloadBytes * 3 else {
            throw SupabaseCatalogError.payloadTooLarge
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope = try decoder.decode(PremiumCatalogEnvelope.self, from: data)
        guard let incentiveData = Data(base64Encoded: envelope.incentiveCatalogBase64),
              let locationData = Data(base64Encoded: envelope.locationCatalogBase64) else {
            throw SupabaseCatalogError.invalidCatalogEnvelope
        }
        return (incentiveData, locationData)
    }
}
