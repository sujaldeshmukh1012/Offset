import Foundation
import Testing
@testable import Offset

@MainActor
struct ProjectPricerViewModelTests {
    private let profile = UserProfile(
        zipCode: "02108",
        state: "MA",
        utilityProvider: "grid",
        isHomeowner: true,
        selectedProjects: [.heatPump]
    )

    @Test func sanitizesAndValidatesCurrencyInput() {
        let model = makeModel()
        model.setPriceText("$12,345.678")
        #expect(model.priceText == "12345.67")

        model.setPriceText("0")
        model.calculate(profile: profile, hasPremiumAccess: false)
        #expect(model.status == .invalidPrice("Enter a price greater than $0."))
    }

    @Test func freePresentationShowsMatchedProgramsAndEstimatedSavings() {
        let model = makeModel()
        model.setPriceText("10000")
        model.calculate(profile: profile, hasPremiumAccess: false)

        #expect(model.status == .results)
        #expect(model.rows.map(\.id) == ["utility", "state", "federal"])
        #expect(model.visibleSavingsUSD == 3_520)
        #expect(model.visibleNetPriceUSD == 6_480)
        #expect(model.hasLockedMatches)
    }

    @Test func premiumPresentationShowsFullOrderedStack() {
        let model = makeModel()
        model.setPriceText("10000")
        model.calculate(profile: profile, hasPremiumAccess: true)

        #expect(model.rows.map(\.id) == ["utility", "state", "federal"])
        #expect(model.visibleSavingsUSD == 3_520)
        #expect(model.visibleNetPriceUSD == 6_480)
        #expect(!model.hasLockedMatches)
    }

    @Test func reportsIncompleteProfileNoMatchAndLoadFailure() {
        let model = makeModel()
        model.setPriceText("10000")
        model.calculate(profile: nil, hasPremiumAccess: false)
        if case .incompleteProfile = model.status {} else { Issue.record("Expected incomplete profile") }

        let noMatch = ProjectPricerViewModel(
            selectedProject: .solar,
            referenceDate: Self.now,
            loadPrograms: { Self.programs }
        )
        noMatch.setPriceText("10000")
        noMatch.calculate(profile: profile, hasPremiumAccess: false)
        #expect(noMatch.status == .noMatches)

        let loadFailure = ProjectPricerViewModel(selectedProject: .heatPump, loadPrograms: { throw TestError.failed })
        if case .dataFailure = loadFailure.status {} else { Issue.record("Expected data failure") }
    }

    private func makeModel() -> ProjectPricerViewModel {
        ProjectPricerViewModel(
            selectedProject: .heatPump,
            referenceDate: Self.now,
            loadPrograms: { Self.programs }
        )
    }

    private enum TestError: Error { case failed }
    private static let now = Date(timeIntervalSince1970: 1_000)
    private static let programs = [
        program(id: "federal", level: .federal, amount: .percentage(0.20)),
        program(id: "utility", level: .utility, amount: .fixedAmount(1_000)),
        program(id: "state", level: .state, amount: .percentage(0.10))
    ]

    private static func program(id: String, level: ProgramLevel, amount: AmountType) -> Program {
        Program(
            id: id,
            name: "\(level.rawValue.capitalized) program",
            level: level,
            benefitType: .rebate,
            status: .active,
            projectTypes: [.heatPump],
            amountType: amount,
            eligibilityStates: level == .federal ? [] : ["MA"],
            eligibilityUtilities: level == .utility ? ["grid"] : [],
            eligibleHomeOccupancies: [],
            eligibleVehicleConditions: [],
            incomeCapsUSD: [:],
            vehiclePriceCapsUSD: [:],
            annualCaps: [],
            effectiveDate: Date(timeIntervalSince1970: 0),
            deadline: nil,
            sourceURL: "https://example.com",
            lastVerifiedDate: Date(timeIntervalSince1970: 0),
            eligibilitySummary: ["Eligible"],
            claimSteps: ["Claim"],
            description: "Test program"
        )
    }
}
