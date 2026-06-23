# Pattern Catalog — `jjj/dash-api` (read-only analysis)

**Generated:** 2026-06-23 · Task (B), one-time setup · advisory only.
**Source repo:** `/Users/yaroslavlebedevich/Projects/jjj/dash-api` (READ-ONLY — not modified).
**Primary source:** `db/schema.rb` (6,352 lines, 388 `create_table`, 408 `add_foreign_key`).
**Secondary source:** `app/models/*.rb` (92 model files, many with nested namespaced models).

Verdict tags: ✅ **sound** · ⚠️ **stylistic** (your call) · 🛑 **integrity-risk** (excluded from baseline).

Quantities are grep-derived from `db/schema.rb` unless noted. "Tables" = `create_table` blocks
(388), which exceeds model files (92) because many models are namespaced submodules and many
tables are join/lookup tables.

---

## 1. Primary keys & identifiers

### 1a. UUID primary keys (default) — ✅ sound
- **What:** Nearly all tables use `id: :uuid, default: -> { "public.gen_random_uuid()" }`.
- **Where:** 323 of 388 tables. The dominant convention.
- **Pros:** Non-enumerable, merge-safe across environments/shards, safe to expose in URLs/APIs,
  generable client-side. Consistent across the modern codebase.
- **Cons:** 16 bytes vs 8; slightly larger indexes; random UUIDv4 hurts index locality (no UUIDv7).
- **Verdict:** ✅ sound — and a deliberate house standard worth continuing.

### 1b. Legacy `serial`/`bigint` integer PKs — ⚠️ stylistic
- **What:** A handful of older tables use `id: :serial` (e.g. `admin_action_reasons`) or bigint.
- **Where:** ~8 tables (`id: false`=8; `id: :serial`×2; `t.bigint`=73 columns but mostly FKs).
- **Verdict:** ⚠️ stylistic — legacy holdouts. New work should follow the UUID standard (1a).

---

## 2. Inheritance (STI / polymorphic / MTI)

### 2a. Single-Table Inheritance (STI) — ⚠️ stylistic (used sparingly)
- **What:** `t.string "type"` discriminator columns for Rails STI.
- **Where:** ~5 tables (lines 323, 2748, 3938, 4545, 4590). Not a dominant pattern.
- **Pros:** Simple for small closed hierarchies sharing most columns.
- **Cons:** Wide sparse tables and nullable subtype columns if hierarchies diverge.
- **Verdict:** ⚠️ stylistic — fine where used; not over-applied here.

### 2b. Polymorphic associations — ✅ sound
- **What:** `belongs_to :x, polymorphic: true` (`*_type` + `*_id` pair).
- **Where:** 8 models: `uploaded_by`, `performer`, `sessionable`, `user`, `resolved_by`,
  `actor`, `grantee`, `blocked_from`. Idiomatic cross-entity references.
- **Pros:** Clean modeling for genuinely heterogeneous owners (audit actor, file uploader).
- **Cons:** Polymorphic FKs cannot have DB-level foreign-key constraints → referential integrity
  is application-only for these columns.
- **Verdict:** ✅ sound — appropriately scoped; the FK-constraint gap is inherent to the pattern.

### 2c. MTI (multi-table inheritance) — genuinely absent.

---

## 3. Associations & join styles — ✅ sound / ⚠️ stylistic

- **What:** Standard Rails `belongs_to`/`has_many`; explicit join tables for M:N (e.g.
  `companies_required_agency`, `add_skills_blacklisted_district_position`).
- **Namespaced models via `table_name_prefix`:** modules declare `table_name_prefix` (e.g.
  `Bookings` → `bookings_*`, `Dayforce` → `dayforce_*`). Tables are grouped by domain prefix.
- **`optional:`/`null:` discipline:** `belongs_to ... optional: false` appears alongside polymorphic
  declarations, matching `null: false` at the DB level in newer modules.
- **Verdict:** association style ✅ sound; **module/table-name prefixing is ⚠️ stylistic** (a strong
  organizing convention worth continuing for domain grouping).

---

## 4. Enums — hybrid (three coexisting styles)

