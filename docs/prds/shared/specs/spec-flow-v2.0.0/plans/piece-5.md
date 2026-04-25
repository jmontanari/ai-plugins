# v2.0.0 Piece 5 — Update Mode + Divergence Resolution

**Goal:** Implement the charter skill's **update mode** (previously no-op'd with a "deferred" message), and add a formal **divergence resolution flow** users can invoke on diverged pieces.

**Architecture:** Update mode is a scoped re-run of the Socratic flow — user picks which file(s) to edit, skill runs targeted Socratic, QA re-runs on touched files only. Divergence resolution is a lightweight skill integration in `status` that, when a user runs `/spec-flow:status --resolve <piece>` (new flag), walks them through three options per diverged file.

**Scope fence:**
- Retrofit mode stays deferred to piece 6
- No automated re-spec / re-plan runners (user invokes spec/plan skills themselves after accepting divergence)

## Files

- Modify: `plugins/spec-flow/skills/charter/SKILL.md` (implement update mode, remove deferred message)
- Modify: `plugins/spec-flow/skills/status/SKILL.md` (add `--resolve <piece>` flag)
- Modify: `plugins/spec-flow/CHANGELOG.md`

## Tasks

1. **Update mode in charter skill:**
   - Detect trigger: `docs/charter/` exists, user invokes plain `/spec-flow:charter` OR with `--update`
   - List files, ask which to edit
   - For each selected file, run scoped Socratic (re-use Phase 2 questions applicable to that file's subject area)
   - Auto-detect retired-entry cases: if user removes an NN-C or CR entry, ask "retire (tombstone) or delete (removes all trace)?" — retire is default and recommended
   - Write updated file, bump `last_updated` to today's date
   - Dispatch `qa-charter` with `Input Mode: Full` on touched files (small context — no need for focused mode since only touched files reviewed)
   - Human sign-off
   - Per-file commit
2. **Divergence resolution in status skill:**
   - New flag `/spec-flow:status --resolve <piece-name>` walks user through each diverged charter file
   - Per-file, three options:
     - **Re-spec:** dispatch `spec` skill targeted to update the piece's citations for that file
     - **Re-plan:** dispatch `plan` skill to update phase allocations
     - **Accept:** write a paragraph into the piece's `spec.md` under a new `### Accepted Charter Divergence` section documenting why the divergence is acceptable
   - Update `charter_snapshot` in spec.md (re-spec and accept options) or plan.md (re-plan option) to current date after resolution
3. CHANGELOG piece 5 entry.
4. Single commit covering both skill files + CHANGELOG.
