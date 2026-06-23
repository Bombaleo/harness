# RoR Schema-Design Harness — Design

**Date:** 2026-06-23
**Status:** Approved (brainstorming), pending spec review
**Location:** `./harness/schema-design/`

## Purpose

A Ralph-compatible harness that turns a PRD (plus accompanying test scenarios and
extra context docs/links) into a **coherent, RoR-aware database schema design**,
verified against test-derived requirements. The harness deliberately reuses
proven design patterns from an existing Ruby on Rails app in the same product
domain, while not propagating that app's integrity footguns.

The **harness deliverable** is two components — (R) and (A) — plus their gates and
Ralph wiring, consuming a set of shared, version-controlled artifacts. The
per-feature design work is packaged so a [Ralph](https://github.com/snarktank/ralph)
autonomous loop runs it unchanged.

**(B) is NOT part of the harness.** It is a **one-time setup action**: analyze the
existing Rails app once, extract its patterns, and bake the curated result into the
harness as static context (`schema-conventions.md`). It does not ship as a harness
skill and is never run inside the loop.

## Inputs

- **Existing Rails repo:** `../jjj/dash-api` (relative to `JJJ-V2/`).
  169 models, 783 migrations, `db/schema.rb` present (no `structure.sql`).
- **New project:** does not exist yet. The harness is greenfield-targeted; the
  "schema designed so far" lives entirely in harness artifacts, not in a Rails app.
- **PRD + test scenarios + extra context:** to be supplied at build/run time.

## Core decisions (resolved during grilling)

1. **"Done" must be machine-verifiable in the loop.** A story is not `passes: true`
   on a model's say-so.
2. **Output is design docs, not runnable migrations.** The verification signal is
   *"does the schema design cover the story's test scenarios?"* — not *"does a
   migration run?"*. This keeps output review-friendly and avoids requiring a live
   Rails app to design against.
3. **Coverage is made mechanical, not vibes.** Test scenarios are decomposed into
   atomic, ID'd data requirements; the schema doc carries a coverage matrix mapping
   every requirement ID to a concrete schema element. Gate = (a) a script asserting
   100% mapped / no orphans + (b) an adversarial verifier agent.
4. **Requirements are extracted once, up-front, and frozen.** Stable IDs are the
   backbone of the coverage matrix; re-extracting per iteration would drift IDs and
   make coverage meaningless. Mid-loop requirement gaps are *flagged*, not auto-added.
5. **A single cumulative schema artifact is the source of truth.** `schema/current.md`
   (+ regenerated ERD) plays the role `schema.rb` plays for code-Ralph. Each story
   applies a verified *delta*; the verifier and coverage check run against the
   cumulative schema, preventing fragmentation across fresh-context iterations.
6. **One curated conventions file, with split precedence.** Selected existing-app
   patterns + a baked-in best-practices baseline merge into `schema-conventions.md`.
   Style/convention conflicts → selected patterns win. Correctness/integrity
   conflicts (e.g. float-money, missing FK/NOT NULL, no unique index on a natural
   key) → best practice wins, but the deviation is flagged in the per-story doc.
7. **Stories are topologically ordered by entity dependency.** A one-time planning
   step sets `prd.json` `priority` so foundational entities are designed before
   dependents. Cycles are broken and noted. Ralph's selection logic is untouched.

## Architecture

```
(B) Pattern Analyzer ──> pattern-catalog.md ──(you cherry-pick)──> schema-conventions.md
                                                                          │
(R) Requirements + Planning ──> requirements/*.json (frozen, stable IDs)  │
                            └─> prd.json (topologically ordered priority)  │
                                                                          ▼
                  ┌──────────── Ralph loop (fresh context per iteration) ───────────┐
                  │ pick story passes:false → (A) design-feature-schema skill         │
                  │   reads schema/current.md + conventions + story requirements       │
                  │   emits delta → merges into schema/current.md + ERD                │
                  │   writes us_<slug>/schema.md (rationale + delta + coverage matrix)  │
                  │ GATE: coverage script (100%, no orphans) + adversarial verifier     │
                  │ pass → commit, mark passes:true, append progress.txt                │
                  └─────────────────────────────────────────────────────────────────┘
```

### (B) — Existing-schema Pattern Analysis (one-time setup, NOT a harness component)

A one-time action with full read access to `../jjj/dash-api`. Reads `db/schema.rb`,
`db/migrate/*`, and `app/models/*` and emits **`pattern-catalog.md`**. Run once
during setup; its curated output (`schema-conventions.md`) is baked into the harness
as static context. Not packaged as a shippable skill, not run inside the loop.

Each catalogued pattern records: *what it is*, *where it's used* (representative
files/tables), *pros/cons in context*, and a **best-practice verdict** tag:
- ✅ sound — safe to adopt as-is
- ⚠️ stylistic — a convention choice; adopt for continuity if desired
- 🛑 integrity-risk — works but carries a data-correctness hazard

