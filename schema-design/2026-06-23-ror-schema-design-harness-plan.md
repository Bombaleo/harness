# RoR Schema-Design Harness — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Ralph-compatible harness that turns a PRD (+ test scenarios) into a coherent, RoR-aware database **schema design**, machine-verified against test-derived requirements.

**Architecture:** Two agent skills — (R) extract-requirements and (A) design-feature-schema — plus an adversarial verifier skill and four deterministic Ruby tools (contract validation, dependency planner, coverage checker, schema renderer). A cumulative `schema/current.json` is the source of truth; `current.md` + mermaid ERD are rendered from it. Ralph loops the per-story design work unchanged; the coverage checker + verifier are its quality gates.

**Tech Stack:** Ruby (stdlib only: `json`, `tsort`, `set`) + RSpec for the deterministic tools; Markdown SKILL.md prompts for the three agent components; bash for Ralph wiring.

**Design spec (source of truth for *why*):** `harness/schema-design/2026-06-23-ror-schema-design-harness-design.md`
**Static context already produced (setup task B):** `harness/schema-design/workspace/schema-conventions.md`, `harness/schema-design/workspace/pattern-catalog.md`

## Global Constraints

- **Git repo root is `/Users/yaroslavlebedevich/Projects/JJJ-V2/harness`.** The harness lives in
  `schema-design/` within it. In step commands, read every `cd harness/schema-design` as
  `cd /Users/yaroslavlebedevich/Projects/JJJ-V2/harness/schema-design`, and every `git add` path
  is relative to the repo root (`schema-design/...`, NOT `harness/schema-design/...`).
- **Ruby 3.3.10**, pinned via `schema-design/.ruby-version` (matches the dash-api app; resolved by
  rbenv shims). Bundler 2.7.x. Run all `ruby`/`bundle`/`rspec` commands from inside `schema-design/`
  so the pin takes effect.
- All other paths below are relative to `harness/schema-design/` unless absolute.
- Ruby tools use **stdlib only** — no runtime gems. RSpec is the only dev dependency.
- Requirement IDs match `^REQ-[A-Z0-9]+-\d{3}$` (e.g. `REQ-VENDOR-001`) and are **stable/frozen** once (R) runs; never minted inside the loop.
- `schema/current.json` is the single source of truth; `current.md` and `current.mmd` are always regenerated from it, never hand-edited.
- The five requirement types are exactly: `entity_exists`, `attribute`, `relationship`, `constraint`, `state_transition`.
- A story is `passes: true` only if BOTH the coverage checker (exit 0) AND the verifier verdict (`"pass"`) succeed.
- Conventions precedence (from the spec): style conflicts → dash-api pattern wins; integrity conflicts → baseline wins + flagged. The verifier enforces the integrity half.

## File Structure

```
harness/schema-design/
├── Gemfile                          # rspec dev dep only
├── docs/input-contract.md           # Task 1 — harness-defined PRD/test-scenario input shape
├── lib/schema_harness/
│   ├── contracts.rb                 # Task 2 — validators for all JSON artifacts
│   ├── planner.rb                   # Task 3 — entity DAG + topological story ordering
│   ├── coverage.rb                  # Task 4 — mechanical gate (a)
│   └── renderer.rb                  # Task 5 — current.json -> md + mermaid
├── bin/
│   ├── plan                         # Task 3 — CLI: requirements/*.json -> prd.json
│   ├── check-coverage               # Task 4 — CLI: gate (a) for one story
│   └── render-schema                # Task 5 — CLI: current.json -> current.md + .mmd
├── spec/
│   ├── spec_helper.rb
│   ├── contracts_spec.rb            # Task 2
│   ├── planner_spec.rb              # Task 3
│   ├── coverage_spec.rb             # Task 4
│   ├── renderer_spec.rb             # Task 5
│   └── fixtures/                    # shared fixtures
├── skills/
│   ├── extract-requirements/SKILL.md   # Task 6 — (R)
│   ├── design-feature-schema/SKILL.md   # Task 7 — (A)
│   └── verify-schema-delta/SKILL.md     # Task 8 — verifier gate (b)
├── ralph/
│   ├── CLAUDE.md                    # Task 9 — per-iteration prompt
│   └── ralph.sh                     # Task 9 — loop driver
└── workspace/                       # runtime, per-project (see design doc layout)
```

---

### Task 1: Define the input contract + artifact schemas (documentation deliverable)

**Files:**
- Create: `docs/input-contract.md`
- Create: `Gemfile`
- Create: `.ruby-version` (contents: `3.3.10`)
- Create: `spec/spec_helper.rb`

**Interfaces:**
- Produces: the canonical shapes every later task validates against — the `input/stories/us_<slug>.md` input format, and the JSON shapes for `requirements/us_<slug>.json`, `prd.json`, `us_<slug>/coverage.json`, and `schema/current.json`.

- [ ] **Step 1: Write `Gemfile`**

```ruby
source "https://rubygems.org"
gem "rspec", "~> 3.13", group: :development
```

- [ ] **Step 2: Install and init RSpec**

Run: `cd harness/schema-design && bundle install && bundle exec rspec --init`
Expected: creates `.rspec` and `spec/spec_helper.rb`.

- [ ] **Step 3: Write `docs/input-contract.md`** documenting the harness-defined input and all artifact JSON shapes.

````markdown
# Harness Input Contract

## Input the harness consumes

`workspace/input/prd.md` — optional global PRD context (free prose, advisory only).
`workspace/input/context/` — optional extra docs/links (advisory only).
`workspace/input/stories/us_<slug>.md` — REQUIRED, one file per story, this exact shape:

