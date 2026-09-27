import Foundation

@MainActor
final class ProjectPricerViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case results
        case noMatches
        case incompleteProfile(String)
        case invalidPrice(String)
        case dataFailure(String)
    }

    enum ResultRow: Identifiable, Equatable {
        case exact(ExactResultRow)
        case locked(id: String, level: ProgramLevel)

        var id: String {
            switch self {
            case .exact(let row): row.id
            case .locked(let id, _): "locked-\(id)"
            }
        }
    }

    struct ExactResultRow: Identifiable, Equatable {
        let id: String
        let program: Program
        let programName: String
        let level: ProgramLevel
        let savingsUSD: Double
        let priceBeforeUSD: Double
        let priceAfterUSD: Double
    }

    @Published var selectedProject: ProjectType?
    @Published private(set) var priceText = ""
    @Published private(set) var status: Status
    @Published private(set) var rows: [ResultRow] = []
    @Published private(set) var stickerPriceUSD: Double = 0
    @Published private(set) var visibleSavingsUSD: Double = 0
    @Published private(set) var visibleNetPriceUSD: Double = 0
    @Published private(set) var hasLockedMatches = false
    @Published private(set) var calculationID = UUID()

    private let loadPrograms: () throws -> [Program]
    private let loadProgramsForProfile: (UserProfile?) throws -> [Program]
    private let referenceDate: Date
    private var programs: [Program] = []
    private var programsLoaded = false

    init(
        selectedProject: ProjectType? = nil,
        referenceDate: Date = Date()
    ) {
        self.selectedProject = selectedProject
        self.referenceDate = referenceDate
        self.loadPrograms = { try ProgramStore.loadCurrentPrograms() }
        self.loadProgramsForProfile = { try ProgramStore.loadCurrentPrograms(profile: $0) }
        self.status = .idle
        reloadPrograms()
    }

    init(
        selectedProject: ProjectType? = nil,
        referenceDate: Date = Date(),
        loadPrograms: @escaping () throws -> [Program]
    ) {
        self.selectedProject = selectedProject
        self.referenceDate = referenceDate
        self.loadPrograms = loadPrograms
        self.loadProgramsForProfile = { _ in try loadPrograms() }
        self.status = .idle
        reloadPrograms()
    }

    func setPriceText(_ input: String) {
        priceText = Self.sanitizedCurrencyInput(input)
        if case .invalidPrice = status { status = .idle }
    }

    func invalidateResults() {
        guard programsLoaded else { return }
        status = .idle
        rows = []
        hasLockedMatches = false
    }

    func reloadPrograms() {
        do {
            programs = try loadPrograms()
            programsLoaded = true
            status = .idle
        } catch {
            programs = []
            programsLoaded = false
            status = .dataFailure("Offset couldn't load its verified incentive data.")
        }
    }

    func calculate(profile: UserProfile?, hasPremiumAccess: Bool) {
        guard programsLoaded else {
            status = .dataFailure("Offset couldn't load its verified incentive data.")
            return
        }
        guard let profile,
              profile.zipCode.count == 5,
              profile.state.count == 2 else {
            status = .incompleteProfile("Finish your ZIP code and home profile before calculating incentives.")
            return
        }
        do {
            programs = try loadProgramsForProfile(profile)
            programsLoaded = true
        } catch {
            programs = []
            programsLoaded = false
            status = .dataFailure("Offset couldn't load its verified incentive data.")
            return
        }
        guard let selectedProject else {
            status = .incompleteProfile("Choose a project to calculate its price.")
            return
        }
        guard let price = Self.price(from: priceText), price > 0 else {
            status = .invalidPrice(priceText.isEmpty ? "Enter a sticker price." : "Enter a price greater than $0.")
            return
        }
        guard price < 10_000_000 else {
            status = .invalidPrice("Enter a sticker price below $10,000,000.")
            return
        }

        let completeMatches = MatchingEngine(programs: programs, referenceDate: referenceDate).matches(
            for: profile,
            project: selectedProject,
            stickerPriceUSD: price,
            hasPremiumAccess: true
        )

        stickerPriceUSD = price
        hasLockedMatches = !hasPremiumAccess && completeMatches.contains { $0.program.level != .federal }

        if hasPremiumAccess {
            rows = completeMatches.map { .exact(Self.exactRow(from: $0)) }
            visibleSavingsUSD = completeMatches.reduce(0) { $0 + $1.estimatedSavingsUSD }
            visibleNetPriceUSD = completeMatches.last?.priceAfterUSD ?? price
        } else {
            let federalMatches = MatchingEngine(
                programs: programs.filter { $0.level == .federal },
                referenceDate: referenceDate
            ).matches(
                for: profile,
                project: selectedProject,
                stickerPriceUSD: price,
                hasPremiumAccess: true
            )
            let federalByID = Dictionary(uniqueKeysWithValues: federalMatches.map { ($0.program.id, $0) })

            rows = completeMatches.compactMap { match in
                if match.program.level == .federal, let publicMatch = federalByID[match.program.id] {
                    return .exact(Self.exactRow(from: publicMatch))
                }
                return .locked(id: match.program.id, level: match.program.level)
            }
            visibleSavingsUSD = federalMatches.reduce(0) { $0 + $1.estimatedSavingsUSD }
            visibleNetPriceUSD = federalMatches.last?.priceAfterUSD ?? price
        }

        status = completeMatches.isEmpty ? .noMatches : .results
        calculationID = UUID()
    }

    func formatPriceForEditingEnd() {
        guard let price = Self.price(from: priceText) else { return }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        priceText = formatter.string(from: NSNumber(value: price)) ?? priceText
    }

    static func sanitizedCurrencyInput(_ input: String) -> String {
        var output = ""
        var foundDecimal = false
        var fractionDigits = 0

        for character in input {
            if character.isNumber {
                if foundDecimal {
                    guard fractionDigits < 2 else { continue }
                    fractionDigits += 1
                }
                output.append(character)
            } else if character == ".", !foundDecimal {
                foundDecimal = true
                output.append(character)
            }
        }
        return output
    }

    static func price(from input: String) -> Double? {
        guard !input.isEmpty,
              let decimal = Decimal(string: input, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        let value = NSDecimalNumber(decimal: decimal).doubleValue
        return value.isFinite ? value : nil
    }

    private static func exactRow(from result: MatchResult) -> ExactResultRow {
        ExactResultRow(
            id: result.program.id,
            program: result.program,
            programName: result.program.name,
            level: result.program.level,
            savingsUSD: result.estimatedSavingsUSD,
            priceBeforeUSD: result.priceBeforeUSD,
            priceAfterUSD: result.priceAfterUSD
        )
    }
}
