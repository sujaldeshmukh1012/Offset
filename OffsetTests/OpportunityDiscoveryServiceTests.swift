import Foundation
import Testing
@testable import Offset

struct OpportunityDiscoveryServiceTests {
    @Test func prioritizesSelectedCategoriesThenStrongestOpportunities() {
        let profile = UserProfile(
            zipCode: "10001",
            state: "NY",
            utilityProvider: "con-edison",
            isHomeowner: true,
            selectedProjects: [.solar]
        )
        let snapshot = OpportunityDiscoveryService.snapshot(
            for: profile,
            programs: [
                program(id: "heat-1", project: .heatPump, level: .federal),
                program(id: "heat-2", project: .heatPump, level: .state, states: ["NY"]),
                program(id: "solar-1", project: .solar, level: .federal)
            ]
        )

        #expect(snapshot.opportunities.map(\.project) == [.solar, .heatPump])
        #expect(snapshot.totalProgramCount == 3)
        #expect(snapshot.programCountsByLevel[.federal] == 2)
        #expect(snapshot.programCountsByLevel[.state] == 1)
    }

    @Test func renterDoesNotReceiveHomeownerOnlyRecommendation() {
        let renter = UserProfile(
            zipCode: "10001",
            state: "NY",
            isHomeowner: false,
            selectedProjects: [.heatPump, .evPurchase]
        )
        let homeownerOnly = program(
            id: "owner-heat",
            project: .heatPump,
            level: .federal,
            occupancies: [.homeownerPrimaryResidence]
        )
        let renterEV = program(
            id: "renter-ev",
            project: .evPurchase,
            level: .federal,
            occupancies: [.renterPrimaryResidence, .homeownerPrimaryResidence]
        )

        let snapshot = OpportunityDiscoveryService.snapshot(for: renter, programs: [homeownerOnly, renterEV])

        #expect(snapshot.opportunities.map(\.project) == [.evPurchase])
    }

    @Test func unknownUtilityKeepsFederalAndStateButNotUtilityPrograms() {
        let profile = UserProfile(
            zipCode: "10001",
            state: "NY",
            utilityProvider: nil,
            isHomeowner: true,
            selectedProjects: [.solar]
        )
        let snapshot = OpportunityDiscoveryService.snapshot(
            for: profile,
            programs: [
                program(id: "federal", project: .solar, level: .federal),
                program(id: "state", project: .solar, level: .state, states: ["NY"]),
                program(
                    id: "utility",
                    project: .solar,
                    level: .utility,
                    states: ["NY"],
                    utilities: ["con-edison"]
                )
            ]
        )

        #expect(snapshot.totalProgramCount == 2)
        #expect(snapshot.programCountsByLevel[.federal] == 1)
        #expect(snapshot.programCountsByLevel[.state] == 1)
        #expect(snapshot.programCountsByLevel[.utility] == nil)
    }

    @Test func partialAndUnsupportedCoverageRemainExplicit() {
        let florida = UserProfile(
            zipCode: "33101",
            state: "FL",
            utilityProvider: "fpl",
            isHomeowner: true,
            selectedProjects: [.heatPump]
        )
        let snapshot = OpportunityDiscoveryService.bundledSnapshot(for: florida)

        #expect(snapshot.errorMessage == nil)
        #expect(snapshot.opportunities.allSatisfy { $0.coverage.confidence != .verified || $0.coverage.isProductionMarket })
    }

    private func program(
        id: String,
        project: ProjectType,
        level: ProgramLevel,
        states: [String] = [],
        utilities: [String] = [],
        occupancies: [HomeOccupancy] = []
    ) -> Program {
        Program(
            id: id,
            name: id,
            level: level,
            benefitType: .rebate,
            status: .active,
            projectTypes: [project],
            amountType: .fixedAmount(500),
            eligibilityStates: states,
            eligibilityUtilities: utilities,
            eligibleHomeOccupancies: occupancies,
            eligibleVehicleConditions: [],
            incomeCapsUSD: [:],
            vehiclePriceCapsUSD: [:],
            annualCaps: [],
            effectiveDate: .distantPast,
            deadline: nil,
            sourceURL: "https://example.gov/\(id)",
            lastVerifiedDate: .now,
            eligibilitySummary: ["Profile must match"],
            claimSteps: ["Apply"],
            description: "Test program"
        )
    }
}