```markdown
# <Story title>
slug: <kebab-slug>            # must equal the filename slug
domain: <UPPER_SNAKE>          # used as the REQ-<DOMAIN>-NNN id prefix, e.g. VENDOR

## Description
<narrative>

## Acceptance Criteria
- <criterion>
- <criterion>

## Test Scenarios
### <scenario name>
Given <data precondition>
When <action>
Then <observable data outcome>
```

## Artifacts the harness produces

### requirements/us_<slug>.json
```json
{
  "story_slug": "vendor-onboarding",
  "title": "Vendor onboarding",
  "domain": "VENDOR",
  "requirements": [
    { "id": "REQ-VENDOR-001", "type": "entity_exists", "entity": "Vendor", "description": "..." },
    { "id": "REQ-VENDOR-002", "type": "attribute", "entity": "Vendor", "name": "status",
      "data_type": "enum", "nullable": false, "description": "..." },
    { "id": "REQ-VENDOR-003", "type": "relationship", "from": "JobPosting", "to": "Vendor",
      "cardinality": "many_to_one", "description": "..." },
    { "id": "REQ-VENDOR-004", "type": "constraint", "entity": "Rate", "constraint_kind": "check",
      "expression": "amount_cents >= 0", "description": "..." },
    { "id": "REQ-VENDOR-005", "type": "state_transition", "entity": "JobPosting",
      "states": ["draft","published","closed"],
      "transitions": [["draft","published"],["published","closed"]], "description": "..." }
  ]
}
```
- `cardinality` ∈ `one_to_one | one_to_many | many_to_one | many_to_many`.
- For `relationship`, `from` holds the reference to `to` (so `from` depends on `to`), except
  `many_to_many`, where a join entity depends on both.
- `constraint_kind` ∈ `not_null | unique | check | range | foreign_key`.

### prd.json (Ralph story file)
```json
{
  "branchName": "schema-design",
  "stories": [
    { "id": "us_vendor-onboarding", "slug": "vendor-onboarding", "title": "Vendor onboarding",
      "priority": 1, "requirementsFile": "requirements/us_vendor-onboarding.json", "passes": false }
  ]
}
```
`priority` ascending = design order (1 first). Set by the planner (Task 3).

### us_<slug>/coverage.json (machine-readable coverage matrix)
```json
{
  "story_slug": "vendor-onboarding",
  "mappings": [
    { "requirement_id": "REQ-VENDOR-001", "satisfied_by": { "kind": "table", "name": "vendors" } },
    { "requirement_id": "REQ-VENDOR-002",
      "satisfied_by": { "kind": "column", "table": "vendors", "name": "status" } }
  ]
}
```
`satisfied_by.kind` ∈ `table | column | association | constraint | index | enum`.

### schema/current.json (cumulative source of truth — the schema.rb analog)
```json
{
  "tables": [
    { "name": "vendors",
      "columns": [
        { "name": "id", "type": "uuid", "null": false, "primary_key": true },
        { "name": "status", "type": "enum", "enum_type": "vendor_status", "null": false },
        { "name": "amount_cents", "type": "integer", "null": false } ],
      "indexes": [ { "columns": ["status"], "unique": false } ],
      "foreign_keys": [ { "column": "organization_id", "references": "organizations", "on_delete": "restrict" } ],
      "checks": [ { "name": "chk_vendors_amount", "expression": "amount_cents >= 0" } ] }
  ],
  "enums": [ { "name": "vendor_status", "values": ["active","inactive"] } ],
  "associations": [
    { "from": "job_postings", "to": "vendors", "kind": "belongs_to", "via": "vendor_id" } ]
}
```
````

- [ ] **Step 4: Commit**

```bash
git add harness/schema-design/Gemfile harness/schema-design/.rspec harness/schema-design/spec/spec_helper.rb harness/schema-design/docs/input-contract.md
git commit -m "docs(harness): define schema-design input contract and artifact shapes"
```

---

### Task 2: Contract validators

**Files:**
- Create: `lib/schema_harness/contracts.rb`
- Test: `spec/contracts_spec.rb`
- Create: `spec/fixtures/requirements_valid.json`, `spec/fixtures/requirements_bad_id.json`

**Interfaces:**
- Produces: `SchemaHarness::Contracts.validate_requirements(hash) -> [errors]` (empty array = valid). Also `.validate_prd`, `.validate_coverage`, `.validate_current_schema`, each returning an array of human-readable error strings.
- Consumes: the JSON shapes from Task 1.

- [ ] **Step 1: Write the failing test**

```ruby
# spec/contracts_spec.rb
require "json"
require_relative "../lib/schema_harness/contracts"

RSpec.describe SchemaHarness::Contracts do
  def fixture(name) = JSON.parse(File.read("spec/fixtures/#{name}"))

  it "accepts a well-formed requirements file" do
    expect(described_class.validate_requirements(fixture("requirements_valid.json"))).to eq([])
  end

  it "rejects a requirement whose id violates the REQ-<DOMAIN>-NNN pattern" do
    errors = described_class.validate_requirements(fixture("requirements_bad_id.json"))
    expect(errors).to include(match(/REQ-/))
  end

  it "rejects an unknown requirement type" do
    h = { "story_slug" => "x", "title" => "x", "domain" => "X",
          "requirements" => [{ "id" => "REQ-X-001", "type" => "teleport", "description" => "d" }] }
    expect(described_class.validate_requirements(h)).to include(match(/type/))
  end
end
```

- [ ] **Step 2: Write the two fixtures**

`spec/fixtures/requirements_valid.json` = the requirements example from `docs/input-contract.md` (copy it verbatim).
`spec/fixtures/requirements_bad_id.json` = same, but change the first requirement's `id` to `"VENDOR-1"`.

- [ ] **Step 3: Run test to verify it fails**

Run: `cd harness/schema-design && bundle exec rspec spec/contracts_spec.rb`
Expected: FAIL — `uninitialized constant SchemaHarness::Contracts`.

