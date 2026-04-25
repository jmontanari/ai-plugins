# Migration notes — v2 → v3.0.0

## Files moved
- docs/prd/manifest.yaml → docs/prds/shared/manifest.yaml
- docs/prd/prd.md → docs/prds/shared/prd.md
- docs/specs/PI-007-copilot-coship/ → docs/prds/shared/specs/PI-007-copilot-coship/
- docs/specs/PI-008-multi-prd-v3.0.0/ → docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/
- docs/specs/spec-flow-v2.0.0/ → docs/prds/shared/specs/spec-flow-v2.0.0/

## Stale internal references (manual review)
- README.md:127: ./docs/specs/PI-007-copilot-coship/learnings.md
- README.md:156: docs/prd/manifest.yaml
- plugins/spec-flow/README.md:117: docs/prd/, docs/specs/<piece>/, docs/manifest.yaml (intentional — describes legacy v1.x/v2.x layout being migrated from)
- plugins/spec-flow/README.md:123: docs/prd/ (intentional — describes pre-migration source path)
- plugins/spec-flow/README.md:132: git mv docs/prd/ ... (intentional — illustrates migration mechanics)
- plugins/spec-flow/README.md:133: git mv docs/specs/ ... (intentional — illustrates migration mechanics)

## .spec-flow.yaml note
- `.spec-flow.yaml` is gitignored in this repo and was edited locally to add `layout_version: 3` immediately after `worktrees_root:`. This edit is **not** part of the migration commit. If `.spec-flow.yaml` is auto-regenerated at session start by a hook, ensure the source/template that produces it carries `layout_version: 3`, otherwise the bump will silently revert.

## What to do next
- Review stale references above; rewrite as needed (no automatic rewrite to keep migration scope minimal). The README.md root references at lines 127 and 156 point to real moved paths and should be updated to `docs/prds/shared/specs/...` and `docs/prds/shared/manifest.yaml`. The `plugins/spec-flow/README.md` references describe the migration itself and are likely intended to remain unchanged.
- Verify `git log --follow docs/prds/shared/prd.md` shows pre-migration history.
- Delete this MIGRATION_NOTES.md once you've completed the manual review.
