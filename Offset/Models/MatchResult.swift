import Foundation

struct MatchResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let program: Program
    let estimatedSavingsUSD: Double
    let priceBeforeUSD: Double
    let priceAfterUSD: Double
    let isLocked: Bool

    init(
        id: UUID = UUID(),
        program: Program,
        estimatedSavingsUSD: Double,
        priceBeforeUSD: Double,
        priceAfterUSD: Double,
        isLocked: Bool
    ) {
        self.id = id
        self.program = program
        self.estimatedSavingsUSD = estimatedSavingsUSD
        self.priceBeforeUSD = priceBeforeUSD
        self.priceAfterUSD = priceAfterUSD
        self.isLocked = isLocked
    }
}
