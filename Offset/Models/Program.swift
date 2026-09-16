import Foundation

struct ProgramCatalog: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let programs: [Program]
}

struct Program: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let level: ProgramLevel
    let benefitType: BenefitType
    let status: ProgramStatus
    let projectTypes: [ProjectType]
    let amountType: AmountType
    let eligibilityStates: [String]
    let eligibilityUtilities: [String]
    let eligibleHomeOccupancies: [HomeOccupancy]
    let eligibleVehicleConditions: [VehicleCondition]
    let incomeCapsUSD: [FilingStatus: Double]
    let vehiclePriceCapsUSD: [VehicleCategory: Double]
    let annualCaps: [AnnualCap]
    let effectiveDate: Date
    let deadline: Date?
    let sourceURL: String
    let lastVerifiedDate: Date
    let eligibilitySummary: [String]
    let claimSteps: [String]
    let description: String
}

enum ProgramLevel: String, Codable, CaseIterable, Sendable { case federal, state, utility, regional, local }

enum BenefitType: String, Codable, CaseIterable, Sendable {
    case rebate
    case pointOfSaleDiscount
    case nonrefundableTaxCredit
    case refundableTaxCredit
    case salesTaxExemption
    case propertyTaxExclusion
    case nonCash
}

enum ProgramStatus: String, Codable, CaseIterable, Sendable {
    case active
    case dynamic
    case waitlist
    case discovery
    case paused
    case closed
}

extension ProgramStatus {
    var displayName: String {
        switch self {
        case .active: "Active"
        case .dynamic: "Verify current details"
        case .waitlist: "Waitlist"
        case .discovery: "Coverage in progress"
        case .paused: "Paused"
        case .closed: "Closed"
        }
    }
}

enum HomeOccupancy: String, Codable, CaseIterable, Sendable {
    case homeownerPrimaryResidence
    case homeownerSecondaryResidence
    case renterPrimaryResidence
}

enum FilingStatus: String, Codable, CaseIterable, Sendable {
    case singleOrOther
    case headOfHousehold
    case marriedFilingJointly
}

extension FilingStatus: CodingKeyRepresentable {
    var codingKey: any CodingKey { ProgramDictionaryKey(stringValue: rawValue) }

    init?<Key>(codingKey: Key) where Key: CodingKey {
        self.init(rawValue: codingKey.stringValue)
    }
}

enum VehicleCondition: String, Codable, CaseIterable, Sendable { case new, used }

enum VehicleCategory: String, Codable, CaseIterable, Sendable {
    case car
    case suvPickupOrVan
    case usedVehicle
}

extension VehicleCategory: CodingKeyRepresentable {
    var codingKey: any CodingKey { ProgramDictionaryKey(stringValue: rawValue) }

    init?<Key>(codingKey: Key) where Key: CodingKey {
        self.init(rawValue: codingKey.stringValue)
    }
}

private struct ProgramDictionaryKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

struct AnnualCap: Codable, Equatable, Sendable {
    let group: String
    let amountUSD: Double
    let description: String
}

enum ProjectType: String, Codable, CaseIterable, Identifiable, Sendable {
    case heatPump
    case evPurchase
    case evCharger
    case insulation
    case solar
    case waterHeater
    case batteryStorage
    case windows
    case ductwork
    case weatherization

    var id: Self { self }
}

enum AmountType: Equatable, Sendable {
    case percentage(Double)
    case fixedAmount(Double)
    case upTo(Double, percentage: Double)
    case range(min: Double?, max: Double?)
    case formula(String)
    case taxBenefit(String)
    case nonCash(String)
    case unknown
}

extension AmountType: Codable {
    private enum CodingKeys: String, CodingKey { case type, value, percentage, minimum, maximum, explanation }
    private enum Kind: String, Codable {
        case percentage, fixedAmount, upTo, range, formula, taxBenefit, nonCash, unknown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .percentage:
            self = .percentage(try container.decode(Double.self, forKey: .value))
        case .fixedAmount:
            self = .fixedAmount(try container.decode(Double.self, forKey: .value))
        case .upTo:
            self = .upTo(
                try container.decode(Double.self, forKey: .value),
                percentage: try container.decode(Double.self, forKey: .percentage)
            )
        case .range:
            self = .range(
                min: try container.decodeIfPresent(Double.self, forKey: .minimum),
                max: try container.decodeIfPresent(Double.self, forKey: .maximum)
            )
        case .formula:
            self = .formula(try container.decode(String.self, forKey: .explanation))
        case .taxBenefit:
            self = .taxBenefit(try container.decode(String.self, forKey: .explanation))
        case .nonCash:
            self = .nonCash(try container.decode(String.self, forKey: .explanation))
        case .unknown:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .percentage(let value):
            try container.encode(Kind.percentage, forKey: .type)
            try container.encode(value, forKey: .value)
        case .fixedAmount(let value):
            try container.encode(Kind.fixedAmount, forKey: .type)
            try container.encode(value, forKey: .value)
        case .upTo(let cap, let percentage):
            try container.encode(Kind.upTo, forKey: .type)
            try container.encode(cap, forKey: .value)
            try container.encode(percentage, forKey: .percentage)
        case .range(let minimum, let maximum):
            try container.encode(Kind.range, forKey: .type)
            try container.encodeIfPresent(minimum, forKey: .minimum)
            try container.encodeIfPresent(maximum, forKey: .maximum)
        case .formula(let explanation):
            try container.encode(Kind.formula, forKey: .type)
            try container.encode(explanation, forKey: .explanation)
        case .taxBenefit(let explanation):
            try container.encode(Kind.taxBenefit, forKey: .type)
            try container.encode(explanation, forKey: .explanation)
        case .nonCash(let explanation):
            try container.encode(Kind.nonCash, forKey: .type)
            try container.encode(explanation, forKey: .explanation)
        case .unknown:
            try container.encode(Kind.unknown, forKey: .type)
        }
    }
}
