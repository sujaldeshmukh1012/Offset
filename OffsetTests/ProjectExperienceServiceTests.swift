import Foundation
import Testing
@testable import Offset

struct ProjectExperienceServiceTests {
    @Test func checklistGroupsFollowFinancialApplicationOrder() {
        let programs = [
            Self.program(id: "federal-fixed", level: .federal, amount: .fixedAmount(500)),
            Self.program(id: "federal-percent", level: .federal, amount: .percentage(0.20)),
            Self.program(id: "state-percent", level: .state, amount: .percentage(0.10)),
            Self.program(id: "utility", level: .utility, amount: .fixedAmount(1_000))
        ]
        let service = ProjectExperienceService(programs: programs, referenceDate: Date(timeIntervalSince1970: 100))
        let profile = UserProfile(
            zipCode: "02108",
            state: "MA",
            utilityProvider: "evergreen-electric",
            isHomeowner: true,
            selectedProjects: [.heatPump]
        )
        let project = SavedProject(name: "Heat pump", projectType: .heatPump, stickerPriceUSD: 10_000)

        let groups = service.checklistGroups(for: project, profile: profile)

        #expect(groups.map { $0.program.id } == ["utility", "state-percent", "federal-percent", "federal-fixed"])
        #expect(groups.map { $0.steps } == [["utility step"], ["state-percent step"], ["federal-percent step"], ["federal-fixed step"]])
    }

    @Test func relatedProgramsIncludeClosedHistoryWithoutTreatingItAsAMatch() {
        let active = Self.program(id: "active", level: .federal, amount: .fixedAmount(500))
        let closed = Self.program(id: "closed", level: .federal, amount: .fixedAmount(500), status: .closed)
        let service = ProjectExperienceService(programs: [closed, active], referenceDate: Date(timeIntervalSince1970: 100))
        let profile = UserProfile(zipCode: "02108", state: "MA", isHomeowner: true, selectedProjects: [.heatPump])
        let project = SavedProject(name: "Heat pump", projectType: .heatPump, stickerPriceUSD: 10_000)

        #expect(service.matches(for: project, profile: profile).map { $0.program.id } == ["active"])
        #expect(service.relatedPrograms(for: ProjectType.heatPump).map { $0.id } == ["active", "closed"])
    }

    private static func program(
        id: String,
        level: ProgramLevel,
        amount: AmountType,
        status: ProgramStatus = .active
    ) -> Program {
        Program(
            id: id,
            name: id,
            level: level,
            benefitType: level == .federal ? .nonrefundableTaxCredit : .rebate,
            status: status,
            projectTypes: [.heatPump],
            amountType: amount,
            eligibilityStates: level == .federal ? [] : ["MA"],
            eligibilityUtilities: level == .utility ? ["evergreen-electric"] : [],
            eligibleHomeOccupancies: [],
            eligibleVehicleConditions: [],
            incomeCapsUSD: [:],
            vehiclePriceCapsUSD: [:],
            annualCaps: [],
            effectiveDate: Date(timeIntervalSince1970: 0),
            deadline: nil,
            sourceURL: "https://example.com/\(id)",
            lastVerifiedDate: Date(timeIntervalSince1970: 0),
            eligibilitySummary: ["Eligible"],
            claimSteps: ["\(id) step"],
            description: "Test program"
        )
    }
}
