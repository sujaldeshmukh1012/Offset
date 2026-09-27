import Foundation

enum LocationCatalogError: LocalizedError, Equatable {
    case missingResource
    case unsupportedSchema(Int)
    case invalidCatalog([String])

    var errorDescription: String? {
        switch self {
        case .missingResource:
            "The bundled location catalog could not be found."
        case .unsupportedSchema(let version):
            "Location catalog schema version \(version) is not supported."
        case .invalidCatalog(let issues):
            "The location catalog is invalid: \(issues.joined(separator: "; "))"
        }
    }
}

struct LocationService: Sendable {
    static let currentSchemaVersion = 1

    static var empty: Self {
        Self(validatedCatalog: LocationCatalog(
            schemaVersion: currentSchemaVersion,
            stateZIPRanges: [],
            utilityProviders: []
        ))
    }

    private let catalog: LocationCatalog

    init(catalog: LocationCatalog) throws {
        guard catalog.schemaVersion == Self.currentSchemaVersion else {
            throw LocationCatalogError.unsupportedSchema(catalog.schemaVersion)
        }
        var issues: [String] = []
        let states = catalog.stateZIPRanges.map { $0.state }
        let duplicateStates = Dictionary(grouping: states, by: { $0 }).filter { $0.value.count > 1 }.keys
        if !duplicateStates.isEmpty { issues.append("duplicate state ZIP ranges") }
        if catalog.stateZIPRanges.contains(where: { $0.state.count != 2 || $0.state != $0.state.uppercased() }) {
            issues.append("invalid state code")
        }
        if catalog.stateZIPRanges.flatMap(\.ranges).contains(where: {
            !(0...999).contains($0.lower) || !(0...999).contains($0.upper) || $0.lower > $0.upper
        }) {
            issues.append("invalid ZIP prefix range")
        }
        let utilityIDs = catalog.utilityProviders.map { $0.id }
        if Dictionary(grouping: utilityIDs, by: { $0 }).contains(where: { $0.value.count > 1 }) {
            issues.append("duplicate utility identifier")
        }
        let knownStates = Set(states)
        if catalog.utilityProviders.contains(where: {
            $0.id.isEmpty || $0.name.isEmpty || !knownStates.contains($0.state)
        }) {
            issues.append("invalid utility record")
        }
        if !issues.isEmpty { throw LocationCatalogError.invalidCatalog(issues.sorted()) }
        self.catalog = catalog
    }

    private init(validatedCatalog: LocationCatalog) {
        catalog = validatedCatalog
    }

    static func bundled(bundle: Bundle = .main) throws -> Self {
        guard let url = bundle.url(forResource: "location_catalog", withExtension: "json") else {
            throw LocationCatalogError.missingResource
        }
        return try decode(Data(contentsOf: url))
    }

    static func current(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) throws -> Self {
        if let cached = try? SupabaseCatalogCache.cachedLocationData(fileManager: fileManager),
           let service = try? decode(cached) {
            return service
        }
        return try bundled(bundle: bundle)
    }

    static func decode(_ data: Data) throws -> Self {
        try LocationService(catalog: validatedCatalog(from: data))
    }

    static func validatedCatalog(from data: Data) throws -> LocationCatalog {
        let catalog = try JSONDecoder().decode(LocationCatalog.self, from: data)
        _ = try LocationService(catalog: catalog)
        return catalog
    }

    func state(forZIPCode zipCode: String) -> String? {
        guard zipCode.count == 5,
              zipCode.allSatisfy(\.isNumber),
              let prefix = Int(zipCode.prefix(3)) else {
            return nil
        }

        return catalog.stateZIPRanges.first { stateRange in
            stateRange.ranges.contains { $0.lower...$0.upper ~= prefix }
        }?.state
    }

    func utilities(in state: String) -> [UtilityProvider] {
        catalog.utilityProviders
            .filter { $0.state == state.uppercased() }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func utilityName(for identifier: String) -> String? {
        catalog.utilityProviders.first { $0.id == identifier }?.name
    }
}
