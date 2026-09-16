import Foundation

struct CoverageAssessment: Equatable, Sendable {
    enum Confidence: Int, Equatable, Sendable {
        case unsupported = 0
        case discovery = 1
        case partial = 2
        case verifiedDynamic = 3
        case verified = 4
    }

    let confidence: Confidence
    let title: String
    let message: String
    let isProductionMarket: Bool
}

enum CoverageService {
    static func bundledAssessment(for project: ProjectType, profile: UserProfile) -> CoverageAssessment {
        guard let dataset = try? IncentiveDatasetStore.loadBundled() else {
            return .init(
                confidence: .unsupported,
                title: "Coverage unavailable",
                message: "Offset could not load its coverage record. No completeness claim is being made.",
                isProductionMarket: false
            )
        }
        return assessment(for: project, profile: profile, dataset: dataset)
    }

    static func assessment(
        for project: ProjectType,
        profile: UserProfile,
        dataset: IncentiveDataset
    ) -> CoverageAssessment {
        let state = profile.state.uppercased()
        let rawUtility = profile.utilityProvider.map(sourceUtilityID)
        let categories = categoryIDs(for: project, profile: profile)
        let stateRecord = dataset.states.first { $0.code == state }
        let relevant = dataset.coverage.filter { item in
            guard item.stateCode == state, categories.contains(item.categoryId) else { return false }
            if let itemUtility = item.utilityId { return itemUtility == rawUtility }
            return true
        }
        let utilitySpecific = relevant.filter { $0.utilityId != nil }
        let candidates = utilitySpecific.isEmpty ? relevant : utilitySpecific
        let best = candidates.max { confidence(for: $0.status).rawValue < confidence(for: $1.status).rawValue }
        let isProductionMarket = stateRecord?.coverageStatus == "verified_major_territories"

        guard let best else {
            return .init(
                confidence: .unsupported,
                title: "Coverage not verified",
                message: "Offset has not verified complete \(project.displayName.lowercased()) coverage for this location. This does not mean that no incentives exist.",
                isProductionMarket: isProductionMarket
            )
        }

        let resolvedConfidence = confidence(for: best.status)
        let marketSuffix = isProductionMarket
            ? ""
            : " This state remains a partial-coverage market, so local and regional programs may be missing."
        return .init(
            confidence: resolvedConfidence,
            title: title(for: resolvedConfidence),
            message: (best.notes ?? defaultMessage(for: resolvedConfidence)) + marketSuffix,
            isProductionMarket: isProductionMarket
        )
    }

    private static func categoryIDs(for project: ProjectType, profile: UserProfile) -> Set<String> {
        switch project {
        case .heatPump: ["heat_pump_hvac"]
        case .waterHeater: ["heat_pump_water_heater"]
        case .evPurchase:
            switch profile.vehicleCondition {
            case .new: ["ev_new"]
            case .used: ["ev_used"]
            case nil: ["ev_new", "ev_used"]
            }
        case .evCharger: ["ev_charger"]
        case .solar: ["solar"]
        case .batteryStorage: ["battery_storage"]
        case .insulation: ["insulation"]
        case .windows: ["windows"]
        case .ductwork: ["ductwork"]
        case .weatherization: ["weatherization"]
        }
    }

    private static func confidence(for status: String) -> CoverageAssessment.Confidence {
        switch status {
        case "verified": .verified
        case "verified_dynamic": .verifiedDynamic
        case "partial": .partial
        case "discovery_only": .discovery
        default: .unsupported
        }
    }

    private static func title(for confidence: CoverageAssessment.Confidence) -> String {
        switch confidence {
        case .verified: "Verified program coverage"
        case .verifiedDynamic: "Verified, with live details"
        case .partial: "Partial coverage"
        case .discovery: "Coverage research in progress"
        case .unsupported: "Coverage not verified"
        }
    }

    private static func defaultMessage(for confidence: CoverageAssessment.Confidence) -> String {
        switch confidence {
        case .verified: "Offset has verified a primary-source program for this project and location."
        case .verifiedDynamic: "A primary source is verified, but funding or program details require a current check."
        case .partial: "Some relevant programs are represented, but coverage is not comprehensive."
        case .discovery: "Official sources are known, but their program rules are not normalized for matching yet."
        case .unsupported: "Offset has not verified coverage for this combination."
        }
    }

    private static func sourceUtilityID(_ appID: String) -> String {
        [
            "national-grid-ny": "ny_national_grid", "con-edison": "ny_coned",
            "nyseg": "ny_nyseg", "rge": "ny_rge", "central-hudson": "ny_central_hudson",
            "orange-rockland": "ny_oru", "pseg-long-island": "ny_psegli",
            "pge": "ca_pge", "sce": "ca_sce", "sdge": "ca_sdge", "ladwp": "ca_ladwp",
            "smud": "ca_smud", "fpl": "fl_fpl", "duke-energy-florida": "fl_duke",
            "teco": "fl_teco", "jea": "fl_jea", "ouc": "fl_ouc", "gru": "fl_gru"
        ][appID] ?? appID
    }
}
