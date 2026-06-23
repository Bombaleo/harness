# Schema Conventions — Style Guide

**Status:** Finalized 2026-06-23 via interactive review of `pattern-catalog.md` (Task B). This is the
authoritative style guide baked into the schema-design harness as static context.

**Provenance tags:** `[from dash-api]` = ✅ sound pattern adopted from the existing app ·
`[baseline]` = Rails/relational best-practice baseline · `[chosen]` = a stylistic decision made
during review. 🛑 integrity-risk patterns are excluded and listed at the end with their replacement.

**Precedence:** style conflicts → existing dash-api pattern wins; integrity conflicts → baseline
wins and the harness emits a flagged deviation note rather than inheriting the footgun.

---

## 1. Primary keys & identifiers

- **UUID primary keys**: `id: :uuid, default: -> { "gen_random_uuid()" }`. House standard. `[from dash-api]` `[baseline]` `[chosen]`
- No new `serial`/integer PKs (legacy holdouts only). `[from dash-api]`
- FK columns are `uuid`, named `<association>_id`. `[from dash-api]`

## 2. Numeric & money types

- **Money is `decimal(p, s)`** — typically `precision: 10, scale: 2`. Never `float`. `[baseline]` `[chosen]`
- Rates/multipliers/percentages: `decimal` with explicit precision/scale (e.g. multipliers `decimal(4,2)`). Never `float`. `[baseline]`
- The same business concept uses the **same type across all tables** (no `decimal` here / `float` there). `[baseline]`
- Geo coordinates: `decimal` with explicit precision/scale (e.g. `decimal(9,6)`). `[baseline]`
- Counts/quantities: `integer`, `null: false`, sensible `default`. `[baseline]`

## 3. Enums

- **DB-native PostgreSQL enums** for closed, stable value sets: `create_enum` + `t.enum ..., enum_type:`. `[from dash-api]` `[baseline]` `[chosen]`
- Name enum types `<domain>_<concept>` (e.g. `dayforce_punch_type`). `[from dash-api]`
- If a Rails `enum` is unavoidable, prefer **string-backed**; avoid new integer-backed enums (meaning-drift risk). `[baseline]`

## 4. Foreign keys & referential integrity

- **DB-level foreign key on every non-polymorphic reference** (`add_foreign_key`). `[baseline]` `[chosen]`
- **`on_delete` chosen explicitly per relationship** — `:cascade` only where child rows are meaningless
  without the parent; `:restrict`/`:nullify` otherwise. No blanket cascade default. `[baseline]` `[chosen]`
- Polymorphic associations (`*_type` + `*_id`) allowed for genuinely heterogeneous owners
  (audit actor, uploader, sessionable); their integrity is enforced in app code. `[from dash-api]`

## 5. NOT NULL & constraints

- **`null: false` by default** — nullable only when "unknown/absent" is a real domain state. `[from dash-api]` `[baseline]` `[chosen]`
- **DB-level CHECK constraints** for invariants (ranges, `sort_order >= 0`, XOR scopes), explicitly named (`chk_<table>_<rule>`). `[from dash-api]` `[baseline]`
- **DB-level UNIQUE constraints/indexes** on every natural key; composite where multi-column; `deferrable: :deferred` when ordering requires it. `[from dash-api]` `[baseline]`

## 6. Indexing

- **Index every foreign key.** `[baseline]`
- **Unique index on every natural key** and uniqueness validation. `[from dash-api]` `[baseline]`
- **Partial indexes** (`where:`) for filtered hot paths / conditional uniqueness. `[from dash-api]`
- Composite indexes ordered by selectivity. `[from dash-api]`
- **GIN-index any jsonb column queried** by key/containment. `[baseline]` `[chosen]`

## 7. JSON

- **`jsonb` only — never `json`.** `[baseline]` `[chosen]`
- Default to a **hash literal** `default: {}` (or `default: []`), never the string `"{}"`. `[baseline]`
- Don't model relational data as jsonb when it has its own queries/constraints — promote to columns/tables. `[baseline]`
  (See §11 for the StoreModel-typed-jsonb exception for variant config payloads.)

## 8. Timestamps & auditing

