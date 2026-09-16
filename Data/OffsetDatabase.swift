import Foundation
import SQLite3

public struct OffsetProgram: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let stateCode: String?
    public let utilityID: String?
    public let status: String
    public let verificationStatus: String
    public let incentiveType: String
    public let amountType: String
    public let amountMin: Double?
    public let amountMax: Double?
    public let amountFormula: String?
    public let description: String
    public let claimTiming: String?
    public let requiresPreapproval: Bool
    public let requiresContractor: Bool
    public let sourceURL: URL?
    public let lastVerifiedAt: String?
}

public struct OffsetEligibilityRule: Sendable {
    public let field: String
    public let op: String
    public let valueJSON: String
    public let description: String
    public let blocking: Bool
}

public struct OffsetIncentiveTier: Sendable {
    public let key: String
    public let conditionsJSON: String
    public let amount: Double?
    public let unit: String?
    public let cap: Double?
    public let description: String
}

public struct OffsetClaimStep: Sendable {
    public let order: Int
    public let phase: String
    public let title: String
    public let description: String
    public let blocking: Bool
}

public struct OffsetProgramDetail: Sendable {
    public let program: OffsetProgram
    public let rules: [OffsetEligibilityRule]
    public let tiers: [OffsetIncentiveTier]
    public let steps: [OffsetClaimStep]
}

public enum OffsetDatabaseError: Error {
    case databaseMissing
    case openFailed(String)
    case queryFailed(String)
}

public final class OffsetDatabase: @unchecked Sendable {
    private var db: OpaquePointer?

