---
name: extract-requirements
description: One-shot, up-front. Decompose each workspace/input/stories/us_<slug>.md into atomic, stably-ID'd data requirements (requirements/us_<slug>.json), then build a dependency-ordered prd.json. Run before the Ralph loop; never inside it.
---

# Extract Requirements (R)

You convert the harness input into frozen requirement files. Run ONCE up front.

## Inputs
- `workspace/input/stories/us_<slug>.md` — REQUIRED, the contract in `docs/input-contract.md`.
- `workspace/input/prd.md`, `workspace/input/context/*` — advisory context only.

## Procedure
1. List every `workspace/input/stories/us_*.md`.
2. For EACH story, read its `slug`, `domain`, Description, Acceptance Criteria, and Test Scenarios.
3. Decompose the acceptance criteria + test scenarios into atomic requirements. Each requirement is
   exactly one of: `entity_exists`, `attribute`, `relationship`, `constraint`, `state_transition`
   (shapes in `docs/input-contract.md`).
   - Mint IDs as `REQ-<DOMAIN>-001`, `-002`, … sequentially per story. Assign IDs in source order
     and NEVER renumber on re-runs: if a `requirements/us_<slug>.json` already exists, preserve every
     existing id↔requirement pairing and only append new ones with the next free number.
   - Prefer many small requirements over few broad ones (one attribute = one requirement).
   - Every relationship gets a `from`/`to`/`cardinality`; `from` is the side that holds the reference.
4. Write `workspace/requirements/us_<slug>.json` per the contract.
5. VALIDATE each file: run `ruby -r./lib/schema_harness/contracts -e 'require "json";
   p SchemaHarness::Contracts.validate_requirements(JSON.parse(File.read(ARGV[0])))' workspace/requirements/us_<slug>.json`
   — fix until it prints `[]`.
6. Build the ordered story file: run `bin/plan workspace`. Confirm `workspace/prd.json` is written.
7. Report: stories processed, total requirements, and any cycles `bin/plan` reported.

## Rules
- These files are FROZEN once written. The design loop reads them read-only.
- If a missing requirement is discovered later, it is flagged for a deliberate re-run of THIS skill —
  never invented mid-loop.
- Do not design schema here. Requirements describe WHAT must be representable, not table shapes.
