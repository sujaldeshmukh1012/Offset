import Testing
@testable import Offset

struct LocationServiceTests {
    @Test func bundledCatalogDerivesLaunchStates() throws {
        let service = try LocationService.bundled()

        #expect(service.state(forZIPCode: "94105") == "CA")
        #expect(service.state(forZIPCode: "78701") == "TX")
        #expect(service.state(forZIPCode: "10001") == "NY")
        #expect(service.state(forZIPCode: "02108") == "MA")
        #expect(service.state(forZIPCode: "80202") == "CO")
        #expect(service.state(forZIPCode: "27601") == "NC")
    }

    @Test func ZIPValidationRejectsMalformedAndUnmappedValues() throws {
        let service = try LocationService.bundled()

        #expect(service.state(forZIPCode: "1234") == nil)
        #expect(service.state(forZIPCode: "ABCDE") == nil)
        #expect(service.state(forZIPCode: "00000") == nil)
    }

    @Test func utilityCandidatesAreFilteredAndSortedByState() throws {
        let service = try LocationService.bundled()
        let massachusettsUtilities = service.utilities(in: "ma")

        #expect(!massachusettsUtilities.isEmpty)
        #expect(massachusettsUtilities.allSatisfy { $0.state == "MA" })
        #expect(massachusettsUtilities.map(\.name) == massachusettsUtilities.map(\.name).sorted())
        #expect(service.utilityName(for: "national-grid-ma") == "National Grid")
    }

    @Test func newYorkIncludesAllSevenLaunchUtilities() throws {
        let service = try LocationService.bundled()
        let ids = Set(service.utilities(in: "NY").map(\.id))

        #expect(ids == [
            "central-hudson", "con-edison", "national-grid-ny", "nyseg",
            "orange-rockland", "pseg-long-island", "rge"
        ])
    }

    @Test func ZIPPrefixBoundariesAndUnknownUtilityAreHandled() throws {
        let service = try LocationService(catalog: LocationCatalog(
            schemaVersion: 1,
            stateZIPRanges: [StateZIPRange(state: "XY", ranges: [ZIPPrefixRange(lower: 100, upper: 102)])],
            utilityProviders: [UtilityProvider(id: "xy-power", name: "XY Power", state: "XY")]
        ))

        #expect(service.state(forZIPCode: "10000") == "XY")
        #expect(service.state(forZIPCode: "10299") == "XY")
        #expect(service.state(forZIPCode: "10300") == nil)
        #expect(service.utilities(in: "xy").map(\.id) == ["xy-power"])
        #expect(service.utilityName(for: "not-listed") == nil)
    }

    @Test func rejectsUnsupportedLocationSchema() {
        #expect(throws: LocationCatalogError.unsupportedSchema(2)) {
            try LocationService(catalog: LocationCatalog(schemaVersion: 2, stateZIPRanges: [], utilityProviders: []))
        }
    }
}