### 4a. DB-native PostgreSQL enums — ✅ sound (modern standard)
- **What:** `create_enum "..."` + `t.enum "col", enum_type: "..."`.
- **Where:** 33 native enum columns; concentrated in newer modules (`dayforce_*`, `pricing_legacy_*`,
  `agency_contracts`, `legal_entities`, `organizations_session_settings`). Example:
  `create_enum "dayforce_punch_type", ["punch_in","break_out",...]`.
- **Pros:** Values enforced at the DB; self-documenting; no integer-meaning drift; safe defaults.
- **Verdict:** ✅ sound — the best-practice enum approach and the app's current direction.

### 4b. Rails string-backed enums — ✅ sound
- **What:** `enum :status, { pending: 'pending', approved: 'approved', ... }`.
- **Where:** several models. Stores the string; readable in raw SQL.
- **Verdict:** ✅ sound (DB-native 4a is still preferable when the set is closed/stable).

### 4c. Rails integer-backed enums — ⚠️ stylistic (mild drift risk)
- **What:** `enum :status, { accepted: 0, rejected: 1 }`, `enum :action, { created: 0, updated: 1 }`.
- **Where:** common across ~45 models that use `enum`.
- **Pros:** Compact storage.
- **Cons:** Integer↔meaning mapping lives only in Ruby; reordering/inserting values or reading the
  DB directly is error-prone; no DB-level guard against invalid integers.
- **Verdict:** ⚠️ stylistic — acceptable Rails idiom, but DB-native enums (4a) are safer for new work.

---

## 5. Money / numeric handling — 🛑 the headline integrity risk

### 5a. `float` for monetary & rate values — 🛑 integrity-risk
- **What:** `t.float` used for money/rate/tax fields.
- **Where:** **160 `t.float` columns**, including `bill`, `pay`, `total`, `total_price`, `amount`,
  `fee_amount`, `tax_amount`, `rate_per_hour`, `bill_rate`, `pay_rate`, `markup_percentage`,
  `*_tax_rate` (city/country/state/special), `min_bill`/`max_bill`. (e.g. lines 216, 232, 568,
  572, 575, 890, 933, 1028, 1031.)
- **Cons:** Binary floats cannot represent decimal cents exactly → rounding errors accumulate in
  sums/multiplications; equality and ledger reconciliation become unreliable. For money/rates this
  is a correctness hazard, not a style choice.
- **Verdict:** 🛑 integrity-risk.

### 5b. `decimal(p,s)` for money — ✅ sound
- **What:** `t.decimal precision: 7, scale: 2` (and `4,2` for multipliers, `8,2`/`10,2` for larger).
- **Where:** **54 `t.decimal` columns** — e.g. `bill`/`pay` (lines 1379/1382, 1947–1974),
  payroll fields (`gross_pay`, `net_pay`, `medicare`, `social_security`, … lines 3984–3997),
  `transfer_fee`, `instant_pay_fee`, pricing `input_rate`/`output_rate`/`amount`.
- **Verdict:** ✅ sound. **NOTE the inconsistency:** the *same business concepts* (`bill`, `pay`,
  multipliers) are `decimal` in some tables and `float` in others — strong evidence float usage is
  accidental drift, not an intentional design.

### 5c. Integer `_cents` columns — ✅ sound (but rare, no money gem)
- **What:** `t.integer "*_cents"` storing minor units.
- **Where:** only 3 columns: `used_cents`, `spent_cents`, `value_cents` (lines 1634, 1646, 1648).
- **Note:** No `money-rails`/`monetize` gem in the Gemfile; cents columns are hand-rolled.
- **Verdict:** ✅ sound approach; underused.

### 5d. Unbounded `decimal` for geo — ⚠️ stylistic / minor
- **What:** `t.decimal "lat"` / `t.decimal "lng"` with no precision/scale (lines 2579–2580).
- **Verdict:** ⚠️ minor — fine for geo, but specify precision/scale for predictability.

---

## 6. FK & constraint strategy

### 6a. DB-level foreign keys — ✅ sound (good coverage, not universal)
- **What:** `add_foreign_key` declared at the DB level.
- **Where:** **408 FKs**. Against **647 uuid `*_id` columns** — so a meaningful share of `*_id`
  columns have no DB FK (some are polymorphic by design (§2b), some are unconstrained references).
