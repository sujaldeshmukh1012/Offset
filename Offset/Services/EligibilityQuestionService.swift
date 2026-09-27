import Foundation

struct EligibilityQuestion: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case boolean
        case number(suffix: String)
        case choice([Choice])
    }

    struct Choice: Identifiable, Equatable, Sendable {
        let value: String
        let label: String
        var id: String { value }
    }

    let id: String
    let title: String
    let help: String
    let kind: Kind
}

enum EligibilityQuestionService {
    static func currentQuestions(for project: ProjectType, profile: UserProfile) -> [EligibilityQuestion] {
        guard let dataset = try? IncentiveDatasetStore.loadCurrent() else { return fallbackQuestions(for: project) }
        return questions(for: project, profile: profile, dataset: dataset)
    }

    static func bundledQuestions(for project: ProjectType, profile: UserProfile) -> [EligibilityQuestion] {
        guard let dataset = try? IncentiveDatasetStore.loadBundled() else { return fallbackQuestions(for: project) }
        return questions(for: project, profile: profile, dataset: dataset)
    }

    static func questions(
        for project: ProjectType,
        profile: UserProfile,
        dataset: IncentiveDataset
    ) -> [EligibilityQuestion] {
        let categoriesByProgram = Dictionary(grouping: dataset.programCategories, by: \.programId)
        let relevantPrograms = dataset.programs.filter { record in
            guard record.publishable == 1,
                  record.matchEnabled == 1,
                  ["active", "dynamic"].contains(record.status),
                  record.stateCode == nil || record.stateCode == profile.state.uppercased() else { return false }
            if let utilityID = record.utilityId,
               appUtilityID(utilityID) != profile.utilityProvider { return false }
            return (categoriesByProgram[record.id] ?? []).contains { projectCategories(project).contains($0.categoryId) }
        }
        let programIDs = Set(relevantPrograms.map(\.id))
        var fields = Set(
            dataset.eligibilityRules
                .filter { programIDs.contains($0.programId) && $0.blocking == 1 }
                .map(\.field)
        )

        for tier in dataset.incentiveTiers where programIDs.contains(tier.programId) {
            guard tierCouldApply(tier.conditionsJson, to: project) else { continue }
            fields.formUnion(conditionFields(in: tier.conditionsJson))
        }
        fields.subtract(["state", "utility_id", "residence_type", "category"])
        if project == .evPurchase { fields.insert("vehicle_condition") }

        return definitions.filter { fields.contains($0.id) }
    }

    static func answer(for field: String, in profile: UserProfile) -> EligibilityAnswer? {
        switch field {
        case "vehicle_condition": profile.vehicleCondition.map { .text($0.rawValue) }
        case "vehicle_category": profile.vehicleCategory.map { .text($0.rawValue) }
        default: profile.eligibilityAnswers[field]
        }
    }

    private static func fallbackQuestions(for project: ProjectType) -> [EligibilityQuestion] {
        project == .evPurchase ? definitions.filter { $0.id == "vehicle_condition" } : []
    }