- [ ] **Step 4: Implement `lib/schema_harness/contracts.rb`**

```ruby
module SchemaHarness
  module Contracts
    REQ_ID = /\AREQ-[A-Z0-9]+-\d{3}\z/
    TYPES  = %w[entity_exists attribute relationship constraint state_transition].freeze
    CARD   = %w[one_to_one one_to_many many_to_one many_to_many].freeze
    CKIND  = %w[not_null unique check range foreign_key].freeze

    module_function

    def validate_requirements(h)
      e = []
      %w[story_slug title domain requirements].each { |k| e << "missing #{k}" unless h.key?(k) }
      Array(h["requirements"]).each_with_index do |r, i|
        loc = "requirements[#{i}]"
        e << "#{loc}: id '#{r["id"]}' must match REQ-<DOMAIN>-NNN" unless r["id"].to_s =~ REQ_ID
        e << "#{loc}: unknown type '#{r["type"]}'" unless TYPES.include?(r["type"])
        e << "#{loc}: missing description" if r["description"].to_s.empty?
        case r["type"]
        when "relationship"
          e << "#{loc}: bad cardinality" unless CARD.include?(r["cardinality"])
          %w[from to].each { |k| e << "#{loc}: missing #{k}" if r[k].to_s.empty? }
        when "constraint"
          e << "#{loc}: bad constraint_kind" unless CKIND.include?(r["constraint_kind"])
        when "attribute"
          %w[entity name data_type].each { |k| e << "#{loc}: missing #{k}" if r[k].to_s.empty? }
        when "state_transition"
          e << "#{loc}: needs >=1 transition" if Array(r["transitions"]).empty?
        end
      end
      e
    end

    def validate_prd(h)
      e = []
      e << "missing stories" unless h["stories"].is_a?(Array)
      Array(h["stories"]).each_with_index do |s, i|
        %w[id slug title priority requirementsFile passes].each { |k| e << "stories[#{i}]: missing #{k}" unless s.key?(k) }
        e << "stories[#{i}]: priority must be Integer" unless s["priority"].is_a?(Integer)
      end
      e
    end

    def validate_coverage(h)
      e = []
      e << "missing mappings" unless h["mappings"].is_a?(Array)
      Array(h["mappings"]).each_with_index do |m, i|
        e << "mappings[#{i}]: missing requirement_id" if m["requirement_id"].to_s.empty?
        sb = m["satisfied_by"]
        e << "mappings[#{i}]: empty satisfied_by" if sb.nil? || sb.empty?
      end
      e
    end

    def validate_current_schema(h)
      e = []
      e << "missing tables" unless h["tables"].is_a?(Array)
      Array(h["tables"]).each_with_index do |t, i|
        e << "tables[#{i}]: missing name" if t["name"].to_s.empty?
        e << "tables[#{i}]: missing columns" unless t["columns"].is_a?(Array)
      end
      e
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd harness/schema-design && bundle exec rspec spec/contracts_spec.rb`
Expected: PASS (3 examples).

- [ ] **Step 6: Commit**

```bash
git add harness/schema-design/lib/schema_harness/contracts.rb harness/schema-design/spec/contracts_spec.rb harness/schema-design/spec/fixtures/
git commit -m "feat(harness): contract validators for requirements/prd/coverage/schema"
```

---

### Task 3: Dependency planner + `bin/plan`

**Files:**
- Create: `lib/schema_harness/planner.rb`
- Create: `bin/plan`
- Test: `spec/planner_spec.rb`

**Interfaces:**
- Consumes: a list of requirements hashes (each validated by Task 2), plus a story→domain/slug/title map.
- Produces: `SchemaHarness::Planner.order(stories) -> prd_hash`. `stories` is an array of `{slug:, title:, requirements:[...]}`. Builds the entity→owning-story map from `entity_exists` requirements, derives story→story edges from `relationship` requirements (the `from`-owning story depends on the `to`-owning story; `many_to_many` depends on both), topologically sorts with stdlib `TSort`, and assigns ascending `priority`. Cycles are broken deterministically (lowest slug first) and recorded in a returned `cycles` list.

- [ ] **Step 1: Write the failing test**

```ruby
# spec/planner_spec.rb
require_relative "../lib/schema_harness/planner"

RSpec.describe SchemaHarness::Planner do
  let(:vendors) { { slug: "vendors", title: "Vendors",
    requirements: [{ "type" => "entity_exists", "entity" => "Vendor" }] } }
  let(:postings) { { slug: "postings", title: "Postings", requirements: [
    { "type" => "entity_exists", "entity" => "JobPosting" },
    { "type" => "relationship", "from" => "JobPosting", "to" => "Vendor", "cardinality" => "many_to_one" }] } }

  it "orders a dependency before its dependent" do
    prd = described_class.order([postings, vendors])
    pr = prd["stories"].to_h { |s| [s["slug"], s["priority"]] }
    expect(pr["vendors"]).to be < pr["postings"]
  end

  it "records a cycle instead of raising" do
    a = { slug: "a", title: "A", requirements: [
      { "type" => "entity_exists", "entity" => "A" },
      { "type" => "relationship", "from" => "A", "to" => "B", "cardinality" => "many_to_one" }] }
    b = { slug: "b", title: "B", requirements: [
      { "type" => "entity_exists", "entity" => "B" },
      { "type" => "relationship", "from" => "B", "to" => "A", "cardinality" => "many_to_one" }] }
    prd = described_class.order([a, b])
    expect(prd["cycles"]).not_to be_empty
    expect(prd["stories"].map { |s| s["slug"] }).to contain_exactly("a", "b")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd harness/schema-design && bundle exec rspec spec/planner_spec.rb`
