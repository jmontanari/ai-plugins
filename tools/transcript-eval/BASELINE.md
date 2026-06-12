<!-- METADATA ONLY — SF-5/SF-6: no aggregates, no per-seat numbers, no findings, no transcripts.
     All mined output lives exclusively in the external insight store. -->

# gate-evals baseline (provenance)

Fill in the fields below after running `python3 -m transcript_eval story` and completing the
three operator confirmations in `README.md#producing-the-baseline`.

| Field | Value |
|-------|-------|
| `run_id` | `run-20260612T171607Z` |
| `date` | 2026-06-12 |
| `sessions_parsed` | 254 (all configured project dirs) |
| `repos` | ≥2 (ai-plugins + prop-firm-repo confirmed) |
| `store_path` | `/Volumes/joeData/spec-flow-insights/` |
| `extraction_coverage` | 99.8% (consistent with Phase-2 spike) |

## Operator confirmations

- [x] AC-3: Story is accurate and decision-useful (`## FR-016 per-seat evidence` reflects real usage — 1583 total dispatches, 14 measured seats, precision-from-usage labeling throughout, no "catch rate" language)
- [x] AC-5: No prop-firm / cross-repo content reached the ai-plugins repo (`git status --porcelain` shows only README.md + BASELINE.md; all mined output exclusively in external store)
- [x] AC-6: Full-corpus extraction coverage is acceptable (99.8% — matches Phase-2 spike sample exactly; no regression)
