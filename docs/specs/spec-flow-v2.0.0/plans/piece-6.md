# v2.0.0 Piece 6 — Retrofit Mode + Migration Pipeline

**Goal:** Implement retrofit mode in the charter skill — a nine-step commit-per-step migration pipeline for pre-charter projects (v1.5.x and earlier).

**Architecture:** Pure additions to `skills/charter/SKILL.md` (retrofit section) and `skills/prd/SKILL.md` (legacy detection hint points at retrofit). Dry-run flag + opt-out flag. No destructive commands anywhere; `git mv` preserves history; pre-state snapshot is the backstop.

**Scope fence:**
- Automated divergence resolution runners stay in backlog
- Cross-piece retirement impact analysis stays in backlog
- Stale-reference detector stays in backlog

## Files

- Modify: `plugins/spec-flow/skills/charter/SKILL.md` (implement retrofit mode; replace current "deferred" line)
- Modify: `plugins/spec-flow/skills/prd/SKILL.md` (update legacy detection hint to say "run /spec-flow:charter --retrofit")
- Modify: `plugins/spec-flow/CHANGELOG.md`

## Tasks

1. Replace the charter skill's retrofit "deferred" line with the full nine-step pipeline from spec §10.
2. Document the dry-run flag (`/spec-flow:charter --retrofit --dry-run`) and opt-out flag (`/spec-flow:charter --decline`).
3. Document mapping table persistence (`docs/archive/pre-charter-migration-<date>/nn-mapping.md`).
4. Document retired-citation escalation during step 6 (per-piece spec rewrite).
5. Update `prd` skill's legacy-detect hint to say run retrofit (piece 6 is now live).
6. CHANGELOG piece 6 entry.
7. Single commit.