    /// Bundle `offset_incentives.sqlite` into the app target before calling this initializer.
    public init(bundle: Bundle = .main, resource: String = "offset_incentives", extension ext: String = "sqlite") throws {
        guard let path = bundle.path(forResource: resource, ofType: ext) else {
            throw OffsetDatabaseError.databaseMissing
        }
        let result = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
        guard result == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            sqlite3_close(db)
            db = nil
            throw OffsetDatabaseError.openFailed(message)
        }
    }

    deinit { sqlite3_close(db) }

    /// Returns verified candidate programs for a state/category.
    /// Statewide programs have `utility_id = NULL`; utility programs are included when utilityID matches.
    public func programs(state: String, category: String, utilityID: String? = nil) throws -> [OffsetProgram] {
        let sql = """
        SELECT p.id,p.name,p.state_code,p.utility_id,p.status,p.verification_status,
               p.incentive_type,p.amount_type,p.amount_min,p.amount_max,p.amount_formula,
               p.description,p.claim_timing,p.requires_preapproval,p.requires_contractor,
               p.source_url,p.last_verified_at
        FROM active_match_programs p
        JOIN program_categories pc ON pc.program_id = p.id
        WHERE pc.category_id = ?1
          AND p.state_code = ?2
          AND (p.utility_id IS NULL OR p.utility_id = ?3)
        ORDER BY CASE WHEN p.utility_id IS NULL THEN 0 ELSE 1 END, p.name;
        """
        return try queryPrograms(sql: sql, bindings: [category, state, utilityID ?? ""])
    }

    /// Programs that are known but intentionally excluded from automatic savings totals.
    public func reviewQueue(state: String? = nil) throws -> [OffsetProgram] {
        let sql: String
        let bindings: [String]
        if let state {
            sql = """
            SELECT p.id,p.name,p.state_code,p.utility_id,p.status,p.verification_status,
                   p.incentive_type,p.amount_type,p.amount_min,p.amount_max,p.amount_formula,
                   p.description,p.claim_timing,p.requires_preapproval,p.requires_contractor,
                   p.source_url,p.last_verified_at
            FROM programs p
            WHERE p.state_code = ?1 AND (p.match_enabled = 0 OR p.verification_status IN ('needs_reverify','discovery_only'))
            ORDER BY p.name;
            """
            bindings = [state]
        } else {
            sql = """
            SELECT p.id,p.name,p.state_code,p.utility_id,p.status,p.verification_status,
                   p.incentive_type,p.amount_type,p.amount_min,p.amount_max,p.amount_formula,
                   p.description,p.claim_timing,p.requires_preapproval,p.requires_contractor,
                   p.source_url,p.last_verified_at
            FROM programs p
            WHERE p.match_enabled = 0 OR p.verification_status IN ('needs_reverify','discovery_only')
            ORDER BY p.state_code,p.name;
            """
            bindings = []
        }
        return try queryPrograms(sql: sql, bindings: bindings)
    }

    public func detail(programID: String) throws -> OffsetProgramDetail? {
        let psql = """
        SELECT p.id,p.name,p.state_code,p.utility_id,p.status,p.verification_status,
               p.incentive_type,p.amount_type,p.amount_min,p.amount_max,p.amount_formula,
               p.description,p.claim_timing,p.requires_preapproval,p.requires_contractor,
               p.source_url,p.last_verified_at
        FROM programs p WHERE p.id = ?1 LIMIT 1;
        """
        guard let program = try queryPrograms(sql: psql, bindings: [programID]).first else { return nil }
        return OffsetProgramDetail(
            program: program,
            rules: try eligibilityRules(programID: programID),
            tiers: try incentiveTiers(programID: programID),
            steps: try claimSteps(programID: programID)
        )
    }

    private func eligibilityRules(programID: String) throws -> [OffsetEligibilityRule] {
        let sql = "SELECT field,operator,value_json,description,blocking FROM eligibility_rules WHERE program_id=?1 ORDER BY id;"
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        bind(programID, index: 1, stmt: stmt)
        var out: [OffsetEligibilityRule] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(.init(field: text(stmt,0) ?? "", op: text(stmt,1) ?? "", valueJSON: text(stmt,2) ?? "null", description: text(stmt,3) ?? "", blocking: sqlite3_column_int(stmt,4) != 0))
        }
        return out
    }

    private func incentiveTiers(programID: String) throws -> [OffsetIncentiveTier] {
        let sql = "SELECT tier_key,conditions_json,amount,unit,cap,description FROM incentive_tiers WHERE program_id=?1 ORDER BY id;"
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        bind(programID, index: 1, stmt: stmt)
        var out: [OffsetIncentiveTier] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(.init(key: text(stmt,0) ?? "", conditionsJSON: text(stmt,1) ?? "{}", amount: nullableDouble(stmt,2), unit: text(stmt,3), cap: nullableDouble(stmt,4), description: text(stmt,5) ?? ""))
        }
        return out
    }

    private func claimSteps(programID: String) throws -> [OffsetClaimStep] {
        let sql = "SELECT step_order,phase,title,description,blocking FROM claim_steps WHERE program_id=?1 ORDER BY step_order;"
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        bind(programID, index: 1, stmt: stmt)
        var out: [OffsetClaimStep] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(.init(order: Int(sqlite3_column_int(stmt,0)), phase: text(stmt,1) ?? "", title: text(stmt,2) ?? "", description: text(stmt,3) ?? "", blocking: sqlite3_column_int(stmt,4) != 0))
        }
        return out
    }

    private func queryPrograms(sql: String, bindings: [String]) throws -> [OffsetProgram] {
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        for (i, value) in bindings.enumerated() { bind(value, index: Int32(i+1), stmt: stmt) }
        var output: [OffsetProgram] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw OffsetDatabaseError.queryFailed(errorMessage()) }
            output.append(.init(
                id: text(stmt,0) ?? "",
                name: text(stmt,1) ?? "",
                stateCode: text(stmt,2),
                utilityID: text(stmt,3),
                status: text(stmt,4) ?? "",
                verificationStatus: text(stmt,5) ?? "",
                incentiveType: text(stmt,6) ?? "",
                amountType: text(stmt,7) ?? "",
                amountMin: nullableDouble(stmt,8),
                amountMax: nullableDouble(stmt,9),
                amountFormula: text(stmt,10),
                description: text(stmt,11) ?? "",
                claimTiming: text(stmt,12),
                requiresPreapproval: sqlite3_column_int(stmt,13) != 0,
                requiresContractor: sqlite3_column_int(stmt,14) != 0,
                sourceURL: text(stmt,15).flatMap(URL.init(string:)),
                lastVerifiedAt: text(stmt,16)
            ))
        }
        return output
    }

    private func prepare(_ sql: String, _ stmt: inout OpaquePointer?) throws {
        guard let db else { throw OffsetDatabaseError.openFailed("Database is closed") }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw OffsetDatabaseError.queryFailed(errorMessage())
        }
    }

    private func bind(_ value: String, index: Int32, stmt: OpaquePointer?) {
        sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
    }

    private func text(_ stmt: OpaquePointer?, _ column: Int32) -> String? {
        guard sqlite3_column_type(stmt, column) != SQLITE_NULL,
              let c = sqlite3_column_text(stmt, column) else { return nil }
        return String(cString: c)
    }

    private func nullableDouble(_ stmt: OpaquePointer?, _ column: Int32) -> Double? {
        sqlite3_column_type(stmt, column) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, column)
    }

    private func errorMessage() -> String {
        guard let db else { return "Database is closed" }
        return String(cString: sqlite3_errmsg(db))
    }
}