Expected: FAIL — `uninitialized constant SchemaHarness::Planner`.

- [ ] **Step 3: Implement `lib/schema_harness/planner.rb`**

```ruby
require "tsort"
require "set"

module SchemaHarness
  module Planner
    module_function

    def order(stories)
      owner = {} # entity => slug
      stories.each { |s| s[:requirements].each { |r| owner[r["entity"]] = s[:slug] if r["type"] == "entity_exists" } }

      deps = Hash.new { |h, k| h[k] = Set.new } # slug => set of slugs it depends on
      stories.each { |s| deps[s[:slug]] }
      stories.each do |s|
        s[:requirements].each do |r|
          next unless r["type"] == "relationship"
          targets = r["cardinality"] == "many_to_many" ? [r["from"], r["to"]] : [r["to"]]
          targets.each do |ent|
            dep = owner[ent]
            deps[s[:slug]] << dep if dep && dep != s[:slug]
          end
        end
      end

      cycles = []
      sorted = tsort(deps, cycles)
      prio = sorted.each_with_index.to_h { |slug, i| [slug, i + 1] }
      by_slug = stories.to_h { |s| [s[:slug], s] }

      {
        "branchName" => "schema-design",
        "stories" => stories.sort_by { |s| prio[s[:slug]] }.map { |s|
          { "id" => "us_#{s[:slug]}", "slug" => s[:slug], "title" => s[:title],
            "priority" => prio[s[:slug]],
            "requirementsFile" => "requirements/us_#{s[:slug]}.json", "passes" => false } },
        "cycles" => cycles
      }
    end

    # deterministic topo sort; on cycle, break at lowest-slug node and record it
    def tsort(deps, cycles)
      each_node = ->(&b) { deps.keys.sort.each(&b) }
      each_child = ->(n, &b) { deps[n].to_a.sort.each(&b) }
      begin
        TSort.tsort(each_node, each_child)
      rescue TSort::Cyclic => e
        node = e.message[/\["?(.+?)"?\]/, 1] || deps.keys.min
        broken = deps[node].min
        cycles << { "between" => [node, broken].compact }
        deps[node].delete(broken)
        retry
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd harness/schema-design && bundle exec rspec spec/planner_spec.rb`
Expected: PASS (2 examples).

- [ ] **Step 5: Write `bin/plan`**

```ruby
#!/usr/bin/env ruby
# Usage: bin/plan <workspace_dir>
require "json"
require_relative "../lib/schema_harness/planner"
require_relative "../lib/schema_harness/contracts"

ws = ARGV[0] or abort "usage: bin/plan <workspace_dir>"
files = Dir["#{ws}/requirements/us_*.json"].sort
abort "no requirements files in #{ws}/requirements" if files.empty?

stories = files.map do |f|
  h = JSON.parse(File.read(f))
  errs = SchemaHarness::Contracts.validate_requirements(h)
  abort "#{f}: #{errs.join("; ")}" unless errs.empty?
  { slug: h["story_slug"], title: h["title"], requirements: h["requirements"] }
end

prd = SchemaHarness::Planner.order(stories)
File.write("#{ws}/prd.json", JSON.pretty_generate(prd))
warn "wrote #{ws}/prd.json (#{prd["stories"].size} stories, #{prd["cycles"].size} cycles broken)"
```

- [ ] **Step 6: Make executable and smoke-test**

Run: `cd harness/schema-design && chmod +x bin/plan`
Expected: no output, exit 0.

- [ ] **Step 7: Commit**

```bash
git add harness/schema-design/lib/schema_harness/planner.rb harness/schema-design/bin/plan harness/schema-design/spec/planner_spec.rb
git commit -m "feat(harness): topological story planner and bin/plan"
```

---

### Task 4: Coverage checker (gate a) + `bin/check-coverage`

**Files:**
- Create: `lib/schema_harness/coverage.rb`
- Create: `bin/check-coverage`
- Test: `spec/coverage_spec.rb`

**Interfaces:**
- Consumes: a requirements hash, a coverage hash, and a `current.json` schema hash.
- Produces: `SchemaHarness::Coverage.check(requirements:, coverage:, schema:) -> [errors]`. Empty = pass. Fails if: any requirement id is unmapped; any mapping is empty; any mapped `satisfied_by` element does not exist in `schema` (table/column/enum/fk/index lookup).

- [ ] **Step 1: Write the failing test**

```ruby
# spec/coverage_spec.rb
require_relative "../lib/schema_harness/coverage"

RSpec.describe SchemaHarness::Coverage do
  let(:reqs) { { "requirements" => [
    { "id" => "REQ-V-001", "type" => "entity_exists", "entity" => "Vendor" },
    { "id" => "REQ-V-002", "type" => "attribute", "entity" => "Vendor", "name" => "status" }] } }
  let(:schema) { { "tables" => [
    { "name" => "vendors", "columns" => [{ "name" => "id" }, { "name" => "status" }] }] } }

  it "passes when every requirement maps to a real schema element" do
    cov = { "mappings" => [
      { "requirement_id" => "REQ-V-001", "satisfied_by" => { "kind" => "table", "name" => "vendors" } },
      { "requirement_id" => "REQ-V-002", "satisfied_by" => { "kind" => "column", "table" => "vendors", "name" => "status" } }] }
    expect(described_class.check(requirements: reqs, coverage: cov, schema: schema)).to eq([])
  end

  it "fails on an unmapped requirement" do
    cov = { "mappings" => [{ "requirement_id" => "REQ-V-001", "satisfied_by" => { "kind" => "table", "name" => "vendors" } }] }
    expect(described_class.check(requirements: reqs, coverage: cov, schema: schema)).to include(match(/REQ-V-002/))
  end

  it "fails on a mapping that points at a non-existent column" do
    cov = { "mappings" => [
      { "requirement_id" => "REQ-V-001", "satisfied_by" => { "kind" => "table", "name" => "vendors" } },
      { "requirement_id" => "REQ-V-002", "satisfied_by" => { "kind" => "column", "table" => "vendors", "name" => "ghost" } }] }
    expect(described_class.check(requirements: reqs, coverage: cov, schema: schema)).to include(match(/ghost/))
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd harness/schema-design && bundle exec rspec spec/coverage_spec.rb`
Expected: FAIL — `uninitialized constant SchemaHarness::Coverage`.

