import Foundation
import XCTest
@testable import Offset

final class PerformanceTests: XCTestCase {
    func testProgramCatalogDecodeAndValidationPerformance() throws {
        let resourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Offset/Resources/programs.json")
        let data = try Data(contentsOf: resourceURL)

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            for _ in 0..<100 {
                do {
                    _ = try ProgramStore.decodeCatalog(from: data)
                } catch {
                    XCTFail("Catalog decode failed during performance measurement: \(error)")
                    return
                }
            }
        }
    }

    func testMatchingEnginePerformance() throws {
        let resourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Offset/Resources/programs.json")
        let programs = try ProgramStore.decodeCatalog(from: Data(contentsOf: resourceURL)).programs
        let profile = UserProfile(
            zipCode: "02108",
            state: "MA",
            utilityProvider: "national-grid-ma",
            isHomeowner: true,
            selectedProjects: ProjectType.allCases
        )
        let engine = MatchingEngine(programs: programs)

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            for _ in 0..<5_000 {
                for project in ProjectType.allCases {
                    _ = engine.matches(for: profile, project: project, stickerPriceUSD: 20_000, hasPremiumAccess: true)
                }
            }
        }
    }
}
