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
