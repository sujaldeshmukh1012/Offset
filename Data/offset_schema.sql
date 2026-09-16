
PRAGMA foreign_keys = ON;

CREATE TABLE meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE states (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  coverage_status TEXT NOT NULL CHECK (coverage_status IN ('verified_major_territories','partial','discovery_only')),
  notes TEXT
);

CREATE TABLE utilities (
  id TEXT PRIMARY KEY,
  state_code TEXT NOT NULL REFERENCES states(code),
  name TEXT NOT NULL,
  utility_type TEXT NOT NULL,
  domain TEXT,
  supported INTEGER NOT NULL DEFAULT 0 CHECK (supported IN (0,1)),
  notes TEXT
);

CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE sources (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  authority_tier INTEGER NOT NULL CHECK (authority_tier BETWEEN 0 AND 3),
  source_type TEXT NOT NULL,
  state_code TEXT REFERENCES states(code),
  utility_id TEXT REFERENCES utilities(id),
  trust_status TEXT NOT NULL CHECK (trust_status IN ('primary','official_aggregator','secondary_discovery','deprecated','unreliable')),
  notes TEXT
);

CREATE TABLE programs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  jurisdiction_level TEXT NOT NULL CHECK (jurisdiction_level IN ('federal','state','utility','regional','local')),
  state_code TEXT REFERENCES states(code),
  utility_id TEXT REFERENCES utilities(id),
  administrator TEXT,
  incentive_type TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active','dynamic','waitlist','expired','unknown','discovery_only')),
  publishable INTEGER NOT NULL DEFAULT 0 CHECK (publishable IN (0,1)),
  match_enabled INTEGER NOT NULL DEFAULT 0 CHECK (match_enabled IN (0,1)),
  verification_status TEXT NOT NULL CHECK (verification_status IN ('primary_verified','primary_verified_dynamic','needs_reverify','discovery_only')),
  effective_start TEXT,
  effective_end TEXT,
  last_verified_at TEXT,
  amount_type TEXT NOT NULL CHECK (amount_type IN ('flat','tiered','percent','formula','tax_exemption','property_tax_exclusion','noncash','unknown')),
  amount_min REAL,
  amount_max REAL,
  amount_unit TEXT,
  amount_formula TEXT,
  description TEXT NOT NULL,
  claim_timing TEXT,
  requires_preapproval INTEGER NOT NULL DEFAULT 0 CHECK (requires_preapproval IN (0,1)),
  requires_contractor INTEGER NOT NULL DEFAULT 0 CHECK (requires_contractor IN (0,1)),
  source_id TEXT REFERENCES sources(id),
  source_url TEXT NOT NULL,
  notes TEXT
);

CREATE TABLE program_categories (
  program_id TEXT NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
  category_id TEXT NOT NULL REFERENCES categories(id),
  PRIMARY KEY (program_id, category_id)
);

CREATE TABLE eligibility_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  program_id TEXT NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
  field TEXT NOT NULL,
  operator TEXT NOT NULL,
  value_json TEXT NOT NULL,
  description TEXT NOT NULL,
  blocking INTEGER NOT NULL DEFAULT 1 CHECK (blocking IN (0,1))
);

CREATE TABLE incentive_tiers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  program_id TEXT NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
  tier_key TEXT NOT NULL,
  conditions_json TEXT NOT NULL,
  amount REAL,
  unit TEXT,
  cap REAL,
  description TEXT NOT NULL
);

CREATE TABLE claim_steps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  program_id TEXT NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
  step_order INTEGER NOT NULL,
  phase TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  blocking INTEGER NOT NULL DEFAULT 0 CHECK (blocking IN (0,1)),
  UNIQUE(program_id, step_order)
);

CREATE TABLE stacking_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  program_a TEXT NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
  program_b TEXT NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
  relationship TEXT NOT NULL CHECK (relationship IN ('stackable','not_stackable','may_stack','reduces_basis','conditional','unknown')),
  notes TEXT,
  verified INTEGER NOT NULL DEFAULT 0 CHECK (verified IN (0,1)),
  UNIQUE(program_a, program_b)
);

CREATE TABLE coverage (
  state_code TEXT NOT NULL REFERENCES states(code),
  utility_id TEXT REFERENCES utilities(id),
  category_id TEXT NOT NULL REFERENCES categories(id),
  status TEXT NOT NULL CHECK (status IN ('verified','verified_dynamic','partial','unsupported','discovery_only')),
  notes TEXT,
  PRIMARY KEY (state_code, utility_id, category_id)
);

CREATE INDEX idx_programs_geo ON programs(state_code, utility_id, status, match_enabled);
CREATE INDEX idx_programs_verify ON programs(verification_status, publishable);
CREATE INDEX idx_program_categories_category ON program_categories(category_id, program_id);
CREATE INDEX idx_eligibility_program ON eligibility_rules(program_id);
CREATE INDEX idx_tiers_program ON incentive_tiers(program_id);
CREATE INDEX idx_sources_geo ON sources(state_code, utility_id, trust_status);

CREATE VIEW active_match_programs AS
SELECT p.*
FROM programs p
WHERE p.publishable = 1 AND p.match_enabled = 1 AND p.status IN ('active','dynamic');

CREATE VIEW review_queue AS
SELECT p.id, p.name, p.state_code, p.utility_id, p.status, p.verification_status, p.last_verified_at, p.source_url
FROM programs p
WHERE p.match_enabled = 0 OR p.verification_status IN ('needs_reverify','discovery_only');
