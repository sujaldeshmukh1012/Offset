import Foundation

struct SavedProject: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var projectType: ProjectType
    var stickerPriceUSD: Double
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        projectType: ProjectType,
        stickerPriceUSD: Double,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.projectType = projectType
        self.stickerPriceUSD = stickerPriceUSD
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ClaimStepID: Codable, Hashable, Sendable {
    let projectID: UUID
    let programID: String
    let stepIndex: Int
}

struct PricerDraft: Equatable, Sendable {
    let projectType: ProjectType
    let stickerPriceUSD: Double
}