**Pattern categories to detect:**
inheritance (STI / polymorphic / MTI), associations & join styles, enums,
money/decimal handling, FK & constraint strategy, indexing strategy, soft-delete,
timestamps/auditing, naming conventions, denormalization & counter-caches,
JSON/JSONB usage, multi-tenancy/scoping.

**Output is advisory.** The user cherry-picks patterns from the catalog into
`schema-conventions.md`.

### Curated context — `schema-conventions.md`

The harness's authoritative style guide. Assembled from:
- user-selected patterns from `pattern-catalog.md`, plus
- a baked-in **Rails + relational best-practices baseline**: FK constraints,
  NOT NULL by default, correct numeric types (no float money), indexes on every
  FK, `created_at`/`updated_at`, unique indexes on natural keys, sensible enum
  backing, and idiomatic-Rails affordances (association conventions, polymorphic
  vs STI guidance, counter caches where justified).

**Precedence rule, by category:**
- **Style/convention** (naming, association style, STI vs polymorphic, enum use)
  → selected patterns win.
- **Correctness/integrity** (data-loss/corruption risks) → best practice wins; the
  harness follows it and emits a flagged note ("deviated from existing-app pattern
  X for integrity reason Y") rather than silently inheriting the footgun.

The adversarial verifier enforces this: it will not pass a delta that violates an
integrity-baseline rule even if an existing pattern endorses it; it defers to
selected patterns on style.

### Component (R) — Requirements Extractor + Dependency Planner

One-shot, up-front, produces frozen, version-controlled output:

- **`requirements/us_<slug>.json`** — atomic data requirements decomposed from the
  PRD + test scenarios for each story. Each requirement is typed and carries a
  stable ID (e.g. `REQ-VENDOR-001`):
  - `entity_exists` — a named entity must be representable
  - `attribute` — name + type + nullability
  - `relationship` — between entities + cardinality
  - `constraint` — e.g. NOT NULL, unique, check, range
  - `state_transition` — a lifecycle state/transition that must be representable
- **`prd.json`** — Ralph's story file. `priority` is set by a **topological sort**
  of the entity dependency graph extracted from all requirements: foundational
  entities (few/no dependencies) rank ahead of dependents. True cycles are broken
  at a chosen point and noted (one side becomes a forward reference).

If schema work later reveals a missing requirement, the loop **flags it** (does not
invent an ID); resolving it means a deliberate, versioned re-run of (R).

### Component (A) — `design-feature-schema` skill (per-iteration unit)

Invoked by Ralph's per-iteration prompt (`CLAUDE.md`). For one story:

1. **Read** `schema/current.md` (cumulative source of truth) + `schema-conventions.md`
   + the story's `requirements/us_<slug>.json`.
2. **Design** the story's requirements as a **delta** against the cumulative schema —
   new tables, or alterations to existing ones (added columns, indexes, FKs).
3. **Merge** the delta into `schema/current.md` and regenerate the mermaid ERD.
4. **Write** `us_<slug>/schema.md`: rationale + the delta + the **coverage matrix**
   (every requirement ID → the concrete table/column/association/constraint that
   satisfies it, in the cumulative schema after merge).

### Verification gate (the `passes: true` signal)

Both must pass, or the story is not marked done and is not committed:

- **(a) Mechanical coverage check** — a script asserts every requirement ID for the
  story appears in the coverage matrix with a non-empty mapping, and that each mapped
  element actually exists in `schema/current.md` after merge. No orphans, no dangling
  mappings.
- **(b) Adversarial verifier** — a fresh-context agent tasked to *break* the design:
  find a requirement the schema cannot actually represent; a delta that duplicates or
  contradicts something already in `current.md` (redefined table, type mismatch on a
  shared column); or an integrity-baseline violation. Must sign off.

On pass: commit, mark `passes: true` in `prd.json`, append learnings to `progress.txt`.

## Ralph integration

No fork of Ralph is required. Mapping to Ralph's existing mechanics:

| Ralph concept            | This harness                                              |
|--------------------------|-----------------------------------------------------------|
| `prd.json` stories       | Produced by (R); `priority` = topological order            |
| per-iteration prompt     | `CLAUDE.md` invokes the `design-feature-schema` skill (A)  |
| "implement the story"    | Design the delta + merge into `schema/current.md`          |
| quality checks           | Coverage script (a) + adversarial verifier (b)             |
| commit + `passes: true`  | Only on gate pass                                          |
| `progress.txt`           | Append per-story learnings / flagged requirement gaps      |
| cumulative state         | `schema/current.md` (+ ERD), the `schema.rb` analog        |
| stop condition           | All stories `passes: true` → `<promise>COMPLETE</promise>` |

## Proposed artifact layout (`./harness/schema-design/`)

```
harness/schema-design/
├── 2026-06-23-ror-schema-design-harness-design.md   # this doc
├── setup/
│   └── analyze-existing-schema.md    # (B) one-time action prompt/notes (not shipped in loop)
├── skills/
│   ├── extract-requirements/         # (R): requirements + dependency planner
│   └── design-feature-schema/        # (A): per-iteration unit
├── scripts/
│   └── check-coverage.*              # mechanical gate (a)
├── ralph/
│   ├── ralph.sh
│   └── CLAUDE.md                     # per-iteration prompt that calls (A)
└── workspace/                        # run artifacts (per project)
    ├── pattern-catalog.md            # (B) output, advisory
    ├── schema-conventions.md         # curated context (style guide)
    ├── requirements/us_<slug>.json   # (R) frozen output
    ├── prd.json                      # (R) ordered stories
    ├── progress.txt                  # Ralph learnings
    ├── schema/current.md (+ erd)     # cumulative source of truth
    └── us_<slug>/schema.md           # per-story rationale + delta + coverage matrix
```

## Build order

**Setup (one-time, not part of the harness build):**
- **(B)** analyze `../jjj/dash-api` → `pattern-catalog.md`; produce assisted draft
  `schema-conventions.md`; user trims. Output becomes the harness's static context.

**Harness build:**
1. **(R)** requirements extractor + dependency planner (needs a PRD + test scenarios).
2. Coverage script (a) + adversarial verifier (b).
3. **(A)** `design-feature-schema` skill.
4. Ralph wiring (`ralph.sh`, `CLAUDE.md`).

## Open / deferred items

- PRD + test scenarios source and exact format — needed before (R) and any loop run.
- New project root — not created yet; harness operates on its own `workspace/`.
- **Curation mode: assisted (confirmed).** (B) emits the full `pattern-catalog.md`
  *and* drafts a `schema-conventions.md` from its tag recommendations (✅ sound +
  best-practices baseline included; 🛑 integrity-risk excluded with a note;
  ⚠️ stylistic included-but-marked). The user trims/overrides that draft rather than
  hand-authoring or being walked through interactively.
```
