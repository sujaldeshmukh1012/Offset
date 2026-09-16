import Foundation
import Testing
@testable import Offset

struct ProgramCatalogTests {
    @Test func bundledProductionCatalogDecodesAndValidates() throws {
        let resourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Offset/Resources/programs.json")

        let catalog = try ProgramStore.decodeCatalog(from: Data(contentsOf: resourceURL))

        #expect(catalog.schemaVersion == ProgramCatalog.currentSchemaVersion)
        #expect(catalog.programs.count == 14)
        #expect(Set(catalog.programs.map(\.id)).count == catalog.programs.count)
        #expect(catalog.programs.contains { $0.status == .active })
        #expect(catalog.programs.allSatisfy { $0.sourceURL.hasPrefix("https://") })
        #expect(!catalog.programs.contains { $0.sourceURL.contains("example.com") })
    }

    @Test func productionCatalogIncludesVerifiedNewYorkPrograms() throws {
        let resourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Offset/Resources/programs.json")
        let programs = try ProgramStore.decodeCatalog(from: Data(contentsOf: resourceURL)).programs
        let solar = try #require(programs.first { $0.id == "new-york-residential-solar-equipment-credit" })
        let nationalGrid = try #require(programs.first { $0.id == "new-york-clean-heat-hpwh-national-grid" })
        let conEdison = try #require(programs.first { $0.id == "new-york-clean-heat-hpwh-con-edison" })

        #expect(solar.amountType == .upTo(5_000, percentage: 0.25))
        #expect(solar.eligibilityStates == ["NY"])
        #expect(nationalGrid.amountType == .fixedAmount(1_250))
        #expect(nationalGrid.eligibilityUtilities == ["national-grid-ny"])
        #expect(conEdison.amountType == .fixedAmount(1_000))
        #expect(programs.filter { $0.id.hasPrefix("new-york-clean-heat-hpwh-") }.count == 6)
    }

    @Test func verifiedNewYorkProgramsProduceExactUtilityScopedCalculations() throws {
        let resourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Offset/Resources/programs.json")
        let programs = try ProgramStore.decodeCatalog(from: Data(contentsOf: resourceURL)).programs
        let referenceDate = try #require(ISO8601DateFormatter().date(from: "2026-09-13T12:00:00Z"))
        let engine = MatchingEngine(programs: programs, referenceDate: referenceDate)
        var profile = UserProfile(
            zipCode: "14228",
            state: "NY",
            utilityProvider: "national-grid-ny",
            isHomeowner: true,
            selectedProjects: [.solar, .waterHeater]
        )

        let solar = engine.matches(
            for: profile,
            project: .solar,
            stickerPriceUSD: 12_000,
            hasPremiumAccess: true
        )
        #expect(solar.map(\.program.id) == ["new-york-residential-solar-equipment-credit"])
        #expect(solar.first?.estimatedSavingsUSD == 3_000)

        let nationalGrid = engine.matches(
            for: profile,
            project: .waterHeater,
            stickerPriceUSD: 2_500,
            hasPremiumAccess: true
        )
        #expect(nationalGrid.map(\.program.id) == ["new-york-clean-heat-hpwh-national-grid"])
        #expect(nationalGrid.first?.estimatedSavingsUSD == 1_250)

        profile.utilityProvider = "con-edison"
        let conEdison = engine.matches(
            for: profile,
            project: .waterHeater,
            stickerPriceUSD: 2_500,
            hasPremiumAccess: true
        )
        #expect(conEdison.map(\.program.id) == ["new-york-clean-heat-hpwh-con-edison"])
        #expect(conEdison.first?.estimatedSavingsUSD == 1_000)
    }