- **Every table has `created_at` and `updated_at`** (`t.timestamps`). `[from dash-api]` `[baseline]` `[chosen]`
- **Dedicated `*_log` audit tables** for domain-significant change history (append-only). `[from dash-api]` `[chosen]`
- **paper_trail versioning** on entities that need a full field-level audit trail. `[from dash-api]` `[chosen]`
- **`created_by`/`updated_by`** (or polymorphic actor) where attributing the change matters. `[from dash-api]` `[chosen]`

## 9. Soft delete

- **Per-entity decision.** Hard delete by default; add an explicit `deleted_at` (or `discarded_at`)
  + partial index + scope only for entities needing recoverability/history. Don't rely on cascade
  alone for important data. `[baseline]` `[chosen]`

## 10. Naming & organization

- snake_case plural tables; `*_id` FKs, `*_at` datetimes, `*_cents`/`*_count` suffixes. `[from dash-api]` `[baseline]`
- Name all DB constraints explicitly (`chk_*`, `*_uniq_*`). `[from dash-api]`
- **Domain table-name prefixing** via module `table_name_prefix` (`bookings_*`, `dayforce_*`,
  `pricing_legacy_*`) to group a feature's tables. `[from dash-api]` `[chosen]`

## 11. Subtypes & inheritance

**Pick the strategy by *why* the subtypes differ** (all three are sanctioned): `[chosen]`

- **Behavior differs, columns shared** → **STI** (`type` discriminator), used *sparingly* — only for
  small, stable hierarchies that share nearly all columns. `[from dash-api]` `[baseline]`
- **Attributes genuinely diverge and deserve DB-level integrity** (NOT NULL, FKs, CHECK, unique) →
  **delegated types** (Rails 6.1+) or separate per-subtype tables. The modern, normalized default. `[baseline]`
- **Subtypes share identity/lifecycle but each carries a distinct flexible config payload** →
  **STI + StoreModel-typed jsonb** (dash-api's `Ma::OvertimeRule` pattern): one table with a `type`
  discriminator and a `configuration` jsonb column whose shape/validation is a per-subtype StoreModel
  class. `[from dash-api]`
  - ⚠️ **Integrity note:** this moves per-subtype attribute constraints *out of the DB* into Ruby
    validations. Use only for true variant config blobs — never to avoid columns that should be real,
    DB-constrained columns.
- Use **polymorphic associations** for "subtypes" that are really independent models playing a shared
  role (not an is-a hierarchy). `[from dash-api]`

## 12. Multi-tenancy / scoping

- **Tenant scoping via `organization_id`** (and/or `company_id`) on tenant-scoped tables — indexed and
  usually `null: false`; isolation enforced in app/query code. `[from dash-api]` `[chosen]`
- Index the tenant column and include it in relevant composite/unique indexes (uniqueness is usually
  *per tenant*). `[baseline]`

## 13. Postgres affordances (adopt as needed)

- **Generated/stored columns** (`t.virtual ..., stored: true`) for derived values (full_name, totals,
  durations) instead of app-side denormalization. `[from dash-api]` `[chosen]`
- **`citext`** for case-insensitive natural keys (codes, handles). `[from dash-api]` `[chosen]`
- Native types where they fit: `interval`, `inet`, `date`, `time`. `[from dash-api]`
- No `counter_cache` by default — add only with a demonstrated read-hot count. `[baseline]`

---

## Deliberately excluded (integrity) — with baseline replacement

- 🛑 **`float` for money/rates/percentages** (160 columns in dash-api). Binary floats can't represent
  decimal cents exactly → rounding/reconciliation errors. **Instead:** `decimal(p,s)` (§2).
- 🛑 **Non-polymorphic reference columns without a DB foreign key.** **Instead:** a DB-level FK on every
  non-polymorphic reference (§4).
- 🛑 **Required fields left nullable.** **Instead:** `null: false` by default (§5).
- 🛑 **Natural keys without a unique index.** **Instead:** a unique index/constraint on every natural key (§5/§6).
- 🛑 **`t.json` (non-binary) + string `"{}"` defaults.** No indexing/operators; string default is a
  latent bug. **Instead:** `jsonb` with `default: {}`, GIN-indexed where queried (§7).
