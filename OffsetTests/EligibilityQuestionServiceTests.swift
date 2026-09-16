import Foundation
import Testing
@testable import Offset

struct EligibilityQuestionServiceTests {
    private var dataset: IncentiveDataset {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Data/offset_seed.json")
            return try IncentiveDatasetStore.decode(Data(contentsOf: url))
        }
    }

    private var referenceDate: Date {
        get throws { try #require(ISO8601DateFormatter().date(from: "2026-09-14T00:00:00Z")) }
    }

    @Test func questionsAreDerivedFromRelevantProjectAndUtilityPrograms() throws {
        let profile = UserProfile(
            zipCode: "33101",
            state: "FL",
            utilityProvider: "fpl",
            isHomeowner: true,
            selectedProjects: [.heatPump]
        )

        let questions = EligibilityQuestionService.questions(
            for: .heatPump,
            profile: profile,
            dataset: try dataset
        )

        #expect(questions.map(\.id) == ["contractor_participating", "seer2"])
    }

    @Test func qualifyingAnswersPromoteFPLRebateIntoExactMatching() throws {
        let profile = UserProfile(
            zipCode: "33101",
            state: "FL",
            utilityProvider: "fpl",
            isHomeowner: true,
            selectedProjects: [.heatPump],
            eligibilityAnswers: [
                "contractor_participating": .boolean(true),
                "seer2": .number(16)
            ]
        )
        let programs = IncentiveDatasetStore.appPrograms(
            from: try dataset,
            referenceDate: try referenceDate,
            profile: profile
        )
        let matches = MatchingEngine(programs: programs, referenceDate: try referenceDate).matches(
            for: profile,
            project: .heatPump,
            stickerPriceUSD: 8_000,
            hasPremiumAccess: true
        )

        #expect(matches.first { $0.program.id == "fl_fpl_ac_rebate" }?.estimatedSavingsUSD == 200)
    }

    @Test func disqualifyingAnswerRemovesProgramRatherThanReportingZeroSavings() throws {
        let profile = UserProfile(
            zipCode: "33101",
            state: "FL",
            utilityProvider: "fpl",
            isHomeowner: true,
            selectedProjects: [.heatPump],
            eligibilityAnswers: [
                "contractor_participating": .boolean(false),
                "seer2": .number(16)
            ]
        )
        let programs = IncentiveDatasetStore.appPrograms(
            from: try dataset,
            referenceDate: try referenceDate,
            profile: profile
        )

        #expect(!programs.contains { $0.id == "fl_fpl_ac_rebate" })
    }

    @Test func tierAnswersResolveNewYorkVehicleAmount() throws {
        let profile = UserProfile(
            zipCode: "10001",
            state: "NY",
            utilityProvider: "con-edison",
            isHomeowner: false,
            selectedProjects: [.evPurchase],
            vehicleCondition: .new,
            eligibilityAnswers: [
                "dealer_participating": .boolean(true),
                "vehicle_on_eligible_list": .boolean(true),
                "epa_range_miles": .number(250),
                "base_msrp": .number(40_000)
            ]
        )
        let programs = IncentiveDatasetStore.appPrograms(
            from: try dataset,
            referenceDate: try referenceDate,
            profile: profile
        )
        let match = MatchingEngine(programs: programs, referenceDate: try referenceDate).matches(
            for: profile,
            project: .evPurchase,
            stickerPriceUSD: 42_000,
            hasPremiumAccess: true
        ).first { $0.program.id == "ny_drive_clean" }

        #expect(match?.estimatedSavingsUSD == 2_000)
    }

    @Test func legacyProfilesDecodeWithEmptyEligibilityAnswers() throws {
        let legacy = Data(#"{"zipCode":"10001","state":"NY","isHomeowner":true,"selectedProjects":["solar"]}"#.utf8)
        let profile = try JSONDecoder().decode(UserProfile.self, from: legacy)

        #expect(profile.eligibilityAnswers.isEmpty)
    }
}