    @Test func productionCatalogIncludesCurrentMassachusettsSolarCredit() throws {
        let resourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Offset/Resources/programs.json")
        let programs = try ProgramStore.decodeCatalog(from: Data(contentsOf: resourceURL)).programs
        let credit = try #require(programs.first {
            $0.id == "massachusetts-residential-renewable-energy-credit"
        })

        #expect(credit.status == .active)
        #expect(credit.level == .state)
        #expect(credit.amountType == .upTo(1_000, percentage: 0.15))
        #expect(credit.eligibilityStates == ["MA"])
        #expect(credit.projectTypes == [.solar])
    }

    @Test func rejectsUnsupportedSchemaVersions() {
        let catalog = ProgramCatalog(
            schemaVersion: 999,
            generatedAt: Date(timeIntervalSince1970: 0),
            programs: []
        )

        #expect(throws: ProgramStoreError.unsupportedSchemaVersion(999)) {
            try ProgramStore.validate(catalog)
        }
    }

    @Test func rejectsDuplicateIDsAndInvalidSourceURLs() {
        let invalid = Self.program(id: "duplicate", sourceURL: "http://example.com")
        let catalog = ProgramCatalog(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 0),
            programs: [invalid, invalid]
        )

        #expect(throws: ProgramStoreError.self) {
            try ProgramStore.validate(catalog)
        }
    }

    @Test func rejectsMalformedJSONAndInvalidFinancialRules() {
        #expect(throws: Error.self) {
            try ProgramStore.decodeCatalog(from: Data("{not-json".utf8))
        }

        let invalidAmount = Self.program(id: "invalid-amount", sourceURL: "https://example.com")
        let invalidCatalog = ProgramCatalog(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 0),
            programs: [Program(
                id: invalidAmount.id,
                name: invalidAmount.name,
                level: invalidAmount.level,
                benefitType: invalidAmount.benefitType,
                status: invalidAmount.status,
                projectTypes: invalidAmount.projectTypes,
                amountType: .percentage(1.01),
                eligibilityStates: invalidAmount.eligibilityStates,
                eligibilityUtilities: invalidAmount.eligibilityUtilities,
                eligibleHomeOccupancies: invalidAmount.eligibleHomeOccupancies,
                eligibleVehicleConditions: invalidAmount.eligibleVehicleConditions,
                incomeCapsUSD: invalidAmount.incomeCapsUSD,
                vehiclePriceCapsUSD: invalidAmount.vehiclePriceCapsUSD,
                annualCaps: invalidAmount.annualCaps,
                effectiveDate: invalidAmount.effectiveDate,
                deadline: invalidAmount.deadline,
                sourceURL: invalidAmount.sourceURL,
                lastVerifiedDate: invalidAmount.lastVerifiedDate,
                eligibilitySummary: invalidAmount.eligibilitySummary,
                claimSteps: invalidAmount.claimSteps,
                description: invalidAmount.description
            )]
        )
        #expect(throws: ProgramStoreError.self) { try ProgramStore.validate(invalidCatalog) }
    }

    @Test func productionAmountsMatchPublishedRuleInputs() throws {
        let resourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Offset/Resources/programs.json")
        let programs = try ProgramStore.decodeCatalog(from: Data(contentsOf: resourceURL)).programs

        #expect(programs.first { $0.id == "massachusetts-residential-renewable-energy-credit" }?.amountType == .upTo(1_000, percentage: 0.15))
        #expect(programs.first { $0.id == "federal-25c-heat-pump" }?.amountType == .upTo(2_000, percentage: 0.30))
        #expect(programs.first { $0.id == "federal-25c-insulation" }?.amountType == .upTo(1_200, percentage: 0.30))
        #expect(programs.first { $0.id == "federal-25d-solar" }?.amountType == .percentage(0.30))
        #expect(programs.first { $0.id == "federal-30d-new-clean-vehicle" }?.amountType == .fixedAmount(7_500))
        #expect(programs.first { $0.id == "federal-25e-used-clean-vehicle" }?.amountType == .upTo(4_000, percentage: 0.30))
    }

    @Test func federalVehicleRulesCarryExactCaps() throws {
        let resourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Offset/Resources/programs.json")
        let programs = try ProgramStore.decodeCatalog(from: Data(contentsOf: resourceURL)).programs
        let newCredit = try #require(programs.first { $0.id == "federal-30d-new-clean-vehicle" })
        let usedCredit = try #require(programs.first { $0.id == "federal-25e-used-clean-vehicle" })

        #expect(newCredit.incomeCapsUSD[.singleOrOther] == 150_000)
        #expect(newCredit.incomeCapsUSD[.headOfHousehold] == 225_000)
        #expect(newCredit.incomeCapsUSD[.marriedFilingJointly] == 300_000)
        #expect(newCredit.vehiclePriceCapsUSD[.car] == 55_000)
        #expect(newCredit.vehiclePriceCapsUSD[.suvPickupOrVan] == 80_000)
        #expect(usedCredit.incomeCapsUSD[.singleOrOther] == 75_000)
        #expect(usedCredit.vehiclePriceCapsUSD[.usedVehicle] == 25_000)
        #expect(usedCredit.amountType == .upTo(4_000, percentage: 0.30))
    }

    private static func program(id: String, sourceURL: String) -> Program {
        Program(
            id: id,
            name: "Test",
            level: .state,
            benefitType: .rebate,
            status: .active,
            projectTypes: [.heatPump],
            amountType: .fixedAmount(100),
            eligibilityStates: ["MA"],
            eligibilityUtilities: [],
            eligibleHomeOccupancies: [],
            eligibleVehicleConditions: [],
            incomeCapsUSD: [:],
            vehiclePriceCapsUSD: [:],
            annualCaps: [],
            effectiveDate: Date(timeIntervalSince1970: 0),
            deadline: nil,
            sourceURL: sourceURL,
            lastVerifiedDate: Date(timeIntervalSince1970: 0),
            eligibilitySummary: ["Test"],
            claimSteps: ["Test"],
            description: "Test"
        )
    }
}
