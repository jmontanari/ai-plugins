# v2.0.0 Piece 3 — Downstream Skill Charter Wiring

**Goal:** Teach the five downstream skills (`prd`, `spec`, `plan`, `execute`, `status`) to read charter files, enumerate NN-C/NN-P/CR, capture `charter_snapshot`, enforce `charter.required`, and (for `status`) surface charter presence + divergence.

**Backward compat strategy:** Reads support BOTH new layout (`docs/prd/prd.md`) and legacy flat layout (`docs/prd.md`) — whichever exists. Writes default to new layout for new projects. Retrofit (piece 6) will migrate existing projects formally. This keeps v1.5.x projects working until they choose to retrofit.

**Architecture:** Pure markdown edits to five SKILL.md files.

## Files

- Modify: `plugins/spec-flow/skills/prd/SKILL.md`
- Modify: `plugins/spec-flow/skills/spec/SKILL.md`
- Modify: `plugins/spec-flow/skills/plan/SKILL.md`
- Modify: `plugins/spec-flow/skills/execute/SKILL.md`
- Modify: `plugins/spec-flow/skills/status/SKILL.md`
- Modify: `plugins/spec-flow/CHANGELOG.md`

## Piece 3 scope fence

- No agent file changes (piece 4)
- No update mode / divergence implementation in charter skill (piece 5)
- No retrofit-mode implementation in charter skill (piece 6) — prd skill still includes a detection note pointing users to `/spec-flow:charter --retrofit` but does not itself run the migration

## Tasks (concise)

1. **`prd`:** Add charter prereq check. If `charter.required: true` and `docs/charter/` missing → tell user to run `/spec-flow:charter` first. Detect legacy layout; if found, suggest retrofit. Write `prd.md` + `manifest.yaml` to `docs/prd/` on new bootstraps.
2. **`spec`:** Phase 1 loads `docs/charter/` (all six files). Phase 1 scans both `docs/charter/non-negotiables.md` (NN-C) and `docs/prd/prd.md` (or legacy `docs/prd.md`) (NN-P). Phase 2 adds a step to enumerate NN/CR touched by this piece. Phase 3 writes spec with `charter_snapshot` front-matter. Phase 4 QA prompt includes charter files.
3. **`plan`:** Exploration reads `docs/charter/`. Each phase's charter-constraints slot auto-populated during plan generation. Plan written with `charter_snapshot` front-matter. QA prompt includes charter.
4. **`execute`:** `qa-phase` prompt interpolates charter entries cited in the phase block. Review-board architecture reviewer receives full charter context. Spec-compliance reviewer verifies spec's NN/CR claims are honored in the diff.
5. **`status`:** Add top-line `charter: present (last_updated YYYY-MM-DD)` indicator. Per-piece divergence flag when any charter file `last_updated` > the piece's `charter_snapshot` date.
6. CHANGELOG piece 3 entry.
7. Single commit covering all changes.

## Self-review checklist

- All five skills read from `docs/charter/` using config's `docs_root` (not hardcoded)
- Legacy `docs/prd.md` still works — no hard break
- `charter.required: true` enforcement is gated to the `prd` skill bootstrap step only (spec/plan don't re-check; they just read charter if it exists)
- `charter_snapshot` front-matter captured at both spec write time and plan write time, using each charter file's `last_updated` value at that moment
- Divergence flag in `status` is informational only — no piece blocking
