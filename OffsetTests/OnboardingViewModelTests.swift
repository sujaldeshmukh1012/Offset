import Testing
@testable import Offset

@MainActor
struct OnboardingViewModelTests {
    @Test func completeFlowBuildsAValidatedProfile() throws {
        let model = OnboardingViewModel(profile: nil, locations: try LocationService.bundled())

        #expect(model.step == .welcome)
        model.advance()
        model.homeStatus = .homeowner
        model.advance()
        model.updateZIPCode("02108 extra")

        #expect(model.zipCode == "02108")
        #expect(model.derivedState == "MA")

        model.advance()
        #expect(model.availableUtilities.contains { $0.id == "national-grid-ma" })
        model.chooseUtility("national-grid-ma")
        model.advance()
        model.toggleProject(.heatPump)
        model.toggleProject(.insulation)

        let profile = try #require(model.makeProfile())
        #expect(profile.zipCode == "02108")
        #expect(profile.state == "MA")
        #expect(profile.isHomeowner)
        #expect(profile.utilityProvider == "national-grid-ma")
        #expect(profile.selectedProjects == [.heatPump, .insulation])
    }

    @Test func changingZIPClearsAnEarlierUtilityChoice() throws {
        let model = OnboardingViewModel(profile: nil, locations: try LocationService.bundled())
        model.updateZIPCode("10001")
        model.chooseUtility("con-edison")

        model.updateZIPCode("94105")

        #expect(model.derivedState == "CA")
        #expect(model.selectedUtilityID == nil)
        #expect(!model.hasChosenUtility)
    }

    @Test func editingPreservesProfileFieldsManagedOutsideOnboarding() throws {
        let existing = UserProfile(
            zipCode: "10001",
            state: "NY",
            utilityProvider: "con-edison",
            isHomeowner: false,
            selectedProjects: [.evPurchase],
            annualIncomeUSD: 85_000,
            filingStatus: .singleOrOther,
            vehicleCondition: .new,
            vehicleCategory: .car
        )
        let model = OnboardingViewModel(profile: existing, locations: try LocationService.bundled())

        #expect(model.step == .homeStatus)
        let updated = try #require(model.makeProfile())
        #expect(updated.annualIncomeUSD == 85_000)
        #expect(updated.filingStatus == .singleOrOther)
        #expect(updated.vehicleCondition == .new)
        #expect(updated.vehicleCategory == .car)
    }
}
