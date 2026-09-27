import Foundation

enum ProgramStoreError: Error, Equatable {
    case resourceNotFound(String)
    case unsupportedSchemaVersion(Int)
    case invalidCatalog([String])
}

struct ProgramStore {
    static func loadCurrentCatalog(profile: UserProfile? = nil) throws -> ProgramCatalog {
        let dataset = try IncentiveDatasetStore.loadCurrent()
        let generatedAt = ISO8601DateFormatter().date(from: dataset.meta.generatedAt) ?? Date(timeIntervalSince1970: 0)
        let catalog = ProgramCatalog(
            schemaVersion: ProgramCatalog.currentSchemaVersion,
            generatedAt: generatedAt,
            programs: IncentiveDatasetStore.appPrograms(from: dataset, profile: profile)
        )
        try validate(catalog)
        return catalog
    }

    static func loadCurrentPrograms(profile: UserProfile? = nil) throws -> [Program] {
        try loadCurrentCatalog(profile: profile).programs
    }

    static func loadBundledCatalog(
        named resourceName: String = "offset_seed",
        bundle: Bundle = .main,
        profile: UserProfile? = nil
    ) throws -> ProgramCatalog {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw ProgramStoreError.resourceNotFound(resourceName)
        }
        if resourceName == "offset_seed" {
            let dataset = try IncentiveDatasetStore.decode(Data(contentsOf: url))
            let generatedAt = ISO8601DateFormatter().date(from: dataset.meta.generatedAt) ?? Date(timeIntervalSince1970: 0)
            let catalog = ProgramCatalog(
                schemaVersion: ProgramCatalog.currentSchemaVersion,
                generatedAt: generatedAt,
                programs: IncentiveDatasetStore.appPrograms(from: dataset, profile: profile)
            )
            try validate(catalog)
            return catalog
        }
        return try decodeCatalog(from: Data(contentsOf: url))
    }

    static func loadBundledPrograms(
        named resourceName: String = "offset_seed",
        bundle: Bundle = .main,
        profile: UserProfile? = nil
    ) throws -> [Program] {
        try loadBundledCatalog(named: resourceName, bundle: bundle, profile: profile).programs
    }

    static func decodeCatalog(from data: Data) throws -> ProgramCatalog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let catalog = try decoder.decode(ProgramCatalog.self, from: data)
        try validate(catalog)
        return catalog
    }

    static func validate(_ catalog: ProgramCatalog) throws {
        guard catalog.schemaVersion == ProgramCatalog.currentSchemaVersion else {
            throw ProgramStoreError.unsupportedSchemaVersion(catalog.schemaVersion)
        }

        var issues: [String] = []
        let duplicateIDs = Dictionary(grouping: catalog.programs, by: \Program.id)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        if !duplicateIDs.isEmpty {
            issues.append("Duplicate program IDs: \(duplicateIDs.joined(separator: ", "))")
        }

        for program in catalog.programs {
            let prefix = program.id.isEmpty ? "<missing-id>" : program.id
            if program.id.isEmpty || program.name.isEmpty || program.description.isEmpty {
                issues.append("\(prefix): id, name, and description are required")
            }
            if program.projectTypes.isEmpty {
                issues.append("\(prefix): at least one project type is required")
            }
            if program.claimSteps.isEmpty || program.eligibilitySummary.isEmpty {
                issues.append("\(prefix): claim steps and eligibility summary are required")
            }
            if URL(string: program.sourceURL)?.scheme?.lowercased() != "https" {
                issues.append("\(prefix): sourceURL must be HTTPS")
            }
            if let deadline = program.deadline, deadline < program.effectiveDate {
                issues.append("\(prefix): deadline precedes effectiveDate")
            }
            if program.level == .federal,
               (!program.eligibilityStates.isEmpty || !program.eligibilityUtilities.isEmpty) {
                issues.append("\(prefix): federal programs cannot restrict state or utility")
            }
            if program.level == .utility && program.eligibilityUtilities.isEmpty {
                issues.append("\(prefix): utility programs require a utility identifier")
            }
            if program.eligibilityStates.contains(where: { $0.count != 2 || $0 != $0.uppercased() }) {
                issues.append("\(prefix): state codes must be two uppercase letters")
            }
            if program.incomeCapsUSD.values.contains(where: { !$0.isFinite || $0 <= 0 })
                || program.vehiclePriceCapsUSD.values.contains(where: { !$0.isFinite || $0 <= 0 })
                || program.annualCaps.contains(where: { !$0.amountUSD.isFinite || $0.amountUSD <= 0 }) {
                issues.append("\(prefix): monetary caps must be finite and positive")
            }
            if !isValid(program.amountType) {
                issues.append("\(prefix): amount metadata is invalid")
            }
        }

        if !issues.isEmpty {
            throw ProgramStoreError.invalidCatalog(issues)
        }
    }

    private static func isValid(_ amount: AmountType) -> Bool {
        switch amount {
        case .percentage(let percentage):
            return percentage.isFinite && percentage >= 0 && percentage <= 1
        case .fixedAmount(let value):
            return value.isFinite && value >= 0
        case .upTo(let value, let percentage):
            return value.isFinite && value >= 0
                && percentage.isFinite && percentage >= 0 && percentage <= 1
        case .range(let minimum, let maximum):
            let validMinimum = minimum.map { $0.isFinite && $0 >= 0 } ?? true
            let validMaximum = maximum.map { $0.isFinite && $0 >= 0 } ?? true
            let ordered = minimum.flatMap { low in maximum.map { low <= $0 } } ?? true
            return validMinimum && validMaximum && ordered
        case .formula(let explanation), .taxBenefit(let explanation), .nonCash(let explanation):
            return !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .unknown:
            return true
        }
    }
}
