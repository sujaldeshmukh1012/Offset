import Foundation

struct ProgramStackingRule: Equatable, Sendable {
    let programA: String
    let programB: String
    let relationship: String
    let notes: String?
    let isVerified: Bool
}

struct ProgramStackingPolicy: Sendable {
    let rules: [ProgramStackingRule]

    static func bundled() -> Self {
        guard let dataset = try? IncentiveDatasetStore.loadBundled() else { return Self(rules: []) }
        return Self(rules: dataset.stackingRules.map {
            ProgramStackingRule(
                programA: $0.programA,
                programB: $0.programB,
                relationship: $0.relationship,
                notes: $0.notes,
                isVerified: $0.verified == 1
            )
        })
    }

    func resolvingConflicts(
        in programs: [Program],
        standaloneSavings: (Program) -> Double
    ) -> [Program] {
        let ranked = programs.sorted { lhs, rhs in
            let left = standaloneSavings(lhs)
            let right = standaloneSavings(rhs)
            if left != right { return left > right }
            return lhs.id < rhs.id
        }
        var accepted: [Program] = []
        for program in ranked where !accepted.contains(where: { conflicts(program, $0) }) {
            accepted.append(program)
        }
        return accepted
    }

    func ordered(_ programs: [Program], fallback: (Program, Program) -> Bool) -> [Program] {
        let baseline = programs.sorted(by: fallback)
        let baselineIndex = Dictionary(uniqueKeysWithValues: baseline.enumerated().map { ($0.element.id, $0.offset) })
        var outgoing = Dictionary(uniqueKeysWithValues: baseline.map { ($0.id, Set<String>()) })
        var indegree = Dictionary(uniqueKeysWithValues: baseline.map { ($0.id, 0) })

        for rule in rules where rule.isVerified && ["applies_before", "applies_after"].contains(rule.relationship) {
            guard let a = baseline.first(where: { sourceID($0.id) == rule.programA }),
                  let b = baseline.first(where: { sourceID($0.id) == rule.programB }) else { continue }
            let before = rule.relationship == "applies_before" ? a : b
            let after = rule.relationship == "applies_before" ? b : a
            if outgoing[before.id]?.insert(after.id).inserted == true {
                indegree[after.id, default: 0] += 1
            }
        }

        var available = baseline.filter { indegree[$0.id] == 0 }
        var result: [Program] = []
        while !available.isEmpty {
            available.sort { baselineIndex[$0.id, default: 0] < baselineIndex[$1.id, default: 0] }
            let next = available.removeFirst()
            result.append(next)
            for target in outgoing[next.id] ?? [] {
                indegree[target, default: 0] -= 1
                if indegree[target] == 0, let program = baseline.first(where: { $0.id == target }) {
                    available.append(program)
                }
            }
        }

        // A malformed future cycle must not make programs disappear; validation and tests flag it,
        // while the deterministic baseline remains the safe runtime fallback.
        return result.count == baseline.count ? result : baseline
    }

    private func conflicts(_ lhs: Program, _ rhs: Program) -> Bool {
        guard let rule = rule(between: lhs, and: rhs) else { return false }
        switch rule.relationship {
        case "exclusive", "mutually_exclusive", "not_stackable": return true
        case "may_stack": return !rule.isVerified
        case "conditional": return !rule.isVerified
        default: return false
        }
    }

    private func rule(between lhs: Program, and rhs: Program) -> ProgramStackingRule? {
        let left = sourceID(lhs.id)
        let right = sourceID(rhs.id)
        return rules.first {
            ($0.programA == left && $0.programB == right) || ($0.programA == right && $0.programB == left)
        }
    }

    private func sourceID(_ appProgramID: String) -> String {
        appProgramID.split(separator: "-", maxSplits: 1).first.map(String.init) ?? appProgramID
    }
}
