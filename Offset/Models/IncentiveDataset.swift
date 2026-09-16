import Foundation

struct IncentiveDataset: Decodable, Sendable {
    struct Metadata: Decodable, Sendable {
        let schemaVersion: String
        let datasetName: String
        let generatedAt: String
        let launchStates: String
        let sourcePolicy: String
        let matchingPolicy: String
        let warning: String
    }

    struct StateRecord: Decodable, Sendable {
        let code: String
        let name: String
        let coverageStatus: String
        let notes: String?
    }

    struct UtilityRecord: Decodable, Sendable {
        let id: String
        let stateCode: String
        let name: String
        let utilityType: String
        let domain: String?
        let supported: Int
        let notes: String?
    }

    struct CategoryRecord: Decodable, Sendable {
        let id: String
        let name: String
    }

    struct SourceRecord: Decodable, Sendable {
        let id: String
        let name: String
        let url: String
        let authorityTier: Int
        let sourceType: String
        let stateCode: String?
        let utilityId: String?
        let trustStatus: String
        let notes: String?
    }

    struct ProgramRecord: Decodable, Sendable {
        let id: String
        let name: String
        let jurisdictionLevel: String
        let stateCode: String?
        let utilityId: String?
        let administrator: String?
        let incentiveType: String
        let status: String
        let publishable: Int
        let matchEnabled: Int
        let verificationStatus: String
        let effectiveStart: String?
        let effectiveEnd: String?
        let lastVerifiedAt: String?
        let amountType: String
        let amountMin: Double?
        let amountMax: Double?
        let amountUnit: String?
        let amountFormula: String?
        let description: String
        let claimTiming: String?
        let requiresPreapproval: Int
        let requiresContractor: Int
        let sourceId: String?
        let sourceUrl: String
        let notes: String?
    }

    struct ProgramCategoryRecord: Decodable, Sendable {
        let programId: String
        let categoryId: String
    }

    struct EligibilityRuleRecord: Decodable, Sendable {
        let programId: String
        let field: String
        let `operator`: String
        let valueJson: String
        let description: String
        let blocking: Int
    }

    struct IncentiveTierRecord: Decodable, Sendable {
        let programId: String
        let tierKey: String
        let conditionsJson: String
        let amount: Double?
        let unit: String?
        let cap: Double?
        let description: String
    }

    struct ClaimStepRecord: Decodable, Sendable {
        let programId: String
        let stepOrder: Int
        let phase: String
        let title: String
        let description: String
        let blocking: Int
    }

    struct StackingRuleRecord: Decodable, Sendable {
        let programA: String
        let programB: String
        let relationship: String
        let notes: String?
        let verified: Int
    }

    struct CoverageRecord: Decodable, Sendable {
        let stateCode: String
        let utilityId: String?
        let categoryId: String
        let status: String
        let notes: String?
    }

    let meta: Metadata
    let states: [StateRecord]
    let utilities: [UtilityRecord]
    let categories: [CategoryRecord]
    let sources: [SourceRecord]
    let programs: [ProgramRecord]
    let programCategories: [ProgramCategoryRecord]
    let eligibilityRules: [EligibilityRuleRecord]
    let incentiveTiers: [IncentiveTierRecord]
    let claimSteps: [ClaimStepRecord]
    let stackingRules: [StackingRuleRecord]
    let coverage: [CoverageRecord]
}

enum IncentiveDatasetError: Error, Equatable {
    case unsupportedSchema(String)
    case invalidDataset([String])
}