- [ ] **Step 3: Implement `lib/schema_harness/coverage.rb`**

```ruby
module SchemaHarness
  module Coverage
    module_function

    def check(requirements:, coverage:, schema:)
      e = []
      mapped = {}
      Array(coverage["mappings"]).each do |m|
        id = m["requirement_id"]
        sb = m["satisfied_by"]
        if sb.nil? || sb.empty?
          e << "mapping for #{id} is empty"
        else
          mapped[id] = sb
        end
      end

      Array(requirements["requirements"]).each do |r|
        id = r["id"]
        unless mapped.key?(id)
          e << "requirement #{id} is unmapped"
          next
        end
        e.concat(verify_element(mapped[id], schema, id))
      end
      e
    end

    def verify_element(sb, schema, id)
      tables = Array(schema["tables"])
      enums  = Array(schema["enums"])
      case sb["kind"]
      when "table"
        tables.any? { |t| t["name"] == sb["name"] } ? [] : ["#{id}: table '#{sb["name"]}' not in schema"]
      when "column"
        t = tables.find { |x| x["name"] == sb["table"] }
        return ["#{id}: table '#{sb["table"]}' not in schema"] unless t
        Array(t["columns"]).any? { |c| c["name"] == sb["name"] } ? [] : ["#{id}: column '#{sb["table"]}.#{sb["name"]}' not in schema"]
      when "enum"
        enums.any? { |x| x["name"] == sb["name"] } ? [] : ["#{id}: enum '#{sb["name"]}' not in schema"]
      when "constraint"
        t = tables.find { |x| x["name"] == sb["table"] }
        return ["#{id}: table '#{sb["table"]}' not in schema"] unless t
        Array(t["checks"]).any? { |c| c["name"] == sb["name"] } ? [] : ["#{id}: constraint '#{sb["name"]}' not in schema"]
      when "index"
        t = tables.find { |x| x["name"] == sb["table"] }
        return ["#{id}: table '#{sb["table"]}' not in schema"] unless t
        Array(t["indexes"]).any? { |c| Array(c["columns"]) == Array(sb["columns"]) } ? [] : ["#{id}: index on #{sb["columns"]} not in schema"]
      when "association"
        Array(schema["associations"]).any? { |a| a["from"] == sb["from"] && a["to"] == sb["to"] } ? [] : ["#{id}: association #{sb["from"]}->#{sb["to"]} not in schema"]
      else
        ["#{id}: unknown satisfied_by.kind '#{sb["kind"]}'"]
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd harness/schema-design && bundle exec rspec spec/coverage_spec.rb`
Expected: PASS (3 examples).

- [ ] **Step 5: Write `bin/check-coverage`**

```ruby
#!/usr/bin/env ruby
# Usage: bin/check-coverage <workspace_dir> <slug>   (exit 0 = covered, 1 = gaps)
require "json"
require_relative "../lib/schema_harness/coverage"

ws, slug = ARGV
abort "usage: bin/check-coverage <workspace_dir> <slug>" unless ws && slug
reqs   = JSON.parse(File.read("#{ws}/requirements/us_#{slug}.json"))
cov    = JSON.parse(File.read("#{ws}/us_#{slug}/coverage.json"))
schema = JSON.parse(File.read("#{ws}/schema/current.json"))

errors = SchemaHarness::Coverage.check(requirements: reqs, coverage: cov, schema: schema)
if errors.empty?
  warn "coverage OK for #{slug}"
  exit 0
else
  warn "COVERAGE GAPS for #{slug}:"
  errors.each { |x| warn "  - #{x}" }
  exit 1
end
```

- [ ] **Step 6: Make executable**

Run: `cd harness/schema-design && chmod +x bin/check-coverage`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add harness/schema-design/lib/schema_harness/coverage.rb harness/schema-design/bin/check-coverage harness/schema-design/spec/coverage_spec.rb
git commit -m "feat(harness): mechanical coverage gate and bin/check-coverage"
```

---

### Task 5: Schema renderer + `bin/render-schema`

**Files:**
- Create: `lib/schema_harness/renderer.rb`
- Create: `bin/render-schema`
- Test: `spec/renderer_spec.rb`

**Interfaces:**
- Consumes: a `current.json` schema hash.
- Produces: `SchemaHarness::Renderer.to_markdown(schema) -> String` and `.to_mermaid(schema) -> String`. The markdown lists each table with columns/types/null/PK, indexes, FKs, checks, and enums. The mermaid is an `erDiagram` with one entity per table and one relationship line per association.

- [ ] **Step 1: Write the failing test**

```ruby
# spec/renderer_spec.rb
require_relative "../lib/schema_harness/renderer"

