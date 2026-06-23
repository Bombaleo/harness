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