    private static let definitions: [EligibilityQuestion] = [
        .init(id: "vehicle_condition", title: "Is the vehicle new or used?", help: "Vehicle programs are specific to new or pre-owned vehicles.", kind: .choice([
            .init(value: "new", label: "New"), .init(value: "used", label: "Used")
        ])),
        .init(id: "contractor_participating", title: "Are you using a program-participating contractor?", help: "Check the program’s official contractor directory before signing.", kind: .boolean),
        .init(id: "home_energy_check_complete", title: "Has the utility Home Energy Check recommended this upgrade?", help: "Duke Energy Florida requires this step for its improvement rebates.", kind: .boolean),
        .init(id: "contractor_heehra_trained", title: "Is the contractor HEEHRA/TECH certified?", help: "California HEEHRA projects require a trained participating contractor.", kind: .boolean),
        .init(id: "reservation_approved", title: "Do you have an approved program reservation?", help: "Some rebates require approval before purchase or installation.", kind: .boolean),
        .init(id: "dealer_participating", title: "Is the seller a participating program dealer?", help: "Confirm the dealer on the official program list.", kind: .boolean),
        .init(id: "vehicle_on_eligible_list", title: "Is the vehicle on the current eligible-model list?", help: "Model eligibility can change; use the official program list.", kind: .boolean),
        .init(id: "days_since_purchase_or_lease", title: "Days since purchase or lease", help: "Enter 0 if the transaction is planned but not completed.", kind: .number(suffix: "days")),
        .init(id: "purchase_age_months", title: "Months since charger purchase", help: "Enter 0 if the charger has not been purchased yet.", kind: .number(suffix: "months")),
        .init(id: "charger_level", title: "What charging level is the equipment?", help: "Residential charger programs commonly require eligible Level 2 equipment.", kind: .choice([
            .init(value: "1", label: "Level 1"), .init(value: "2", label: "Level 2")
        ])),
        .init(id: "seer2", title: "Equipment SEER2 rating", help: "Use the rating shown on the quote or AHRI certificate.", kind: .number(suffix: "SEER2")),
        .init(id: "fuel_switch", title: "What is the existing fuel source?", help: "Some electrification bonuses require replacing gas equipment.", kind: .choice([
            .init(value: "gas_to_electric", label: "Gas to electric"),
            .init(value: "electric_to_electric", label: "Electric to electric")
        ])),
        .init(id: "system", title: "Which system are you installing?", help: "Choose the description that appears on the contractor quote.", kind: .choice([
            .init(value: "ccASHP", label: "Cold-climate air-source"),
            .init(value: "GSHP", label: "Ground-source"),
            .init(value: "HPWH", label: "Heat-pump water heater"),
            .init(value: "variable_stage", label: "Variable-stage HVAC"),
            .init(value: "two_stage", label: "Two-stage HVAC")
        ])),
        .init(id: "configuration", title: "How much of the home will the heat pump serve?", help: "Whole-home and fossil-system decommissioning tiers can differ.", kind: .choice([
            .init(value: "whole_home", label: "Whole home"),
            .init(value: "full_load_decommission", label: "Whole home + remove fossil system")
        ])),
        .init(id: "dwelling", title: "What type of building is this?", help: "Current normalized tiers cover single-family projects.", kind: .choice([
            .init(value: "single_family", label: "Single-family")
        ])),
        .init(id: "project", title: "Is this an existing-home retrofit or new construction?", help: "Ground-source incentive tiers depend on project type.", kind: .choice([
            .init(value: "retrofit", label: "Existing-home retrofit"),
            .init(value: "new_construction", label: "New construction")
        ])),
        .init(id: "dac", title: "Is the project in a designated disadvantaged community?", help: "Verify the address using the program’s official map.", kind: .boolean),
        .init(id: "disadvantaged_community", title: "Is the site in a designated disadvantaged community?", help: "Verify the address using the program’s official map.", kind: .boolean),
        .init(id: "reserved_fleet_or_assigned", title: "Is this a fleet or assigned-space charger?", help: "Assigned and fleet ports can use a different incentive tier.", kind: .boolean),
        .init(id: "site_type", title: "What type of charging site is this?", help: "Charge Ready eligibility depends on the installation site.", kind: .choice([
            .init(value: "workplace", label: "Workplace"),
            .init(value: "multifamily", label: "Multifamily property"),
            .init(value: "hotel", label: "Hotel"),
            .init(value: "other", label: "Other")
        ])),
        .init(id: "epa_range_miles", title: "Vehicle EPA electric range", help: "Use the official EPA range for the exact model and trim.", kind: .number(suffix: "miles")),
        .init(id: "base_msrp", title: "Vehicle base MSRP", help: "Use base MSRP, not the negotiated or out-the-door price.", kind: .number(suffix: "USD")),
        .init(id: "ami_pct", title: "Household income as a percentage of area median income", help: "Use the applicable program income calculator.", kind: .number(suffix: "% AMI")),
        .init(id: "income_tier", title: "Which program income tier applies?", help: "Select market-rate only if no income-qualified tier applies.", kind: .choice([
            .init(value: "market", label: "Market-rate")
        ])),
        .init(id: "income_qualified", title: "Do you qualify for the enhanced income rebate?", help: "Confirm using the utility’s income requirements.", kind: .boolean),
        .init(id: "low_income_program", title: "Are you enrolled in the qualifying low-income utility program?", help: "Examples include the utility programs named in the official rules.", kind: .boolean),
        .init(id: "low_income", title: "Do you meet the program’s low-income requirement?", help: "Confirm using the administrator’s current limits.", kind: .boolean),
        .init(id: "dedicated_ev_tou_meter", title: "Will the charger use a dedicated EV time-of-use meter?", help: "A dedicated qualifying meter may add to the rebate.", kind: .boolean),
        .init(id: "gallons", title: "Water-heater tank capacity", help: "Use the rated storage capacity from the equipment specification.", kind: .number(suffix: "gallons"))
    ]

    private static func conditionFields(in json: String) -> Set<String> {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return Set(object.keys.filter { !["category"].contains($0) })
    }

    private static func tierCouldApply(_ json: String, to project: ProjectType) -> Bool {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        if let category = object["category"] as? String { return projectCategories(project).contains(category) }
        if let system = object["system"] as? String {
            if system == "HPWH" { return project == .waterHeater }
            if ["ccASHP", "GSHP", "GSHP_desuperheater", "variable_stage", "two_stage"].contains(system) {
                return project == .heatPump
            }
        }
        return true
    }

    private static func projectCategories(_ project: ProjectType) -> Set<String> {
        switch project {
        case .heatPump: ["heat_pump_hvac"]
        case .waterHeater: ["heat_pump_water_heater"]
        case .evPurchase: ["ev_new", "ev_used"]
        case .evCharger: ["ev_charger"]
        case .solar: ["solar"]
        case .batteryStorage: ["battery_storage"]
        case .insulation: ["insulation"]
        case .windows: ["windows"]
        case .ductwork: ["ductwork"]
        case .weatherization: ["weatherization"]
        }
    }

    private static func appUtilityID(_ sourceID: String) -> String {
        [
            "ny_national_grid": "national-grid-ny", "ny_coned": "con-edison",
            "ny_nyseg": "nyseg", "ny_rge": "rge", "ny_central_hudson": "central-hudson",
            "ny_oru": "orange-rockland", "ny_psegli": "pseg-long-island",
            "ca_pge": "pge", "ca_sce": "sce", "ca_sdge": "sdge", "ca_ladwp": "ladwp",
            "ca_smud": "smud", "fl_fpl": "fpl", "fl_duke": "duke-energy-florida",
            "fl_teco": "teco", "fl_jea": "jea", "fl_ouc": "ouc", "fl_gru": "gru"
        ][sourceID] ?? sourceID
    }
}
