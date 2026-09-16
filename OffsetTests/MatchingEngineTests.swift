import Foundation
import Testing
@testable import Offset

struct MatchingEngineTests {
    private let project = ProjectType.heatPump

    @Test func filtersByProjectStateAndUtility() {
        let engine = MatchingEngine(programs: Self.samplePrograms)
        let profile = UserProfile(
            zipCode: "02108",
            state: "ma",
            utilityProvider: "evergreen-electric",
            isHomeowner: true,
            selectedProjects: [.heatPump]
        )

        let matches = engine.matches(for: profile, project: project, stickerPriceUSD: 10_000)

        #expect(matches.map(\.program.id) == ["utility", "state-percent", "federal-percent", "federal-fixed"])
        #expect(!matches.contains { $0.program.id == "other-state" })
        #expect(!matches.contains { $0.program.id == "solar" })
    }

    @Test func appliesProgramsInStackingOrderUsingRunningPrice() {
        let engine = MatchingEngine(programs: Self.samplePrograms)
        let profile = UserProfile(
            zipCode: "02108",
            state: "MA",
            utilityProvider: "evergreen-electric",
            isHomeowner: true,
            selectedProjects: [.heatPump]
        )

        let matches = engine.matches(for: profile, project: project, stickerPriceUSD: 10_000)

        #expect(matches.map(\.estimatedSavingsUSD) == [1_000, 900, 1_620, 500])
        #expect(matches.map(\.priceAfterUSD) == [9_000, 8_100, 6_480, 5_980])
    }

    @Test func enforcesIncomeCapOnlyWhenIncomeIsProvided() {
        let engine = MatchingEngine(programs: Self.samplePrograms)
        var profile = UserProfile(
            zipCode: "02108",
            state: "MA",
            utilityProvider: nil,
            isHomeowner: true,
            selectedProjects: [.heatPump]
        )

        #expect(engine.matches(for: profile, project: project, stickerPriceUSD: 10_000).contains { $0.program.id == "state-percent" })

        profile.annualIncomeUSD = 100_001
        profile.filingStatus = .singleOrOther
        #expect(!engine.matches(for: profile, project: project, stickerPriceUSD: 10_000).contains { $0.program.id == "state-percent" })
    }

    @Test func locksNonFederalProgramsForFreeUsers() {
        let engine = MatchingEngine(programs: Self.samplePrograms)
        let profile = UserProfile(
            zipCode: "02108",
            state: "MA",
            utilityProvider: "evergreen-electric",
            isHomeowner: true,
            selectedProjects: [.heatPump]
        )

        let freeMatches = engine.matches(for: profile, project: project, stickerPriceUSD: 10_000)
        let paidMatches = engine.matches(for: profile, project: project, stickerPriceUSD: 10_000, hasPremiumAccess: true)

        #expect(freeMatches.filter(\.isLocked).map(\.program.level) == [.utility, .state])
        #expect(paidMatches.allSatisfy { !$0.isLocked })
    }

    @Test func capsSavingsAtTheRemainingPrice() {
        let largeRebate = Self.program(id: "large", level: .utility, amount: .fixedAmount(50_000))
        let matches = MatchingEngine(programs: [largeRebate]).matches(
            for: UserProfile(
                zipCode: "02108",
                state: "MA",
                utilityProvider: "evergreen-electric",
                isHomeowner: true,
                selectedProjects: [.heatPump]
            ),
            project: project,
            stickerPriceUSD: 8_000
        )

        #expect(matches.first?.estimatedSavingsUSD == 8_000)
        #expect(matches.first?.priceAfterUSD == 0)
    }

