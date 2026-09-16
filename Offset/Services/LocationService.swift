import Foundation

enum LocationCatalogError: LocalizedError, Equatable {
    case missingResource
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .missingResource:
            "The bundled location catalog could not be found."
        case .unsupportedSchema(let version):
            "Location catalog schema version \(version) is not supported."
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
        self.catalog = catalog
    }

    private init(validatedCatalog: LocationCatalog) {
        catalog = validatedCatalog
    }

    static func bundled(bundle: Bundle = .main) throws -> Self {
        guard let url = bundle.url(forResource: "location_catalog", withExtension: "json") else {
            throw LocationCatalogError.missingResource
        }
        let data = try Data(contentsOf: url)
        return try LocationService(catalog: JSONDecoder().decode(LocationCatalog.self, from: data))
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