struct IncentiveDatasetStore {
    static func loadBundled(bundle: Bundle = .main) throws -> IncentiveDataset {
        guard let url = bundle.url(forResource: "offset_seed", withExtension: "json") else {
            throw ProgramStoreError.resourceNotFound("offset_seed")
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> IncentiveDataset {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dataset = try decoder.decode(IncentiveDataset.self, from: data)
        try validate(dataset)
        return dataset
    }

    static func validate(_ dataset: IncentiveDataset) throws {
        guard dataset.meta.schemaVersion == "1" else {
            throw IncentiveDatasetError.unsupportedSchema(dataset.meta.schemaVersion)
        }

        var issues: [String] = []
        validateUnique(dataset.states.map(\.code), label: "state", issues: &issues)
        validateUnique(dataset.utilities.map(\.id), label: "utility", issues: &issues)
        validateUnique(dataset.categories.map(\.id), label: "category", issues: &issues)
        validateUnique(dataset.sources.map(\.id), label: "source", issues: &issues)
        validateUnique(dataset.programs.map(\.id), label: "program", issues: &issues)

        let stateIDs = Set(dataset.states.map(\.code))
        let utilityByID = Dictionary(uniqueKeysWithValues: dataset.utilities.map { ($0.id, $0) })
        let categoryIDs = Set(dataset.categories.map(\.id))
        let sourceByID = Dictionary(uniqueKeysWithValues: dataset.sources.map { ($0.id, $0) })
        let programIDs = Set(dataset.programs.map(\.id))

        for utility in dataset.utilities {
            if !stateIDs.contains(utility.stateCode) { issues.append("\(utility.id): unknown state \(utility.stateCode)") }
            if ![0, 1].contains(utility.supported) { issues.append("\(utility.id): supported must be 0 or 1") }
        }

        for source in dataset.sources {
            if URL(string: source.url)?.scheme?.lowercased() != "https" { issues.append("\(source.id): source URL must be HTTPS") }
            if !(0...3).contains(source.authorityTier) { issues.append("\(source.id): authority tier is out of range") }
            if let state = source.stateCode, !stateIDs.contains(state) { issues.append("\(source.id): unknown source state \(state)") }
            if let utility = source.utilityId, utilityByID[utility] == nil { issues.append("\(source.id): unknown source utility \(utility)") }
        }

        for program in dataset.programs {
            if program.id.isEmpty || program.name.isEmpty || program.description.isEmpty {
                issues.append("\(program.id): id, name, and description are required")
            }
            if let state = program.stateCode, !stateIDs.contains(state) { issues.append("\(program.id): unknown state \(state)") }
            if let utilityID = program.utilityId {
                guard let utility = utilityByID[utilityID] else {
                    issues.append("\(program.id): unknown utility \(utilityID)")
                    continue
                }
                if utility.stateCode != program.stateCode { issues.append("\(program.id): utility and program states differ") }
            }
            if let sourceID = program.sourceId {
                guard let source = sourceByID[sourceID] else {
                    issues.append("\(program.id): unknown source \(sourceID)")
                    continue
                }
                if source.url != program.sourceUrl { issues.append("\(program.id): source URL differs from source record") }
            }
            if URL(string: program.sourceUrl)?.scheme?.lowercased() != "https" { issues.append("\(program.id): program URL must be HTTPS") }
            if program.matchEnabled == 1 && program.publishable != 1 { issues.append("\(program.id): match-enabled program must be publishable") }
            if program.matchEnabled == 1 && !["active", "dynamic"].contains(program.status) {
                issues.append("\(program.id): match-enabled program has non-current status")
            }
            if let minimum = program.amountMin, !minimum.isFinite || minimum < 0 { issues.append("\(program.id): invalid minimum amount") }
            if let maximum = program.amountMax, !maximum.isFinite || maximum < 0 { issues.append("\(program.id): invalid maximum amount") }
            if let minimum = program.amountMin, let maximum = program.amountMax, minimum > maximum {
                issues.append("\(program.id): minimum amount exceeds maximum")
            }
            if program.verificationStatus.hasPrefix("primary_verified"), program.lastVerifiedAt == nil {
                issues.append("\(program.id): verified program has no verification date")
            }
        }

        for link in dataset.programCategories {
            if !programIDs.contains(link.programId) { issues.append("Unknown program-category program \(link.programId)") }
            if !categoryIDs.contains(link.categoryId) { issues.append("Unknown program category \(link.categoryId)") }
        }
        let categorized = Set(dataset.programCategories.map(\.programId))
        for program in dataset.programs where !categorized.contains(program.id) { issues.append("\(program.id): no categories") }

        for rule in dataset.eligibilityRules {
            if !programIDs.contains(rule.programId) { issues.append("Unknown eligibility program \(rule.programId)") }
            validateJSONObject(rule.valueJson, label: "\(rule.programId) eligibility value", issues: &issues)
        }
        for tier in dataset.incentiveTiers {
            if !programIDs.contains(tier.programId) { issues.append("Unknown tier program \(tier.programId)") }
            validateJSONObject(tier.conditionsJson, label: "\(tier.programId) tier conditions", issues: &issues)
            if let amount = tier.amount, !amount.isFinite || amount < 0 { issues.append("\(tier.programId): invalid tier amount") }
            if let cap = tier.cap, !cap.isFinite || cap < 0 { issues.append("\(tier.programId): invalid tier cap") }
        }
        validateUnique(dataset.incentiveTiers.map { "\($0.programId)|\($0.tierKey)" }, label: "program tier", issues: &issues)
        validateUnique(dataset.claimSteps.map { "\($0.programId)|\($0.stepOrder)" }, label: "claim step", issues: &issues)

        for step in dataset.claimSteps where !programIDs.contains(step.programId) {
            issues.append("Unknown claim-step program \(step.programId)")
        }
        for rule in dataset.stackingRules {
            if !programIDs.contains(rule.programA) || !programIDs.contains(rule.programB) {
                issues.append("Unknown stacking program \(rule.programA)/\(rule.programB)")
            }
            if rule.programA == rule.programB { issues.append("Self-referencing stacking rule \(rule.programA)") }
            if !["stackable", "conditional", "may_stack", "exclusive", "mutually_exclusive", "not_stackable", "applies_before", "applies_after"].contains(rule.relationship) {
                issues.append("Unknown stacking relationship \(rule.relationship)")
            }
            if ![0, 1].contains(rule.verified) { issues.append("Stacking verification must be 0 or 1") }
        }
        for item in dataset.coverage {
            if !stateIDs.contains(item.stateCode) { issues.append("Unknown coverage state \(item.stateCode)") }
            if let utility = item.utilityId, utilityByID[utility] == nil { issues.append("Unknown coverage utility \(utility)") }
            if !categoryIDs.contains(item.categoryId) { issues.append("Unknown coverage category \(item.categoryId)") }
        }
        validateUnique(dataset.coverage.map { "\($0.stateCode)|\($0.utilityId ?? "statewide")|\($0.categoryId)" }, label: "coverage", issues: &issues)

        if !issues.isEmpty { throw IncentiveDatasetError.invalidDataset(issues.sorted()) }
    }

    static func appPrograms(
        from dataset: IncentiveDataset,
        referenceDate: Date = Date(),
        profile: UserProfile? = nil
    ) -> [Program] {
        let categoriesByProgram = Dictionary(grouping: dataset.programCategories, by: \.programId)
        let rulesByProgram = Dictionary(grouping: dataset.eligibilityRules, by: \.programId)
        let tiersByProgram = Dictionary(grouping: dataset.incentiveTiers, by: \.programId)
        let stepsByProgram = Dictionary(grouping: dataset.claimSteps, by: \.programId)

        return dataset.programs.flatMap { record -> [Program] in
            let mappedProjects = (categoriesByProgram[record.id] ?? []).compactMap { projectType(for: $0.categoryId) }
            let rawCategoryIDs = Set((categoriesByProgram[record.id] ?? []).map(\.categoryId))
            let uniqueProjects = Array(Set(mappedProjects)).sorted { $0.rawValue < $1.rawValue }
            guard !uniqueProjects.isEmpty else { return [] }

            return uniqueProjects.compactMap { project -> Program? in
                let suffix = uniqueProjects.count == 1 ? "" : "-\(project.rawValue.lowercased())"
                let rules = rulesByProgram[record.id] ?? []
                let tiers = tiersByProgram[record.id] ?? []
                if let profile,
                   rules.filter({ $0.blocking == 1 }).contains(where: { evaluate($0, profile: profile) == false }) {
                    return nil
                }
                let amount = amountType(for: record, project: project, tiers: tiers, profile: profile)
                let canCalculate = isSafelyCalculable(
                    record: record,
                    project: project,
                    rules: rules,
                    amount: amount,
                    referenceDate: referenceDate,
                    profile: profile
                )
                let rawStatus = status(for: record.status)
                let appStatus: ProgramStatus
                if canCalculate {
                    // A recently verified dynamic record may participate in estimates until its
                    // short freshness window expires. It remains labelled dynamic in source data.
                    appStatus = .active
                } else if rawStatus == .active {
                    // Keep discoverable programs visible without presenting an amount that the
                    // current profile cannot resolve safely.
                    appStatus = .dynamic
                } else {
                    appStatus = rawStatus
                }
                let projectSteps = (stepsByProgram[record.id] ?? [])
                    .sorted { $0.stepOrder < $1.stepOrder }
                    .map { $0.title == $0.description ? $0.title : "\($0.title): \($0.description)" }

                return Program(
                    id: record.id + suffix,
                    name: record.name,
                    level: level(for: record.jurisdictionLevel),
                    benefitType: benefitType(for: record.incentiveType),
                    status: appStatus,
                    projectTypes: [project],
                    amountType: amount,
                    eligibilityStates: record.stateCode.map { [$0] } ?? [],
                    eligibilityUtilities: record.utilityId.map { [appUtilityID($0)] } ?? [],
                    eligibleHomeOccupancies: occupancies(from: rules),
                    eligibleVehicleConditions: vehicleConditions(for: project, categoryIDs: rawCategoryIDs),
                    incomeCapsUSD: [:],
                    vehiclePriceCapsUSD: [:],
                    annualCaps: [],
                    effectiveDate: parseDate(record.effectiveStart) ?? Date(timeIntervalSince1970: 0),
                    deadline: parseDate(record.effectiveEnd, endOfDay: true),
                    sourceURL: record.sourceUrl,
                    lastVerifiedDate: parseDate(record.lastVerifiedAt) ?? Date(timeIntervalSince1970: 0),
                    eligibilitySummary: eligibilitySummary(record: record, rules: rules),
                    claimSteps: projectSteps.isEmpty ? fallbackClaimSteps(record: record) : projectSteps,
                    description: record.description
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.status != rhs.status { return statusRank(lhs.status) < statusRank(rhs.status) }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func validateUnique(_ values: [String], label: String, issues: inout [String]) {
        let duplicates = Dictionary(grouping: values, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        if !duplicates.isEmpty { issues.append("Duplicate \(label) keys: \(duplicates.joined(separator: ", "))") }
    }

    private static func validateJSONObject(_ value: String, label: String, issues: inout [String]) {
        guard let data = value.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) != nil else {
            issues.append("Invalid JSON in \(label)")
            return
        }
    }

    private static func projectType(for category: String) -> ProjectType? {
        switch category {
        case "heat_pump_hvac": .heatPump
        case "heat_pump_water_heater": .waterHeater
        case "ev_new", "ev_used": .evPurchase
        case "ev_charger": .evCharger
        case "solar": .solar
        case "battery_storage": .batteryStorage
        case "insulation": .insulation
        case "windows": .windows
        case "ductwork": .ductwork
        case "weatherization": .weatherization
        default: nil
        }
    }

    private static func level(for raw: String) -> ProgramLevel {
        switch raw {
        case "federal": .federal
        case "state": .state
        case "utility": .utility
        case "regional": .regional
        default: .local
        }
    }

    private static func benefitType(for raw: String) -> BenefitType {
        switch raw {
        case "point_of_sale_rebate", "instant_rebate", "upfront_project_incentive": .pointOfSaleDiscount
        case "tax_credit": .nonrefundableTaxCredit
        case "sales_tax_exemption": .salesTaxExemption
        case "property_tax_exclusion": .propertyTaxExclusion
        case "no_cost_efficiency": .nonCash
        default: .rebate
        }
    }

    private static func status(for raw: String) -> ProgramStatus {
        switch raw {
        case "active": .active
        case "dynamic", "unknown": .dynamic
        case "waitlist": .waitlist
        case "discovery_only": .discovery
        default: .closed
        }
    }

    private static func amountType(
        for record: IncentiveDataset.ProgramRecord,
        project: ProjectType,
        tiers: [IncentiveDataset.IncentiveTierRecord],
        profile: UserProfile?
    ) -> AmountType {
        switch record.amountType {
        case "flat":
            return .fixedAmount(record.amountMax ?? record.amountMin ?? 0)
        case "percent":
            if let formula = record.amountFormula,
               let percentage = firstDecimal(in: formula), percentage > 0, percentage <= 1 {
                if let cap = record.amountMax { return .upTo(cap, percentage: percentage) }
                return .percentage(percentage)
            }
            return .formula(record.amountFormula ?? "Percentage depends on current program rules")
        case "tiered":
            if let profile {
                let matching = tiers.filter { tier in
                    guard tierCouldApply(to: project, conditionsJSON: tier.conditionsJson) else { return false }
                    return evaluateConditions(tier.conditionsJson, project: project, profile: profile) == true
                }
                if matching.count == 1, let amount = matching[0].amount { return .fixedAmount(amount) }
            }
            let applicable = tiers.filter { tierAppliesOnly(to: project, conditionsJSON: $0.conditionsJson) }
            if applicable.count == 1, let amount = applicable[0].amount { return .fixedAmount(amount) }
            return .range(min: record.amountMin, max: record.amountMax)
        case "formula":
            return .formula(record.amountFormula ?? "Calculated by the program administrator")
        case "tax_exemption":
            return .taxBenefit("Qualifying purchases may be exempt from applicable sales tax")
        case "property_tax_exclusion":
            return .taxBenefit("Qualifying value may be excluded from the property-tax assessment")
        case "noncash":
            return .nonCash("Eligible upgrades are provided at no cost")
        default:
            return .unknown
        }
    }

    private static func isSafelyCalculable(
        record: IncentiveDataset.ProgramRecord,
        project: ProjectType,
        rules: [IncentiveDataset.EligibilityRuleRecord],
        amount: AmountType,
        referenceDate: Date,
        profile: UserProfile?
    ) -> Bool {
        guard record.matchEnabled == 1, record.publishable == 1,
              isFreshForCalculation(record, referenceDate: referenceDate) else { return false }
        guard amount.isExactCalculation else { return false }
        if let profile {
            guard rules.filter({ $0.blocking == 1 }).allSatisfy({ evaluate($0, profile: profile) == true }) else { return false }
        } else {
            let supportedFields = Set(["state", "utility_id", "residence_type"])
            guard rules.filter({ $0.blocking == 1 }).allSatisfy({ supportedFields.contains($0.field) }) else { return false }
            if project == .evPurchase { return false }
        }
        return true
    }

    private static func isFreshForCalculation(
        _ record: IncentiveDataset.ProgramRecord,
        referenceDate: Date
    ) -> Bool {
        if record.status == "dynamic" { return isFreshDynamicRecord(record, referenceDate: referenceDate) }
        guard record.status == "active", let verified = parseDate(record.lastVerifiedAt) else { return false }
        let age = referenceDate.timeIntervalSince(verified)
        return age >= 0 && age <= 45 * 24 * 60 * 60
    }

    private static func isFreshDynamicRecord(
        _ record: IncentiveDataset.ProgramRecord,
        referenceDate: Date
    ) -> Bool {
        guard record.status == "dynamic", let verified = parseDate(record.lastVerifiedAt) else { return false }
        let age = referenceDate.timeIntervalSince(verified)
        return age >= 0 && age <= 30 * 24 * 60 * 60
    }

    private static func tierAppliesOnly(to project: ProjectType, conditionsJSON: String) -> Bool {
        guard let data = conditionsJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object.count == 1 else { return false }
        if let category = object["category"] as? String { return projectType(for: category) == project }
        if let system = object["system"] as? String { return system == "HPWH" && project == .waterHeater }
        return false
    }

    private static func evaluate(
        _ rule: IncentiveDataset.EligibilityRuleRecord,
        profile: UserProfile
    ) -> Bool? {
        guard let data = rule.valueJson.data(using: .utf8),
              let expected = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
              let actual = answer(for: rule.field, profile: profile) else { return nil }
        return compare(actual: actual, expected: expected, operator: rule.operator)
    }

    private static func evaluateConditions(
        _ json: String,
        project: ProjectType,
        profile: UserProfile
    ) -> Bool? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var unresolved = false
        for (field, expected) in object {
            let actual: EligibilityAnswer?
            if field == "category" {
                actual = .text(categoryID(for: project))
            } else if field == "system", project == .waterHeater, expected as? String == "HPWH" {
                actual = .text("HPWH")
            } else {
                actual = answer(for: field, profile: profile)
            }
            guard let actual else {
                unresolved = true
                continue
            }
            guard compare(actual: actual, expected: expected, operator: "eq") else { return false }
        }
        return unresolved ? nil : true
    }

    private static func answer(for field: String, profile: UserProfile) -> EligibilityAnswer? {
        switch field {
        case "state": .text(profile.state.uppercased())
        case "utility_id": profile.utilityProvider.map { .text(sourceUtilityID($0)) }
        case "residence_type": .text("principal_residence")
        case "vehicle_condition": profile.vehicleCondition.map { .text($0.rawValue) }
        case "vehicle_category": profile.vehicleCategory.map { .text($0.rawValue) }
        default: profile.eligibilityAnswers[field]
        }
    }

    private static func compare(actual: EligibilityAnswer, expected: Any, operator op: String) -> Bool {
        if let conditions = expected as? [String: Any] {
            return conditions.allSatisfy { comparison, target in
                compare(actual: actual, expected: target, operator: comparison)
            }
        }
        if op == "in", let values = expected as? [Any] {
            return values.contains { compare(actual: actual, expected: $0, operator: "eq") }
        }

        if let actualNumber = numericValue(actual), let expectedNumber = numericValue(expected) {
            switch op {
            case "gt": return actualNumber > expectedNumber
            case "gte": return actualNumber >= expectedNumber
            case "lt": return actualNumber < expectedNumber
            case "lte": return actualNumber <= expectedNumber
            default: return abs(actualNumber - expectedNumber) < 0.000_001
            }
        }
        if case .boolean(let value) = actual, let expected = expected as? Bool { return op == "eq" && value == expected }
        if case .text(let value) = actual, let expected = expected as? String { return op == "eq" && value == expected }
        return false
    }

    private static func numericValue(_ answer: EligibilityAnswer) -> Double? {
        switch answer {
        case .number(let value): value
        case .text(let value): Double(value)
        case .boolean: nil
        }
    }

    private static func numericValue(_ value: Any) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func tierCouldApply(to project: ProjectType, conditionsJSON: String) -> Bool {
        guard let data = conditionsJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        if let category = object["category"] as? String { return projectType(for: category) == project }
        if let system = object["system"] as? String {
            if system == "HPWH" { return project == .waterHeater }
            if ["ccASHP", "GSHP", "GSHP_desuperheater", "variable_stage", "two_stage"].contains(system) {
                return project == .heatPump
            }
        }
        return true
    }

    private static func categoryID(for project: ProjectType) -> String {
        switch project {
        case .heatPump: "heat_pump_hvac"
        case .waterHeater: "heat_pump_water_heater"
        case .evPurchase: "ev_new"
        case .evCharger: "ev_charger"
        case .solar: "solar"
        case .batteryStorage: "battery_storage"
        case .insulation: "insulation"
        case .windows: "windows"
        case .ductwork: "ductwork"
        case .weatherization: "weatherization"
        }
    }

    private static func occupancies(from rules: [IncentiveDataset.EligibilityRuleRecord]) -> [HomeOccupancy] {
        guard rules.contains(where: { $0.field == "residence_type" && $0.valueJson.contains("principal_residence") }) else { return [] }
        return [.homeownerPrimaryResidence]
    }

    private static func vehicleConditions(for project: ProjectType, categoryIDs: Set<String>) -> [VehicleCondition] {
        guard project == .evPurchase else { return [] }
        if categoryIDs.contains("ev_new") { return [.new] }
        if categoryIDs.contains("ev_used") { return [.used] }
        return []
    }

    private static func eligibilitySummary(
        record: IncentiveDataset.ProgramRecord,
        rules: [IncentiveDataset.EligibilityRuleRecord]
    ) -> [String] {
        var summary = rules.map(\.description)
        if record.requiresPreapproval == 1 { summary.append("Program preapproval is required before committing to the project.") }
        if record.requiresContractor == 1 { summary.append("A participating or approved contractor is required.") }
        if record.verificationStatus == "primary_verified_dynamic" {
            summary.append("The official source is verified, but funding, amounts, or equipment rules can change; confirm them before purchase.")
        }
        if summary.isEmpty { summary.append("Confirm current eligibility with the program administrator before purchase or installation.") }
        return Array(NSOrderedSet(array: summary)) as? [String] ?? summary
    }

    private static func fallbackClaimSteps(record: IncentiveDataset.ProgramRecord) -> [String] {
        var steps = ["Open the official program source and confirm current availability and eligibility before committing."]
        if record.requiresPreapproval == 1 { steps.append("Obtain required preapproval before purchase or installation.") }
        if record.requiresContractor == 1 { steps.append("Choose a participating or approved contractor from the official program list.") }
        steps.append("Keep the quote, model information, invoices, and proof of payment needed by the administrator.")
        return steps
    }

    private static func appUtilityID(_ sourceID: String) -> String {
        switch sourceID {
        case "ny_national_grid": "national-grid-ny"
        case "ny_coned": "con-edison"
        case "ny_nyseg": "nyseg"
        case "ny_rge": "rge"
        case "ny_central_hudson": "central-hudson"
        case "ny_oru": "orange-rockland"
        case "ny_psegli": "pseg-long-island"
        case "ca_pge": "pge"
        case "ca_sce": "sce"
        case "ca_sdge": "sdge"
        case "ca_ladwp": "ladwp"
        case "ca_smud": "smud"
        case "fl_fpl": "fpl"
        case "fl_duke": "duke-energy-florida"
        case "fl_teco": "teco"
        case "fl_jea": "jea"
        case "fl_ouc": "ouc"
        case "fl_gru": "gru"
        default: sourceID
        }
    }

    private static func sourceUtilityID(_ appID: String) -> String {
        switch appID {
        case "national-grid-ny": "ny_national_grid"
        case "con-edison": "ny_coned"
        case "nyseg": "ny_nyseg"
        case "rge": "ny_rge"
        case "central-hudson": "ny_central_hudson"
        case "orange-rockland": "ny_oru"
        case "pseg-long-island": "ny_psegli"
        case "pge": "ca_pge"
        case "sce": "ca_sce"
        case "sdge": "ca_sdge"
        case "ladwp": "ca_ladwp"
        case "smud": "ca_smud"
        case "fpl": "fl_fpl"
        case "duke-energy-florida": "fl_duke"
        case "teco": "fl_teco"
        case "jea": "fl_jea"
        case "ouc": "fl_ouc"
        case "gru": "fl_gru"
        default: appID
        }
    }

    private static func parseDate(_ value: String?, endOfDay: Bool = false) -> Date? {
        guard let value else { return nil }
        if value.count == 10 {
            let suffix = endOfDay ? "T23:59:59Z" : "T00:00:00Z"
            return ISO8601DateFormatter().date(from: value + suffix)
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func firstDecimal(in text: String) -> Double? {
        guard let range = text.range(of: #"0\.\d+"#, options: .regularExpression) else { return nil }
        return Double(text[range])
    }

    private static func statusRank(_ status: ProgramStatus) -> Int {
        switch status {
        case .active: 0
        case .dynamic: 1
        case .waitlist: 2
        case .discovery: 3
        case .paused: 4
        case .closed: 5
        }
    }
}

private extension AmountType {
    var isExactCalculation: Bool {
        switch self {
        case .percentage, .fixedAmount, .upTo: true
        case .range, .formula, .taxBenefit, .nonCash, .unknown: false
        }
    }
}