    @Test func calculatesEveryAmountTypeAndUpToCapBoundary() {
        let profile = UserProfile(zipCode: "02108", state: "MA", isHomeowner: true, selectedProjects: [.heatPump])
        let percentage = MatchingEngine(programs: [Self.program(id: "percent", level: .federal, amount: .percentage(0.30))])
            .matches(for: profile, project: .heatPump, stickerPriceUSD: 10_000)
        let fixed = MatchingEngine(programs: [Self.program(id: "fixed", level: .federal, amount: .fixedAmount(1_250))])
            .matches(for: profile, project: .heatPump, stickerPriceUSD: 10_000)
        let belowCap = MatchingEngine(programs: [Self.program(id: "below", level: .federal, amount: .upTo(2_000, percentage: 0.30))])
            .matches(for: profile, project: .heatPump, stickerPriceUSD: 5_000)
        let atCap = MatchingEngine(programs: [Self.program(id: "at", level: .federal, amount: .upTo(2_000, percentage: 0.30))])
            .matches(for: profile, project: .heatPump, stickerPriceUSD: 20_000)

        #expect(percentage.first?.estimatedSavingsUSD == 3_000)
        #expect(fixed.first?.estimatedSavingsUSD == 1_250)
        #expect(belowCap.first?.estimatedSavingsUSD == 1_500)
        #expect(atCap.first?.estimatedSavingsUSD == 2_000)
    }

    @Test func resolvesEqualPriorityTiesByStableProgramID() {
        let profile = UserProfile(zipCode: "02108", state: "MA", isHomeowner: true, selectedProjects: [.heatPump])
        let programs = [
            Self.program(id: "z-last", level: .federal, amount: .fixedAmount(100)),
            Self.program(id: "a-first", level: .federal, amount: .fixedAmount(100))
        ]

        let matches = MatchingEngine(programs: programs).matches(
            for: profile,
            project: .heatPump,
            stickerPriceUSD: 1_000
        )

        #expect(matches.map(\.program.id) == ["a-first", "z-last"])
    }

    @Test func verifiedExclusiveRuleKeepsTheHigherValueProgram() {
        let lower = Self.program(id: "lower_program", level: .state, amount: .fixedAmount(500))
        let higher = Self.program(id: "higher_program", level: .state, amount: .fixedAmount(1_000))
        let policy = ProgramStackingPolicy(rules: [
            .init(
                programA: "lower_program",
                programB: "higher_program",
                relationship: "exclusive",
                notes: nil,
                isVerified: true
            )
        ])
        let profile = UserProfile(zipCode: "02108", state: "MA", isHomeowner: true, selectedProjects: [.heatPump])

        let matches = MatchingEngine(programs: [lower, higher], stackingPolicy: policy).matches(
            for: profile,
            project: .heatPump,
            stickerPriceUSD: 5_000
        )

        #expect(matches.map(\.program.id) == ["higher_program"])
    }

    @Test func unverifiedMayStackRuleFailsClosedToOneProgram() {
        let first = Self.program(id: "first_program", level: .state, amount: .fixedAmount(700))
        let second = Self.program(id: "second_program", level: .state, amount: .fixedAmount(900))
        let policy = ProgramStackingPolicy(rules: [
            .init(
                programA: "first_program",
                programB: "second_program",
                relationship: "may_stack",
                notes: nil,
                isVerified: false
            )
        ])
        let profile = UserProfile(zipCode: "02108", state: "MA", isHomeowner: true, selectedProjects: [.heatPump])

        let matches = MatchingEngine(programs: [first, second], stackingPolicy: policy).matches(
            for: profile,
            project: .heatPump,
            stickerPriceUSD: 5_000
        )

        #expect(matches.map(\.program.id) == ["second_program"])
    }

    @Test func explicitStackingOrderOverridesFallbackOrder() {
        let normallyFirst = Self.program(id: "a_program", level: .state, amount: .fixedAmount(100))
        let explicitlyFirst = Self.program(id: "z_program", level: .state, amount: .fixedAmount(100))
        let policy = ProgramStackingPolicy(rules: [
            .init(
                programA: "z_program",
                programB: "a_program",
                relationship: "applies_before",
                notes: nil,
                isVerified: true
            )
        ])
        let profile = UserProfile(zipCode: "02108", state: "MA", isHomeowner: true, selectedProjects: [.heatPump])

        let matches = MatchingEngine(programs: [normallyFirst, explicitlyFirst], stackingPolicy: policy).matches(
            for: profile,
            project: .heatPump,
            stickerPriceUSD: 5_000
        )

        #expect(matches.map(\.program.id) == ["z_program", "a_program"])
    }

