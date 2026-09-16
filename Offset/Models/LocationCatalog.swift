import Foundation

struct LocationCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let stateZIPRanges: [StateZIPRange]
    let utilityProviders: [UtilityProvider]
}

struct StateZIPRange: Codable, Equatable, Sendable {
    let state: String
    let ranges: [ZIPPrefixRange]
}

struct ZIPPrefixRange: Codable, Equatable, Sendable {
    let lower: Int
    let upper: Int
}

struct UtilityProvider: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let state: String
}