- **Verdict:** ✅ sound where present; gap (≈ FK constraints < reference columns) is a watch-item.

### 6b. `on_delete` behavior — ⚠️ stylistic (cascade-heavy)
- **Where:** of FKs that specify it: **149 `:cascade`**, 6 `:restrict`, 6 `:nullify`; the rest use
  the default (no action).
- **Cons:** Cascade-heavy deletes + near-total absence of soft-delete (§9) means hard deletes can
  ripple widely. Deliberate, but worth conscious choice per relationship.
- **Verdict:** ⚠️ stylistic — call cascade vs restrict intentionally per FK.

### 6c. `NOT NULL` discipline — ✅ sound
- **Where:** **2,173 `null: false`** declarations — pervasive, including on FKs and required attrs.
- **Verdict:** ✅ sound — strong house habit of non-null-by-intent.

### 6d. CHECK / UNIQUE constraints at DB level — ✅ sound (newer modules only)
- **What:** `t.check_constraint` (8) and `t.unique_constraint` (6, several `deferrable: :deferred`).
- **Where:** concentrated in `pricing_legacy_*` — e.g. `sort_order >= 0` checks; XOR scope check
  (`country_id` xor `organizations_country_id`); composite deferrable unique keys.
- **Verdict:** ✅ sound and sophisticated; newer code reaches for real DB constraints. Older modules
  rely on Rails validations only.

---

## 7. Indexing strategy — ✅ sound (one gap)

- **What/where:** **774 `t.index`**, **201 unique** indexes, **35 partial** (`where:`) indexes,
  composite indexes present. FK columns are broadly indexed.
- **Gap — JSONB not GIN-indexed:** **0 `using: :gin`** despite 67 jsonb columns (§8). If any jsonb
  is queried by key/containment, those queries are unindexed.
- **Verdict:** ✅ sound overall; ⚠️ minor: add GIN indexes for queried jsonb.

---

## 8. JSON / JSONB usage — ✅ sound / ⚠️ stylistic-risk

- **`jsonb`:** **67 columns**, many with `default: {}` (e.g. `filters`, `credentials`,
  `app_versions`, request/response bodies). ✅ sound.
- **`t.json` (non-binary):** **36 columns** — notably `meta` (recurring across many tables),
  `scores`, `booking_variables`, `card_data`, `failure_details`, `payment_reference`.
- **Cons of `t.json`:** Postgres `json` stores raw text (no dedup, no operator/index support, slower
  access) — `jsonb` is the near-universal correct choice. Also **inconsistent defaults**: some use
  `default: {}` (correct) and some use `default: "{}"` (a string literal — lines 103, 286, 1443).
- **Verdict:** jsonb ✅ sound; **`t.json` columns are ⚠️ stylistic-risk** — prefer `jsonb`, and use
  hash defaults not string defaults.

---

## 9. Soft delete — essentially absent (observation)

- **What:** No `acts_as_paranoid`, no `discard`/`Discard`, no soft-delete gem; no `default_scope`
  hiding deleted rows.
- **Where:** only **5** `deleted_at`/`discarded_at` columns total across 388 tables.
- **Implication:** Deletion is overwhelmingly hard delete, amplified by cascade FKs (§6b). History
  is preserved instead via audit logs (§10), not tombstones.
