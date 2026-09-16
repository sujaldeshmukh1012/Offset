import Foundation

struct ProjectExperienceService: Sendable {
    struct ChecklistGroup: Identifiable, Equatable, Sendable {
        let match: MatchResult

        var id: String { match.program.id }
        var program: Program { match.program }
        var steps: [String] { match.program.claimSteps }
    }

    let programs: [Program]
    let referenceDate: Date

    init(programs: [Program], referenceDate: Date = Date()) {
        self.programs = programs
        self.referenceDate = referenceDate
    }

    static func bundled(profile: UserProfile? = nil, referenceDate: Date = Date()) throws -> Self {
        Self(programs: try ProgramStore.loadBundledPrograms(profile: profile), referenceDate: referenceDate)
    }

    func matches(for project: SavedProject, profile: UserProfile) -> [MatchResult] {
        MatchingEngine(programs: programs, referenceDate: referenceDate).matches(
            for: profile,
            project: project.projectType,
            stickerPriceUSD: project.stickerPriceUSD,
            hasPremiumAccess: true
        )
    }

    func checklistGroups(for project: SavedProject, profile: UserProfile) -> [ChecklistGroup] {
        matches(for: project, profile: profile).map(ChecklistGroup.init(match:))
    }

    func relatedPrograms(for projectType: ProjectType) -> [Program] {
        programs
            .filter { $0.projectTypes.contains(projectType) }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status { return statusOrder(lhs.status) < statusOrder(rhs.status) }
                if lhs.level != rhs.level { return levelOrder(lhs.level) < levelOrder(rhs.level) }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func statusOrder(_ status: ProgramStatus) -> Int {
        switch status {
        case .active: 0
        case .dynamic: 1
        case .waitlist: 2
        case .discovery: 3
        case .paused: 4
        case .closed: 5
        }
    }

    private func levelOrder(_ level: ProgramLevel) -> Int {
        switch level {
        case .utility: 0
        case .state: 1
        case .regional: 2
        case .local: 3
        case .federal: 4
        }
    }
}
