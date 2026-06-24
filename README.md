# Harness

A home for **Ralph-compatible harness agents** — self-contained automation
harnesses that package a task as a [Ralph](https://github.com/snarktank/ralph)
autonomous loop (fresh context per iteration, machine-checked "done", commit on
pass).

## Harnesses

| Harness | What it does |
|---------|--------------|
| [`schema-design/`](schema-design/README.md) | Turns a PRD + per-story test scenarios into a cumulative, RoR-aware **database schema design** (not runnable migrations), verified against test-derived requirements by two machine gates. |

## What is a harness agent here

A harness agent is a directory that bundles everything Ralph needs to run a
specific task unchanged:

- a **per-iteration prompt** (`ralph/CLAUDE.md`) and a **driver** (`ralph/ralph.sh`),
- the **skills** the iteration invokes,
- a **machine-checkable gate** so a story only flips to `passes: true` on
  verifiable evidence, never on the model's say-so,
- a **cumulative state artifact** that survives across fresh-context iterations,
- and a `workspace/` holding the run's inputs and outputs.

The harness deliberately does its work in design/document form so it is
review-friendly and does not require a live target system to run against.

## Adding a new harness

New harnesses are **sibling directories** of `schema-design/`. Give each its own
`ralph/`, skills, gate, and `workspace/`, plus a `README.md`, then add a row to
the table above.