RSpec.describe SchemaHarness::Renderer do
  let(:schema) { { "tables" => [
    { "name" => "vendors", "columns" => [
      { "name" => "id", "type" => "uuid", "null" => false, "primary_key" => true },
      { "name" => "status", "type" => "enum", "null" => false }],
      "foreign_keys" => [{ "column" => "org_id", "references" => "organizations", "on_delete" => "restrict" }] }],
    "associations" => [{ "from" => "vendors", "to" => "organizations", "kind" => "belongs_to" }] } }

  it "renders a markdown table section" do
    md = described_class.to_markdown(schema)
    expect(md).to include("vendors").and include("status").and include("uuid")
  end

  it "renders a mermaid erDiagram with the relationship" do
    mmd = described_class.to_mermaid(schema)
    expect(mmd).to start_with("erDiagram")
    expect(mmd).to include("vendors").and include("organizations")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd harness/schema-design && bundle exec rspec spec/renderer_spec.rb`
Expected: FAIL — `uninitialized constant SchemaHarness::Renderer`.

- [ ] **Step 3: Implement `lib/schema_harness/renderer.rb`**

```ruby
module SchemaHarness
  module Renderer
    module_function

    def to_markdown(schema)
      out = ["# Current Schema\n"]
      Array(schema["enums"]).each { |e| out << "**enum `#{e["name"]}`**: #{Array(e["values"]).join(", ")}\n" }
      Array(schema["tables"]).each do |t|
        out << "## #{t["name"]}\n"
        out << "| column | type | null | pk |"
        out << "|---|---|---|---|"
        Array(t["columns"]).each do |c|
          out << "| #{c["name"]} | #{c["type"]} | #{c["null"] == false ? "NO" : "yes"} | #{c["primary_key"] ? "PK" : ""} |"
        end
        Array(t["foreign_keys"]).each { |fk| out << "\n- FK `#{fk["column"]}` → `#{fk["references"]}` (on_delete: #{fk["on_delete"]})" }
        Array(t["checks"]).each { |ck| out << "- CHECK `#{ck["name"]}`: `#{ck["expression"]}`" }
        out << ""
      end
      out.join("\n")
    end

    def to_mermaid(schema)
      lines = ["erDiagram"]
      Array(schema["tables"]).each do |t|
        lines << "  #{t["name"]} {"
        Array(t["columns"]).each { |c| lines << "    #{c["type"]} #{c["name"]}" }
        lines << "  }"
      end
      Array(schema["associations"]).each do |a|
        lines << "  #{a["to"]} ||--o{ #{a["from"]} : \"#{a["kind"]}\""
      end
      lines.join("\n")
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd harness/schema-design && bundle exec rspec spec/renderer_spec.rb`
Expected: PASS (2 examples).

- [ ] **Step 5: Write `bin/render-schema`**

```ruby
#!/usr/bin/env ruby
# Usage: bin/render-schema <workspace_dir>
require "json"
require_relative "../lib/schema_harness/renderer"

