import Foundation

struct MatchingEngine: Sendable {
    private let programs: [Program]
    private let referenceDate: Date
    private let stackingPolicy: ProgramStackingPolicy

    init(
        programs: [Program],
        referenceDate: Date = Date(),
        stackingPolicy: ProgramStackingPolicy = .bundled()
    ) {
        self.programs = programs
        self.referenceDate = referenceDate
        self.stackingPolicy = stackingPolicy
    }

    func matches(
        for profile: UserProfile,
        project: ProjectType,
        stickerPriceUSD: Double,
        hasPremiumAccess: Bool = false
    ) -> [MatchResult] {
        let startingPrice = max(0, stickerPriceUSD)
        var runningPrice = startingPrice

        let candidates = programs
            .filter(isAvailable)
            .filter { $0.projectTypes.contains(project) }
            .filter { isGeographicallyEligible($0, profile: profile) }
            .filter { isOccupancyEligible($0, profile: profile) }
            .filter { isIncomeEligible($0, profile: profile) }
            .filter { isVehicleEligible($0, profile: profile, stickerPriceUSD: startingPrice) }
        let compatible = stackingPolicy.resolvingConflicts(in: candidates) {
            savings(for: $0.amountType, basePrice: startingPrice)
        }
        let ordered = stackingPolicy.ordered(compatible, fallback: appliesBefore)

        return ordered
            .map { program in
                let savings = min(runningPrice, savings(for: program.amountType, basePrice: runningPrice))
                let priceBefore = runningPrice
                runningPrice = max(0, runningPrice - savings)

                return MatchResult(
                    program: program,
                    estimatedSavingsUSD: savings,
                    priceBeforeUSD: priceBefore,
                    priceAfterUSD: runningPrice,
                    isLocked: !hasPremiumAccess && program.level != .federal
                )
            }
    }

    private func isAvailable(_ program: Program) -> Bool {
        guard program.status == .active, program.effectiveDate <= referenceDate else { return false }
        guard let deadline = program.deadline else { return true }
        return referenceDate <= deadline
    }

    private func isGeographicallyEligible(_ program: Program, profile: UserProfile) -> Bool {
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

    private func isOccupancyEligible(_ program: Program, profile: UserProfile) -> Bool {
        guard !program.eligibleHomeOccupancies.isEmpty else { return true }
        let occupancy: HomeOccupancy = profile.isHomeowner
            ? .homeownerPrimaryResidence
            : .renterPrimaryResidence
        return program.eligibleHomeOccupancies.contains(occupancy)
    }

    private func isIncomeEligible(_ program: Program, profile: UserProfile) -> Bool {
        guard !program.incomeCapsUSD.isEmpty, let income = profile.annualIncomeUSD else { return true }
        guard let filingStatus = profile.filingStatus,
              let cap = program.incomeCapsUSD[filingStatus] else { return false }
        return income <= cap
    }

    private func isVehicleEligible(
        _ program: Program,
        profile: UserProfile,
        stickerPriceUSD: Double
    ) -> Bool {
        if !program.eligibleVehicleConditions.isEmpty {
            guard let condition = profile.vehicleCondition,
                  program.eligibleVehicleConditions.contains(condition) else { return false }
        }
        if !program.vehiclePriceCapsUSD.isEmpty {
            guard let category = profile.vehicleCategory,
                  let cap = program.vehiclePriceCapsUSD[category] else { return false }
            return stickerPriceUSD <= cap
        }
        return true
    }

    private func savings(for amount: AmountType, basePrice: Double) -> Double {
        switch amount {
        case .percentage(let percentage):
            return basePrice * normalized(percentage)
        case .fixedAmount(let amount):
            return max(0, amount)
        case .upTo(let cap, let percentage):
            return min(max(0, cap), basePrice * normalized(percentage))
        case .range, .formula, .taxBenefit, .nonCash, .unknown:
            return 0
        }
    }

    private func normalized(_ percentage: Double) -> Double {
        min(max(percentage > 1 ? percentage / 100 : percentage, 0), 1)
    }

    private func appliesBefore(_ lhs: Program, _ rhs: Program) -> Bool {
        let left = sortKey(for: lhs)
        let right = sortKey(for: rhs)
        return left == right ? lhs.id < rhs.id : left < right
    }

    private func sortKey(for program: Program) -> Int {
        if program.level == .utility { return 0 }

        let levelOffset = program.level == .state ? 0 : (program.level == .federal ? 1 : 2)
        switch program.amountType {
        case .percentage, .upTo:
            return 10 + levelOffset
        case .fixedAmount:
            return 20 + levelOffset
        case .range, .formula, .taxBenefit, .nonCash, .unknown:
            return 30 + levelOffset
        }
    }
}