    @Test func missingOptionalIncomeDoesNotInventIneligibility() {
        let capped = Self.program(
            id: "income-capped",
            level: .state,
            amount: .fixedAmount(500),
            incomeCap: 50_000
        )
        let profile = UserProfile(zipCode: "02108", state: "MA", isHomeowner: true, selectedProjects: [.heatPump])

        #expect(MatchingEngine(programs: [capped]).matches(
            for: profile,
            project: .heatPump,
            stickerPriceUSD: 5_000
        ).count == 1)
    }

    @Test func excludesClosedAndExpiredPrograms() {
        let closed = Self.program(id: "closed", level: .federal, amount: .fixedAmount(100), status: .closed)
        let expired = Self.program(
            id: "expired",
            level: .federal,
            amount: .fixedAmount(100),
            deadline: Date(timeIntervalSince1970: 10)
        )
        let engine = MatchingEngine(programs: [closed, expired], referenceDate: Date(timeIntervalSince1970: 20))
        let profile = UserProfile(zipCode: "02108", state: "MA", isHomeowner: true, selectedProjects: [.heatPump])

        #expect(engine.matches(for: profile, project: .heatPump, stickerPriceUSD: 1_000).isEmpty)
    }

    @Test func enforcesVehicleConditionPriceAndFilingStatusCaps() {
        let credit = Self.program(
            id: "ev-credit",
            level: .federal,
            amount: .fixedAmount(7_500),
            projects: [.evPurchase],
            vehicleConditions: [.new],
            vehiclePriceCaps: [.car: 55_000],
            incomeCaps: [.singleOrOther: 150_000]
        )
        let engine = MatchingEngine(programs: [credit])
        var profile = UserProfile(
            zipCode: "02108",
            state: "MA",
            isHomeowner: false,
            selectedProjects: [.evPurchase],
            annualIncomeUSD: 150_000,
            filingStatus: .singleOrOther,
            vehicleCondition: .new,
            vehicleCategory: .car
        )

        #expect(engine.matches(for: profile, project: .evPurchase, stickerPriceUSD: 55_000).count == 1)
        #expect(engine.matches(for: profile, project: .evPurchase, stickerPriceUSD: 55_001).isEmpty)
        profile.annualIncomeUSD = 150_001
        #expect(engine.matches(for: profile, project: .evPurchase, stickerPriceUSD: 55_000).isEmpty)
        profile.annualIncomeUSD = 100_000
        profile.vehicleCondition = .used
        #expect(engine.matches(for: profile, project: .evPurchase, stickerPriceUSD: 20_000).isEmpty)
    }

    private static let samplePrograms: [Program] = [
        program(id: "federal-fixed", level: .federal, amount: .fixedAmount(500)),
        program(id: "other-state", level: .state, amount: .fixedAmount(900), states: ["NY"]),
        program(id: "federal-percent", level: .federal, amount: .percentage(20)),
        program(id: "utility", level: .utility, amount: .fixedAmount(1_000)),
        program(id: "state-percent", level: .state, amount: .percentage(0.10), incomeCap: 100_000),
        program(id: "solar", level: .federal, amount: .percentage(0.30), projects: [.solar])
    ]

    private static func program(
        id: String,
        level: ProgramLevel,
        amount: AmountType,
        states: [String] = ["MA"],
        incomeCap: Double? = nil,
        projects: [ProjectType] = [.heatPump],
        status: ProgramStatus = .active,
        deadline: Date? = nil,
        vehicleConditions: [VehicleCondition] = [],
        vehiclePriceCaps: [VehicleCategory: Double] = [:],
        incomeCaps: [FilingStatus: Double]? = nil
    ) -> Program {
        Program(
            id: id,
            name: id,
            level: level,
            benefitType: level == .federal ? .nonrefundableTaxCredit : .rebate,
            status: status,
            projectTypes: projects,
            amountType: amount,
            eligibilityStates: level == .federal ? [] : states,
            eligibilityUtilities: level == .utility ? ["evergreen-electric"] : [],
            eligibleHomeOccupancies: [],
            eligibleVehicleConditions: vehicleConditions,
            incomeCapsUSD: incomeCaps ?? (incomeCap.map { [.singleOrOther: $0] } ?? [:]),
            vehiclePriceCapsUSD: vehiclePriceCaps,
            annualCaps: [],
            effectiveDate: Date(timeIntervalSince1970: 0),
            deadline: deadline,
            sourceURL: "https://example.com",
            lastVerifiedDate: Date(timeIntervalSince1970: 0),
            eligibilitySummary: ["Test eligibility"],
            claimSteps: [],
            description: "Test program"
        )
    }
}
