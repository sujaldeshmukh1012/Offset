import Foundation

struct DiscoveredOpportunity: Identifiable, Equatable, Sendable {
    let project: ProjectType
    let programs: [Program]
    let sourceLevels: [ProgramLevel]
    let coverage: CoverageAssessment
    let questions: [EligibilityQuestion]
    let answeredQuestionCount: Int
    let hasExactProgram: Bool

    var id: ProjectType { project }
    var programCount: Int { programs.count }
    var remainingQuestionCount: Int { max(0, questions.count - answeredQuestionCount) }
}

struct OpportunityDiscoverySnapshot: Equatable, Sendable {
    let opportunities: [DiscoveredOpportunity]
    let programCountsByLevel: [ProgramLevel: Int]
    let errorMessage: String?

    static let empty = OpportunityDiscoverySnapshot(
        opportunities: [],
        programCountsByLevel: [:],
        errorMessage: nil
    )

    var totalProgramCount: Int {
        Set(opportunities.flatMap(\.programs).map { "\($0.name)|\($0.sourceURL)" }).count
    }
}

enum OpportunityDiscoveryService {
    static func currentSnapshot(for profile: UserProfile) -> OpportunityDiscoverySnapshot {
        do {
            let dataset = try IncentiveDatasetStore.loadCurrent()
            let programs = IncentiveDatasetStore.appPrograms(from: dataset, profile: profile)
            return snapshot(for: profile, programs: programs, dataset: dataset)
        } catch {
            return OpportunityDiscoverySnapshot(
                opportunities: [],
                programCountsByLevel: [:],
                errorMessage: "Offset couldn’t load its verified opportunity catalog."
            )
        }
    }

    static func bundledSnapshot(for profile: UserProfile) -> OpportunityDiscoverySnapshot {
        do {
            let programs = try ProgramStore.loadBundledPrograms(profile: profile)
            return snapshot(for: profile, programs: programs)
        } catch {
            return OpportunityDiscoverySnapshot(
                opportunities: [],
                programCountsByLevel: [:],
                errorMessage: "Offset couldn’t load its verified opportunity catalog."
            )
        }
    }

    static func snapshot(
        for profile: UserProfile,
        programs: [Program],
        dataset: IncentiveDataset? = nil
    ) -> OpportunityDiscoverySnapshot {
        let opportunities = ProjectType.allCases.compactMap { project -> DiscoveredOpportunity? in
            let relevant = programs.filter {
                $0.projectTypes.contains(project)
                    && isDiscoverable($0)
                    && isGeographicallyAvailable($0, profile: profile)
                    && isOccupancyCompatible($0, profile: profile)
            }
            guard !relevant.isEmpty else { return nil }

            let questions = dataset.map {
                EligibilityQuestionService.questions(for: project, profile: profile, dataset: $0)
            } ?? EligibilityQuestionService.bundledQuestions(for: project, profile: profile)
            let answered = questions.filter {
                EligibilityQuestionService.answer(for: $0.id, in: profile) != nil
            }.count
            let sourceLevels = Array(Set(relevant.map(\.level))).sorted { levelRank($0) < levelRank($1) }

            return DiscoveredOpportunity(
                project: project,
                programs: relevant,
                sourceLevels: sourceLevels,
                coverage: dataset.map {
                    CoverageService.assessment(for: project, profile: profile, dataset: $0)
                } ?? CoverageService.bundledAssessment(for: project, profile: profile),
                questions: questions,
                answeredQuestionCount: answered,
                hasExactProgram: relevant.contains { $0.status == .active && $0.amountType.isExactForDiscovery }
            )
        }
        .sorted { lhs, rhs in
            let leftSelected = profile.selectedProjects.contains(lhs.project)
            let rightSelected = profile.selectedProjects.contains(rhs.project)
            if leftSelected != rightSelected { return leftSelected }
            if lhs.programCount != rhs.programCount { return lhs.programCount > rhs.programCount }
            if lhs.coverage.confidence != rhs.coverage.confidence {
                return lhs.coverage.confidence.rawValue > rhs.coverage.confidence.rawValue
            }
            return lhs.project.displayName < rhs.project.displayName
        }

        let uniquePrograms = Dictionary(
            opportunities.flatMap(\.programs).map { ("\($0.name)|\($0.sourceURL)", $0) },
            uniquingKeysWith: { first, _ in first }
        ).values
        let counts = Dictionary(grouping: uniquePrograms, by: \.level).mapValues(\.count)

        return OpportunityDiscoverySnapshot(
            opportunities: opportunities,
            programCountsByLevel: counts,
            errorMessage: nil
        )
    }

    private static func isDiscoverable(_ program: Program) -> Bool {
        ![.closed, .paused].contains(program.status)
    }

    private static func isGeographicallyAvailable(_ program: Program, profile: UserProfile) -> Bool {
        switch program.level {
        case .federal:
            return true
        case .state, .regional, .local:
            return program.eligibilityStates.contains(profile.state.uppercased())
        case .utility:
            guard let utility = profile.utilityProvider else { return false }
            let stateMatches = program.eligibilityStates.isEmpty
                || program.eligibilityStates.contains(profile.state.uppercased())
            return stateMatches && program.eligibilityUtilities.contains(utility)
        }
    }

    private static func isOccupancyCompatible(_ program: Program, profile: UserProfile) -> Bool {
        guard !program.eligibleHomeOccupancies.isEmpty else { return true }
        let occupancy: HomeOccupancy = profile.isHomeowner
            ? .homeownerPrimaryResidence
            : .renterPrimaryResidence
        return program.eligibleHomeOccupancies.contains(occupancy)
    }

    private static func levelRank(_ level: ProgramLevel) -> Int {
        switch level {
        case .federal: 0
        case .state: 1
        case .utility: 2
        case .regional: 3
        case .local: 4
        }
    }
}

private extension AmountType {
    var isExactForDiscovery: Bool {
        switch self {
        case .percentage, .fixedAmount, .upTo: true
        case .range, .formula, .taxBenefit, .nonCash, .unknown: false
        }
    }
}