- **Verdict:** observation — neither inherently risk nor convention; design soft-delete per entity
  on need. (No tag — it's an absence.)

---

## 10. Timestamps & auditing — ✅ sound

- **Timestamps:** `created_at` on 366/388 tables, `updated_at` on 356/388 (~92–94% coverage). The
  ~22 without are mostly join/lookup tables.
- **paper_trail:** `gem 'paper_trail'`; `has_paper_trail` on ≥4 models — versioned change history.
- **`*_log` tables:** a strong domain convention — `admin_log`, `agency_log`, `district_log`,
  `accreditation_log`, `holiday_pricing_log`, `backup_size_change_log`, etc. Append-only audit trail.
- **Manual audit columns:** 11 `created_by*`/`updated_by*` columns; audit `actor`/`resolved_by`
  polymorphic refs (§2b).
- **Verdict:** ✅ sound — multi-pronged auditing (timestamps + paper_trail + dedicated log tables).

---

## 11. Naming conventions — ✅ sound / ⚠️ stylistic

- snake_case tables/columns; `*_id` FK columns; `*_at` datetime, `*_count`/`*_cents` suffixes.
- Domain prefixing via module `table_name_prefix` (`bookings_*`, `dayforce_*`, `pricing_legacy_*`).
- Plural table names; PG enum types named `<domain>_<concept>` (e.g. `dayforce_punch_type`).
- Constraints explicitly named (`chk_*`, `*_uniq_*`).
- **Verdict:** ✅ consistent and idiomatic; domain prefixing is ⚠️ stylistic (worth adopting).

---

## 12. Denormalization & counter caches — observation

- **`counter_cache`:** **0** usages — counts are computed, not cached.
- **Generated/virtual columns (✅ sound):** 4 `t.virtual ... stored: true` columns —
  `total_rows = successful_rows + failed_rows`; `duration = finishes_at - starts_at`;
  `full_name`/`legal_name` concatenations. DB-computed denormalization done correctly.
- **Verdict:** counter_cache absence = observation; generated columns ✅ sound.

---

## 13. Multi-tenancy / scoping — ⚠️ stylistic

- **What:** Tenant scoping via `organization_id` (146 columns) and `company_id` (86); minor
  `account_id` (5), `client_id` (2).
- **Enforcement:** application-level (no `default_scope`, no row-level security visible). Scoping
  columns are widely indexed and frequently `null: false`.
- **Verdict:** ⚠️ stylistic — consistent tenant-column convention; enforcement is by app code/query
  scope, not DB policy.

---

## 14. Other notable patterns — ✅ sound

- **`citext`** for case-insensitive natural keys (`referral_code`) — idiomatic. ✅
- **Native PG types:** `t.interval` (12), `t.inet` (2), `t.time`, `t.date`, `t.binary` — leveraging
  Postgres rather than stuffing into strings. ✅
- **Concerns:** `app/models/concerns/` (`searchable`, `brand_relation`, `branding_setting`,
  `behavioral_flag`) — shared behavior via mixins. ✅

---

## Pattern → tag summary

| # | Pattern | Tag |
|---|---------|-----|
| 1a | UUID primary keys (gen_random_uuid) | ✅ sound |
| 1b | Legacy serial/bigint PKs | ⚠️ stylistic |
| 2a | STI (`type` column), used sparingly | ⚠️ stylistic |
| 2b | Polymorphic associations | ✅ sound |
| 3 | Standard Rails associations + module table-name prefixing | ✅ / ⚠️ |
| 4a | DB-native PG enums | ✅ sound |
| 4b | Rails string-backed enums | ✅ sound |
| 4c | Rails integer-backed enums | ⚠️ stylistic |
| 5a | **`float` for money/rates** | 🛑 integrity-risk |
| 5b | `decimal(p,s)` for money | ✅ sound |
| 5c | integer `_cents` | ✅ sound (rare) |
| 5d | unbounded `decimal` lat/lng | ⚠️ minor |
| 6a | DB-level FKs (not universal) | ✅ sound |
| 6b | cascade-heavy `on_delete` | ⚠️ stylistic |
| 6c | pervasive `null: false` | ✅ sound |
| 6d | DB CHECK/UNIQUE constraints (newer modules) | ✅ sound |
| 7 | rich indexing (unique/partial/composite) | ✅ sound |
| 7 | **no GIN index on jsonb** | ⚠️ minor |
| 8 | jsonb with `{}` defaults | ✅ sound |
| 8 | **`t.json` for `meta`/etc. + string `"{}"` defaults** | ⚠️ stylistic-risk |
| 9 | soft-delete essentially absent (hard delete + cascade) | observation |
| 10 | timestamps + paper_trail + `*_log` tables | ✅ sound |
| 11 | snake_case + domain prefixing + named constraints | ✅ / ⚠️ |
| 12 | no counter_cache; stored generated columns | ✅ sound |
| 13 | org/company tenant columns, app-level scoping | ⚠️ stylistic |
| 14 | citext, native PG types, concerns | ✅ sound |
