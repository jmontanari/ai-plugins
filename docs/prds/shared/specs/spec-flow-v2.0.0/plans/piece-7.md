# v2.0.0 Piece 7 — README + Full CHANGELOG + Diagrams + Version Bump

**Goal:** Finalize the v2.0.0 release. Bump `plugin.json` to 2.0.0, consolidate the six `2.0.0-piece.N` CHANGELOG entries into a single `## [2.0.0]` section, and update README with charter stage, new layout, two-namespace NN model, and updated pipeline diagrams.

## Files

- Modify: `plugins/spec-flow/.claude-plugin/plugin.json` (version 1.5.0 → 2.0.0)
- Modify: `plugins/spec-flow/CHANGELOG.md` (consolidate piece entries)
- Modify: `plugins/spec-flow/README.md` (charter stage, new layout, NN namespaces, updated diagram)

## Tasks

1. Bump version in `plugin.json` to `2.0.0`.
2. Consolidate the six `[2.0.0-piece.N]` CHANGELOG entries into a single `## [2.0.0]` entry grouped by Added / Changed / Migration / Deprecated.
3. Update README sections:
   - Plugin structure diagram (add `skills/charter/`, `templates/charter/`, `agents/qa-charter.md`)
   - Pipeline chain diagram (add `charter` stage at the top before `prd`)
   - `docs/` layout description (new structure + NN-C/NN-P/CR namespaces + charter files)
   - New section: "Charter stage" explaining the three modes
   - New section: "Non-negotiables: two namespaces" explaining NN-C vs NN-P
4. Single commit covering all three files.
