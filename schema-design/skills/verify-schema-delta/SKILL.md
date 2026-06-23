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
