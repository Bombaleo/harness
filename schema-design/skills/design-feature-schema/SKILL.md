---
name: design-feature-schema
description: Per-story unit invoked by the Ralph loop. Design one story's requirements as a delta against the cumulative schema (schema/current.json), following schema-conventions.md, and emit a coverage matrix that the mechanical gate can verify.
---

# Design Feature Schema (A)

You design the schema for ONE story, given its slug.

## Inputs (read first, in this order)
1. `workspace/schema/current.json` — the cumulative schema designed so far. SOURCE OF TRUTH.
   If absent, treat as `{"tables":[],"enums":[],"associations":[]}`.
2. `workspace/schema-conventions.md` — the authoritative style guide. FOLLOW IT.
3. `workspace/requirements/us_<slug>.json` — the requirements you must satisfy.

## Procedure
1. Read the cumulative schema. Identify which required entities already exist as tables and which
   are new. NEVER redefine an existing table — ALTER it (add columns/indexes/FKs) instead.
2. Design a delta that satisfies every requirement in the story, applying `schema-conventions.md`:
   UUID PKs; money as integer `_cents` or `decimal`, never float; DB-native enums; a DB-level FK on
   every non-polymorphic reference; `null: false` by default; unique index on every natural key;
   index every FK; subtype strategy per §11; tenant scoping via `organization_id`. When a requirement
   would otherwise reproduce a dash-api integrity footgun, follow the baseline and add a one-line
   "deviation note" in `schema.md`.
3. Merge the delta into `workspace/schema/current.json` (add new tables/enums/associations or extend
   existing tables). Keep it valid per `docs/input-contract.md`.
4. Write `workspace/us_<slug>/coverage.json`: one mapping per requirement id → the concrete
   `satisfied_by` element (table/column/enum/constraint/index/association) you just ensured exists.
5. Write `workspace/us_<slug>/schema.md`: (a) rationale, (b) the delta in human terms,
   (c) the coverage matrix as a table, (d) any deviation notes.
6. Regenerate views: run `bin/render-schema workspace`.
7. Self-check the gate BEFORE finishing: run `bin/check-coverage workspace <slug>`. If it exits
   non-zero, fix the schema/coverage until it passes.

## Rules
- Requirement IDs are read-only inputs — never edit `requirements/*.json`.
- If a requirement cannot be satisfied without inventing a NEW requirement, STOP and append the gap to
  `workspace/progress.txt` rather than guessing; the loop will surface it for an (R) re-run.
- Prefer altering existing tables to creating near-duplicates; check `current.json` for an existing
  home before adding a table.
