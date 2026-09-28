import Foundation
import Testing
@testable import Offset

struct IncentiveDatasetTests {
    private var seedURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Data/offset_seed.json")
    }

    @Test func releaseBundleContainsPublicMatchingCatalog() throws {
        let publicSeedURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Offset/Resources/offset_seed.json")
        let dataset = try IncentiveDatasetStore.decode(Data(contentsOf: publicSeedURL))

        #expect(dataset.programs.count == 38)
        #expect(dataset.sources.count == 33)
        #expect(!dataset.incentiveTiers.isEmpty)
        #expect(!dataset.claimSteps.isEmpty)
        #expect(!dataset.stackingRules.isEmpty)
    }

    @Test func normalizedSeedDecodesAndPassesReferentialValidation() throws {
        let dataset = try IncentiveDatasetStore.decode(Data(contentsOf: seedURL))

        #expect(dataset.states.count == 3)
        #expect(dataset.utilities.count == 19)
        #expect(dataset.sources.count == 33)
        #expect(dataset.programs.count == 38)
        #expect(dataset.programs.filter { $0.matchEnabled == 1 }.count == 24)
        #expect(dataset.coverage.count == 66)
    }

    @Test func everySeedProgramWithAnAppProjectIsIntegrated() throws {
        let dataset = try IncentiveDatasetStore.decode(Data(contentsOf: seedURL))
        let date = try #require(ISO8601DateFormatter().date(from: "2026-09-14T00:00:00Z"))
        let programs = IncentiveDatasetStore.appPrograms(from: dataset, referenceDate: date)

        #expect(programs.count == 70)
        #expect(Set(programs.map(\.id)).count == programs.count)
        #expect(ProjectType.allCases.count == 10)
        #expect(programs.contains { $0.projectTypes == [.batteryStorage] })
        #expect(programs.contains { $0.projectTypes == [.windows] })
        #expect(programs.contains { $0.projectTypes == [.ductwork] })
        #expect(programs.contains { $0.projectTypes == [.weatherization] })
    }

    @Test func exactDynamicTierCanMatchWhileUnsupportedFormulaCannot() throws {
        let dataset = try IncentiveDatasetStore.decode(Data(contentsOf: seedURL))
        let date = try #require(ISO8601DateFormatter().date(from: "2026-09-14T00:00:00Z"))
        let programs = IncentiveDatasetStore.appPrograms(from: dataset, referenceDate: date)
        let profile = UserProfile(
            zipCode: "10901",
            state: "NY",
            utilityProvider: "orange-rockland",
            isHomeowner: true,
            selectedProjects: [.waterHeater]
        )

        let matches = MatchingEngine(programs: programs, referenceDate: date).matches(
            for: profile,
            project: .waterHeater,
            stickerPriceUSD: 2_500,
            hasPremiumAccess: true
        )
        #expect(matches.map(\.program.id) == ["ny_oru_clean_heat-waterheater"])
        #expect(matches.first?.estimatedSavingsUSD == 1_250)

        let nationalGrid = programs.first { $0.id == "ny_national_grid_clean_heat-waterheater" }
        #expect(nationalGrid?.status == .dynamic)
    }

    @Test func dynamicAmountsBecomeAdvisoryWhenVerificationAges() throws {
        let dataset = try IncentiveDatasetStore.decode(Data(contentsOf: seedURL))
        let staleDate = try #require(ISO8601DateFormatter().date(from: "2026-11-01T00:00:00Z"))
        let programs = IncentiveDatasetStore.appPrograms(from: dataset, referenceDate: staleDate)

        #expect(programs.first { $0.id == "ny_oru_clean_heat-waterheater" }?.status == .dynamic)
        #expect(programs.first { $0.id == "ny_solar_tax_credit" }?.status == .dynamic)
    }

    @Test func correctedOfficialLinksAreStored() throws {
        let dataset = try IncentiveDatasetStore.decode(Data(contentsOf: seedURL))
        let sources = Dictionary(uniqueKeysWithValues: dataset.sources.map { ($0.id, $0.url) })

        #expect(sources["src_ny_oru_manual"]?.contains("clean-heating-cooling-with-heat-pumps") == true)
        #expect(sources["src_jea"] == "https://www.jea.com/rebates")
        #expect(sources["src_gru"]?.contains("Rebates-and-Incentives-for-Homes") == true)
        #expect(sources["src_sdge_res"]?.hasPrefix("https://marketplace.sdge.com/") == true)
    }

    @Test func danglingProgramCategoryIsRejected() throws {
        var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: seedURL)) as? [String: Any])
        var links = try #require(object["program_categories"] as? [[String: Any]])
        links.append(["program_id": "missing", "category_id": "solar"])
        object["program_categories"] = links
        let malformed = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: IncentiveDatasetError.self) {
            try IncentiveDatasetStore.decode(malformed)
        }
    }

    @Test func supabaseCatalogRequiresANewerGenerationTimestamp() throws {
        let currentData = try Data(contentsOf: seedURL)
        let current = try IncentiveDatasetStore.decode(currentData)

        #expect(try SupabaseCatalogCache.validatedIncentiveUpdate(currentData, comparedWith: current) == nil)

        var newerObject = try #require(JSONSerialization.jsonObject(with: currentData) as? [String: Any])
        var newerMetadata = try #require(newerObject["meta"] as? [String: Any])
        newerMetadata["generated_at"] = "2026-09-25T12:00:00Z"
        newerObject["meta"] = newerMetadata
        let newerData = try JSONSerialization.data(withJSONObject: newerObject)
        #expect(try SupabaseCatalogCache.validatedIncentiveUpdate(newerData, comparedWith: current) != nil)

        var olderObject = newerObject
        var olderMetadata = newerMetadata
        olderMetadata["generated_at"] = "2026-01-01T00:00:00Z"
        olderObject["meta"] = olderMetadata
        let olderData = try JSONSerialization.data(withJSONObject: olderObject)
        #expect(throws: SupabaseCatalogError.catalogRollback) {
            try SupabaseCatalogCache.validatedIncentiveUpdate(olderData, comparedWith: current)
        }
    }

    @Test func supabaseCatalogRejectsOversizedPayloads() throws {
        let current = try IncentiveDatasetStore.decode(Data(contentsOf: seedURL))
        let oversized = Data(repeating: 0, count: SupabaseCatalogCache.maximumPayloadBytes + 1)

        #expect(throws: SupabaseCatalogError.payloadTooLarge) {
            try SupabaseCatalogCache.validatedIncentiveUpdate(oversized, comparedWith: current)
        }
    }

    @Test func remoteReleaseRequiresEverySupportedUtilityInLocationCatalog() throws {
        let incentiveData = try Data(contentsOf: seedURL)
        let locationURL = try #require(Bundle.main.url(forResource: "location_catalog", withExtension: "json"))
        let locationData = try Data(contentsOf: locationURL)

        #expect(throws: Never.self) {
            try SupabaseCatalogCache.validateRelease(
                incentiveData: incentiveData,
                locationData: locationData
            )
        }

        var object = try #require(JSONSerialization.jsonObject(with: locationData) as? [String: Any])
        var utilities = try #require(object["utilityProviders"] as? [[String: Any]])
        utilities.removeAll { $0["id"] as? String == "con-edison" }
        object["utilityProviders"] = utilities
        let incompatibleData = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: SupabaseCatalogError.incompatibleUtilityCatalog(["con-edison"])) {
            try SupabaseCatalogCache.validateRelease(
                incentiveData: incentiveData,
                locationData: incompatibleData
            )
        }
    }
}