ws = ARGV[0] or abort "usage: bin/render-schema <workspace_dir>"
schema = JSON.parse(File.read("#{ws}/schema/current.json"))
File.write("#{ws}/schema/current.md",  SchemaHarness::Renderer.to_markdown(schema))
File.write("#{ws}/schema/current.mmd", SchemaHarness::Renderer.to_mermaid(schema))
warn "rendered #{ws}/schema/current.md and current.mmd"
```

- [ ] **Step 6: Make executable and run full suite**

Run: `cd harness/schema-design && chmod +x bin/render-schema && bundle exec rspec`
Expected: PASS (all examples from Tasks 2–5).

- [ ] **Step 7: Commit**

```bash
git add harness/schema-design/lib/schema_harness/renderer.rb harness/schema-design/bin/render-schema harness/schema-design/spec/renderer_spec.rb
git commit -m "feat(harness): schema renderer (markdown + mermaid) and bin/render-schema"
```

---

### Task 6: (R) `extract-requirements` skill

**Files:**
- Create: `skills/extract-requirements/SKILL.md`
- Create: `workspace/input/stories/us_sample-vendor.md` (acceptance fixture)

**Interfaces:**
- Consumes: `workspace/input/stories/us_<slug>.md` (Task 1 contract), `workspace/input/prd.md` + `input/context/*` (advisory).
- Produces: `workspace/requirements/us_<slug>.json` (one per story, stable IDs) for every story, then runs `bin/plan` to emit `workspace/prd.json`. This is a prompt-driven step; its acceptance test asserts output **validity and stability**, not exact prose.

- [ ] **Step 1: Write the acceptance fixture story** `workspace/input/stories/us_sample-vendor.md`

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

- [ ] **Step 2: Write `skills/extract-requirements/SKILL.md`**

````markdown
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
````

- [ ] **Step 3: Acceptance run**

Invoke the skill against the workspace (manually, or via your agent). Then verify the output:

Run: `cd harness/schema-design && ruby -r./lib/schema_harness/contracts -e 'require "json"; errs = SchemaHarness::Contracts.validate_requirements(JSON.parse(File.read("workspace/requirements/us_sample-vendor.json"))); abort errs.join("; ") unless errs.empty?; puts "valid"' && test -f workspace/prd.json && echo "prd ok"`
Expected: `valid` then `prd ok`.

- [ ] **Step 4: Stability check (IDs frozen on re-run)**

Run the skill a second time, then:
Run: `cd harness/schema-design && git diff --stat workspace/requirements/us_sample-vendor.json`
Expected: no changes to existing requirement IDs (diff empty or additions only).

- [ ] **Step 5: Commit**

```bash
git add harness/schema-design/skills/extract-requirements/SKILL.md harness/schema-design/workspace/input/stories/us_sample-vendor.md
git commit -m "feat(harness): extract-requirements skill (R) with input contract"
```

---

### Task 7: (A) `design-feature-schema` skill

**Files:**
- Create: `skills/design-feature-schema/SKILL.md`

**Interfaces:**
- Consumes: `workspace/schema/current.json` (cumulative SoT, may be empty `{"tables":[],"enums":[],"associations":[]}` on first run), `workspace/schema-conventions.md` (the finalized style guide), `workspace/requirements/us_<slug>.json` for the target story.
- Produces: an updated `workspace/schema/current.json` (delta merged), `workspace/us_<slug>/coverage.json`, `workspace/us_<slug>/schema.md` (rationale + delta + rendered coverage matrix), and regenerated `current.md`/`current.mmd` via `bin/render-schema`. Designed so the Task 4 coverage checker passes.

- [ ] **Step 1: Write `skills/design-feature-schema/SKILL.md`**

````markdown
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
````

- [ ] **Step 2: Acceptance run (first story, empty schema)**

Initialize and run against the sample story:
Run: `cd harness/schema-design && mkdir -p workspace/schema && echo '{"tables":[],"enums":[],"associations":[]}' > workspace/schema/current.json`
Then invoke the skill for slug `sample-vendor`. Then verify the gate:
Run: `cd harness/schema-design && bin/check-coverage workspace sample-vendor`
Expected: exit 0, `coverage OK for sample-vendor`.

- [ ] **Step 3: Conventions adherence spot-check**

Run: `cd harness/schema-design && ruby -e 'require "json"; s=JSON.parse(File.read("workspace/schema/current.json")); cols=s["tables"].flat_map{|t| t["columns"]}; abort "float money found" if cols.any?{|c| c["type"]=="float"}; pk=s["tables"].flat_map{|t| t["columns"].select{|c| c["primary_key"]}}; abort "non-uuid PK" unless pk.all?{|c| c["type"]=="uuid"}; puts "conventions ok"'`
Expected: `conventions ok` (no float money, UUID PKs — per `schema-conventions.md`).

- [ ] **Step 4: Commit**

```bash
git add harness/schema-design/skills/design-feature-schema/SKILL.md
git commit -m "feat(harness): design-feature-schema skill (A)"
```

---

### Task 8: `verify-schema-delta` skill (gate b — adversarial verifier)

**Files:**
- Create: `skills/verify-schema-delta/SKILL.md`
- Create: `workspace/fixtures/verifier_bad_float.json` (a deliberately bad delta for the negative test)

**Interfaces:**
- Consumes: target slug, `workspace/requirements/us_<slug>.json`, `workspace/us_<slug>/coverage.json`, `workspace/schema/current.json`, `workspace/schema-conventions.md`.
- Produces: `workspace/us_<slug>/verdict.json` = `{ "verdict": "pass"|"fail", "findings": [ { "severity": "...", "requirement_id": "...", "issue": "..." } ] }`. Fails on: a requirement the schema cannot actually represent; a delta that duplicates/contradicts the cumulative schema (redefined table, type mismatch on a shared column); or an integrity-baseline violation even if a dash-api pattern endorses it.

- [ ] **Step 1: Write `skills/verify-schema-delta/SKILL.md`**

````markdown
---
name: verify-schema-delta
description: Adversarial gate (b) for the Ralph loop. Try to BREAK a story's schema design — find an unrepresentable requirement, a contradiction with the cumulative schema, or an integrity-baseline violation — and emit a pass/fail verdict.
---

# Verify Schema Delta (gate b)

You are an adversarial reviewer. Your DEFAULT stance is suspicion: assume the design is wrong until
you have checked each angle. Given a slug:

## Inputs
- `workspace/requirements/us_<slug>.json`, `workspace/us_<slug>/coverage.json`
- `workspace/schema/current.json`, `workspace/schema-conventions.md`

## Checks (run ALL; each can produce findings)
1. **Representability** — for every requirement, can the cited `satisfied_by` element actually
   represent it? (e.g. a `state_transition` needs a status column whose enum includes every named
   state; a `constraint` needs a real CHECK/UNIQUE/FK, not just a column.)
2. **Consistency vs cumulative schema** — does the delta redefine an existing table, contradict an
   existing column's type, or duplicate an entity that already has a home under another name?
3. **Integrity baseline** — flag ANY: float for money/rates; a non-polymorphic reference lacking a
   DB-level FK; a required field left nullable; a natural key without a unique index; `json` instead
   of `jsonb`. These FAIL even if `pattern-catalog.md` shows dash-api does it (style defers to
   patterns; integrity defers to baseline).

## Output
Write `workspace/us_<slug>/verdict.json`:
```json
{ "verdict": "pass", "findings": [] }
```
or, with findings, `"verdict": "fail"` and one entry per problem:
`{ "severity": "integrity|consistency|representability", "requirement_id": "REQ-… or null", "issue": "…" }`

Output `"pass"` ONLY if findings is empty. Be specific and cite table/column names.
````

- [ ] **Step 2: Write the negative fixture** `workspace/fixtures/verifier_bad_float.json`

```json
{ "tables": [ { "name": "rates",
  "columns": [ { "name": "id", "type": "uuid", "null": false, "primary_key": true },
               { "name": "amount", "type": "float", "null": false } ] } ],
  "enums": [], "associations": [] }
```

- [ ] **Step 3: Negative acceptance — verifier must FAIL a float-money schema**

Temporarily point the verifier at the bad fixture (copy it in), invoke the skill, then:
Run: `cd harness/schema-design && ruby -e 'require "json"; v=JSON.parse(File.read("workspace/us_sample-vendor/verdict.json")); abort "expected fail" unless v["verdict"]=="fail"; abort "expected integrity finding" unless v["findings"].any?{|f| f["severity"]=="integrity"}; puts "verifier correctly failed float money"'`
Expected: `verifier correctly failed float money`.

- [ ] **Step 4: Positive acceptance — verifier must PASS the real design**

Restore the real `current.json` from Task 7, invoke the verifier for `sample-vendor`, then:
Run: `cd harness/schema-design && ruby -e 'require "json"; v=JSON.parse(File.read("workspace/us_sample-vendor/verdict.json")); abort "expected pass, got #{v["verdict"]}: #{v["findings"]}" unless v["verdict"]=="pass"; puts "verifier passed clean design"'`
Expected: `verifier passed clean design`.

- [ ] **Step 5: Commit**

```bash
git add harness/schema-design/skills/verify-schema-delta/SKILL.md harness/schema-design/workspace/fixtures/verifier_bad_float.json
git commit -m "feat(harness): adversarial verify-schema-delta skill (gate b)"
```

---

### Task 9: Ralph wiring

**Files:**
- Create: `ralph/CLAUDE.md`
- Create: `ralph/ralph.sh`

**Interfaces:**
- Consumes: `workspace/prd.json` (from Task 6), all three skills, `bin/check-coverage`.
- Produces: the per-iteration prompt (`CLAUDE.md`) and loop driver (`ralph.sh`). Each iteration designs the highest-priority `passes:false` story, runs both gates, and on success commits + marks `passes:true` + appends to `progress.txt`; emits `<promise>COMPLETE</promise>` when all stories pass.

- [ ] **Step 1: Write `ralph/CLAUDE.md`** (the per-iteration prompt)

````markdown
# Ralph iteration — schema design

You are one fresh iteration. Do exactly ONE story, then stop.

1. Read `workspace/prd.json`. If every story has `"passes": true`, output `<promise>COMPLETE</promise>`
   and stop. Otherwise pick the story with the LOWEST `priority` where `"passes": false`.
2. Read `workspace/progress.txt` (if present) for prior learnings.
3. Invoke the **design-feature-schema** skill for that story's `slug`.
4. Run the gates:
   - `bin/check-coverage workspace <slug>` — must exit 0.
   - Invoke the **verify-schema-delta** skill for `<slug>`; read `workspace/us_<slug>/verdict.json` —
     `"verdict"` must be `"pass"`.
5. If BOTH gates pass:
   - Append a dated learnings line to `workspace/progress.txt`.
   - Set that story's `"passes": true` in `workspace/prd.json`.
   - Commit: `git add -A && git commit -m "schema: design <slug>"`.
6. If EITHER gate fails: do NOT commit, do NOT mark passes. Append the failure (and any flagged
   requirement gap) to `workspace/progress.txt` and stop so the next iteration retries with that note.
7. Never edit `workspace/requirements/*.json` (frozen). Never hand-edit `current.md`/`current.mmd`
   (rendered).
````

- [ ] **Step 2: Write `ralph/ralph.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."   # harness/schema-design
MAX="${1:-50}"
for i in $(seq 1 "$MAX"); do
  echo "=== Ralph iteration $i ==="
  out="$(claude -p "$(cat ralph/CLAUDE.md)" --dangerously-skip-permissions 2>&1)" || true
  echo "$out"
  if echo "$out" | grep -q "<promise>COMPLETE</promise>"; then
    echo "All stories passed. Done."; exit 0
  fi
done
echo "Reached MAX=$MAX iterations without COMPLETE."; exit 1
```

(Adjust the `claude -p …` invocation to match your installed agent CLI; the contract is: feed
`ralph/CLAUDE.md` as the prompt, fresh context each call.)

- [ ] **Step 3: Make executable and dry-run the stop condition**

Mark all sample stories passed and confirm the loop exits immediately:
Run: `cd harness/schema-design && chmod +x ralph/ralph.sh && ruby -e 'require "json"; p=JSON.parse(File.read("workspace/prd.json")); p["stories"].each{|s| s["passes"]=true}; File.write("workspace/prd.json", JSON.pretty_generate(p))' && grep -q COMPLETE ralph/CLAUDE.md && echo "stop-condition wired"`
Expected: `stop-condition wired`.

- [ ] **Step 4: Full-suite regression**

Run: `cd harness/schema-design && bundle exec rspec`
Expected: PASS (all examples, Tasks 2–5).

- [ ] **Step 5: Commit**

```bash
git add harness/schema-design/ralph/CLAUDE.md harness/schema-design/ralph/ralph.sh
git commit -m "feat(harness): Ralph wiring (per-iteration prompt + loop driver)"
```

---

## Self-Review

**Spec coverage:**
- (R) requirements extractor + frozen IDs + dependency planner → Tasks 3, 6. ✓
- Coverage gate (a) mechanical → Task 4. ✓
- Adversarial verifier (b) → Task 8. ✓
- (A) design-feature-schema + cumulative `current.json` source of truth + delta merge → Task 7. ✓
- `schema-conventions.md` as static context + integrity-vs-style precedence → Tasks 7 (apply) + 8 (enforce). ✓
- Topological ordering into `prd.json` priority → Task 3. ✓
- Ralph integration (no fork; gates = quality checks; `progress.txt`; COMPLETE) → Task 9. ✓
- (B) is setup, already done → not a build task (correct, per revised spec). ✓

**Placeholder scan:** No "TBD"/"handle edge cases"/"similar to Task N". Each code step shows full code; each skill step shows full SKILL.md. ✓

**Type consistency:** `validate_requirements`/`validate_prd`/`validate_coverage`/`validate_current_schema` (Task 2) are reused by name in Tasks 3–4 CLIs. `Planner.order`, `Coverage.check(requirements:, coverage:, schema:)`, `Renderer.to_markdown`/`to_mermaid` signatures match between definition and callers. `satisfied_by.kind` vocabulary matches between input-contract (Task 1), Coverage.verify_element (Task 4), and the (A) skill (Task 7). `verdict.json` shape matches between Task 8 definition and Task 9 consumption. ✓

## Known follow-ups (out of scope for this plan)
- Real PRD → `input/stories/*.md` adapter (depends on your actual PRD source format).
- Multi-vote adversarial verification (N skeptics) if single-verifier proves too lenient in practice.
- `.gitignore` policy for `workspace/` per consuming project.
