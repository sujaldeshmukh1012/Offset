import Foundation
import Testing
@testable import Offset

struct CoverageServiceTests {
    private var dataset: IncentiveDataset {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Data/offset_seed.json")
            return try IncentiveDatasetStore.decode(Data(contentsOf: url))
        }
    }

    @Test func newYorkMajorUtilityReportsProductionCoverage() throws {
        let profile = UserProfile(
            zipCode: "10001",
            state: "NY",
            utilityProvider: "con-edison",
            isHomeowner: true,
            selectedProjects: [.solar]
        )
        let result = CoverageService.assessment(for: .solar, profile: profile, dataset: try dataset)

        #expect(result.confidence == .verifiedDynamic)
        #expect(result.isProductionMarket)
    }

    @Test func partialStateNeverClaimsCompleteMarketCoverage() throws {
        let profile = UserProfile(
            zipCode: "33101",
            state: "FL",
            utilityProvider: "fpl",
            isHomeowner: true,
            selectedProjects: [.heatPump]
        )
        let result = CoverageService.assessment(for: .heatPump, profile: profile, dataset: try dataset)

        #expect(result.confidence == .partial)
        #expect(!result.isProductionMarket)
        #expect(result.message.contains("partial-coverage market"))
    }

    @Test func missingCoverageDoesNotMeanNoIncentivesExist() throws {
        let profile = UserProfile(
            zipCode: "10001",
            state: "NY",
            utilityProvider: "con-edison",
            isHomeowner: true,
            selectedProjects: [.insulation]
        )
        let result = CoverageService.assessment(for: .insulation, profile: profile, dataset: try dataset)

        #expect(result.confidence == .unsupported)
        #expect(result.message.contains("does not mean that no incentives exist"))
    }
}
