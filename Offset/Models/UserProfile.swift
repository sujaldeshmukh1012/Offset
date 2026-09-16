import Foundation

enum EligibilityAnswer: Codable, Equatable, Sendable {
    case boolean(Bool)
    case number(Double)
    case text(String)

    private enum CodingKeys: String, CodingKey { case type, boolean, number, text }
    private enum Kind: String, Codable { case boolean, number, text }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .boolean: self = .boolean(try container.decode(Bool.self, forKey: .boolean))
        case .number: self = .number(try container.decode(Double.self, forKey: .number))
        case .text: self = .text(try container.decode(String.self, forKey: .text))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .boolean(let value):
            try container.encode(Kind.boolean, forKey: .type)
            try container.encode(value, forKey: .boolean)
        case .number(let value):
            try container.encode(Kind.number, forKey: .type)
            try container.encode(value, forKey: .number)
        case .text(let value):
            try container.encode(Kind.text, forKey: .type)
            try container.encode(value, forKey: .text)
        }
    }
}

struct UserProfile: Codable, Equatable, Sendable {
    var zipCode: String
    var state: String
    var utilityProvider: String?
    var isHomeowner: Bool
    var selectedProjects: [ProjectType]
    var annualIncomeUSD: Double?
    var filingStatus: FilingStatus?
    var vehicleCondition: VehicleCondition?
    var vehicleCategory: VehicleCategory?
    var eligibilityAnswers: [String: EligibilityAnswer]

    init(
        zipCode: String,
        state: String,
        utilityProvider: String? = nil,
        isHomeowner: Bool,
        selectedProjects: [ProjectType],
        annualIncomeUSD: Double? = nil,
        filingStatus: FilingStatus? = nil,
        vehicleCondition: VehicleCondition? = nil,
        vehicleCategory: VehicleCategory? = nil,
        eligibilityAnswers: [String: EligibilityAnswer] = [:]
    ) {
        self.zipCode = zipCode
        self.state = state
        self.utilityProvider = utilityProvider
        self.isHomeowner = isHomeowner
        self.selectedProjects = selectedProjects
        self.annualIncomeUSD = annualIncomeUSD
        self.filingStatus = filingStatus
        self.vehicleCondition = vehicleCondition
        self.vehicleCategory = vehicleCategory
        self.eligibilityAnswers = eligibilityAnswers
    }

    private enum CodingKeys: String, CodingKey {
        case zipCode, state, utilityProvider, isHomeowner, selectedProjects
        case annualIncomeUSD, filingStatus, vehicleCondition, vehicleCategory, eligibilityAnswers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zipCode = try container.decode(String.self, forKey: .zipCode)
        state = try container.decode(String.self, forKey: .state)
        utilityProvider = try container.decodeIfPresent(String.self, forKey: .utilityProvider)
        isHomeowner = try container.decode(Bool.self, forKey: .isHomeowner)
        selectedProjects = try container.decode([ProjectType].self, forKey: .selectedProjects)
        annualIncomeUSD = try container.decodeIfPresent(Double.self, forKey: .annualIncomeUSD)
        filingStatus = try container.decodeIfPresent(FilingStatus.self, forKey: .filingStatus)
        vehicleCondition = try container.decodeIfPresent(VehicleCondition.self, forKey: .vehicleCondition)
        vehicleCategory = try container.decodeIfPresent(VehicleCategory.self, forKey: .vehicleCategory)
        eligibilityAnswers = try container.decodeIfPresent(
            [String: EligibilityAnswer].self,
            forKey: .eligibilityAnswers
        ) ?? [:]
    }
}

struct NotificationPreferences: Codable, Equatable, Sendable {
    var deadlineRemindersEnabled: Bool
    var hasPresentedValuePrimer: Bool

    init(
        deadlineRemindersEnabled: Bool = false,
        hasPresentedValuePrimer: Bool = false
    ) {
        self.deadlineRemindersEnabled = deadlineRemindersEnabled
        self.hasPresentedValuePrimer = hasPresentedValuePrimer
    }

    private enum CodingKeys: String, CodingKey {
        case deadlineRemindersEnabled
        case hasPresentedValuePrimer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deadlineRemindersEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .deadlineRemindersEnabled
        ) ?? false
        hasPresentedValuePrimer = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasPresentedValuePrimer
        ) ?? false
    }
}
