# schema-design

A [Ralph](https://github.com/snarktank/ralph)-compatible harness that turns a
PRD (plus per-story test scenarios and optional context docs) into a coherent,
**RoR-aware database schema *design*** — verified against test-derived
requirements. The output is design documents (a cumulative schema as JSON plus
a rendered markdown view and a mermaid ERD), **not runnable migrations**: the
verification signal is *"does the schema design cover the story's test
scenarios?"*, which keeps the output review-friendly and needs no live Rails app
to design against. The harness deliberately reuses proven design patterns from an
existing Rails app (`dash-api`) while refusing to propagate that app's integrity
footguns.

## The verification model

"Done" is **machine-checked**, never declared by the model. A story only flips to
`passes: true` when **both** gates pass:

- **(a) Mechanical coverage check** — `bin/check-coverage` asserts that every
  requirement ID for the story maps to a concrete schema element in the coverage
  matrix, and that each mapped element actually exists in the cumulative schema.
  No orphans, no dangling mappings.
- **(b) Adversarial verifier** — the `verify-schema-delta` skill runs as a
  fresh-context reviewer whose default stance is suspicion. It tries to *break*
  the design: an unrepresentable requirement, a delta that contradicts or
  duplicates something already in the schema, or an integrity-baseline violation.
  It writes a `pass`/`fail` verdict and only passes when it has zero findings.

If either gate fails the story is not committed and not marked done; the failure
(and any flagged requirement gap) is appended to `progress.txt` so the next
iteration retries with that note.

## Repository layout

```
schema-design/
├── lib/schema_harness/   # stdlib-only Ruby support code
│   ├── contracts.rb      # JSON shape validators for requirements/coverage/schema
│   ├── planner.rb        # topological story ordering (TSort) → prd.json priority
│   ├── coverage.rb       # mechanical gate (a): requirement-ID ↔ schema-element check
│   └── renderer.rb       # current.json → markdown + mermaid ERD
├── bin/                  # thin CLI wrappers around lib/
│   ├── plan              # build the dependency-ordered prd.json from requirements/
│   ├── check-coverage    # run gate (a) for one story (exit 0 = covered)
│   └── render-schema     # regenerate current.md + current.mmd from current.json
├── skills/               # the three skills the harness uses
│   ├── extract-requirements/   # (R) one-shot: stories → frozen requirements + prd.json
│   ├── design-feature-schema/  # (A) per-iteration: design one story's schema delta
│   └── verify-schema-delta/    # gate (b): adversarial pass/fail verdict
├── ralph/                # the Ralph loop wiring
│   ├── CLAUDE.md         # the per-iteration prompt (do exactly ONE story)
│   └── ralph.sh          # the driver loop
├── docs/
│   └── input-contract.md # authoritative input/output artifact shapes
└── workspace/            # per-run inputs and produced artifacts
    ├── input/            # what you supply (see "Input" below)
    ├── schema-conventions.md   # baked-in static style guide
    ├── requirements/     # (R) frozen, stably-ID'd requirements
    ├── prd.json          # (R) Ralph story file, ordered by priority
    ├── schema/           # current.json (source of truth) + current.md + current.mmd
    ├── progress.txt      # Ralph learnings / flagged gaps
    └── us_<slug>/        # per-story schema.md + coverage.json + verdict.json
```

## Input

You supply everything the harness consumes under `workspace/input/`:

- `stories/us_<slug>.md` — **REQUIRED**, one file per story, in a fixed shape
  (title, `slug`, `domain`, Description, Acceptance Criteria, Test Scenarios).
- `prd.md` — **optional** global PRD context (free prose, advisory only).
- `context/` — **optional** extra docs/links (advisory only).

The `domain` (UPPER_SNAKE) becomes the `REQ-<DOMAIN>-NNN` prefix for that story's
requirement IDs. See [`docs/input-contract.md`](docs/input-contract.md) for the
authoritative shapes of every input and produced artifact.

The real sample input, `workspace/input/stories/us_sample-vendor.md`:

```markdown
# Sample vendor onboarding
slug: sample-vendor
domain: VENDOR

## Description
A vendor can be registered and must belong to an organization. A vendor has a status.

## Acceptance Criteria
- A vendor record can be created with a name and a status.
- A vendor belongs to exactly one organization.

## Test Scenarios
### Register active vendor
Given an organization "Acme"
When a vendor "Globex" is registered under "Acme" with status active
Then the vendor is stored linked to "Acme" with status active
```

## How it runs (the pipeline)

**1. Extract requirements (R) — one-shot, before the loop.** The
`extract-requirements` skill decomposes each story's acceptance criteria and test
scenarios into atomic, typed requirements (`entity_exists`, `attribute`,
`relationship`, `constraint`, `state_transition`), minting **stable IDs**
(`REQ-<DOMAIN>-001`, …) that are **frozen** — they are the backbone of the
coverage matrix, so they are never renumbered on re-runs. It writes
`workspace/requirements/us_<slug>.json` per story.

**2. Plan — topological story ordering.** `bin/plan workspace` runs the planner
(`TSort` over the entity dependency graph) so foundational entities are designed
before dependents. It writes `workspace/prd.json`, Ralph's story file, with
`priority` ascending = design order (cycles are broken and noted).

**3. Per story, inside the loop.** Each fresh iteration:

- picks the lowest-`priority` story where `passes: false`;
- invokes **`design-feature-schema` (A)**, which reads the cumulative
  `schema/current.json`, the conventions, and the story's frozen requirements,
  then applies a **delta** (new tables, or ALTERs to existing ones) into
  `current.json` and writes the per-story `schema.md` + `coverage.json`;
- runs **gate (a)** `bin/check-coverage workspace <slug>`;
- runs **gate (b)** the `verify-schema-delta` skill, then reads
  `us_<slug>/verdict.json`;
- on **both** passing: appends to `progress.txt`, sets `passes: true` in
  `prd.json`, and commits.

`bin/render-schema workspace` regenerates the human views `schema/current.md` and
the mermaid ERD `schema/current.mmd` from `current.json`.

The single cumulative `schema/current.json` is the source of truth (the
`schema.rb` analog): each story applies a verified delta to it, and both gates run
against the cumulative schema, so the design does not fragment across
fresh-context iterations.

The loop is driven by Ralph with the per-iteration prompt `ralph/CLAUDE.md`. Each
iteration is a **fresh context** that does exactly ONE story, then stops; the
driver re-invokes a clean agent for the next:

```bash
# from schema-design/ ; optional arg = max iterations (default 50)
ralph/ralph.sh 50
```

```bash
# what each iteration runs, in essence:
claude -p "$(cat ralph/CLAUDE.md)" --dangerously-skip-permissions
```

The loop stops when every story is `passes: true`, at which point the iteration
emits `<promise>COMPLETE</promise>`.

## Conventions

`workspace/schema-conventions.md` is the harness's authoritative, **baked-in
static style guide** — UUID primary keys, money never `float`, DB-native enums, a
DB-level foreign key on every non-polymorphic reference, `null: false` by default,
unique indexes on natural keys, `jsonb` over `json`, and more. It was assembled
once from a one-time analysis of `dash-api` plus a relational best-practices
baseline; that analysis is **not** part of the harness loop. Precedence is split:
on **style** conflicts the existing-app pattern wins, but on **integrity**
conflicts the baseline wins and the harness emits a flagged deviation note rather
than inheriting the footgun. See the file itself for the full rule set rather than
relying on this summary.

## Development

- **Toolchain:** Ruby `3.3.10` (see `.ruby-version`), stdlib-only support code,
  with **RSpec** the sole dependency (see `Gemfile`).
- **Setup & tests:**

  ```bash
  bundle install
  bundle exec rspec      # 27 examples, 0 failures
  ```

- **CLI helpers** (all take the workspace dir):

  ```bash
  bin/plan workspace                    # requirements/ → ordered prd.json
  bin/check-coverage workspace <slug>   # mechanical gate (a); exit 0 = covered
  bin/render-schema workspace           # current.json → current.md + current.mmd
  ```
