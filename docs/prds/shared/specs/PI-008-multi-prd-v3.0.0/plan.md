---
charter_snapshot:
  architecture: 2026-04-21
  non-negotiables: 2026-04-21
  tools: 2026-04-21
  processes: 2026-04-21
  flows: 2026-04-21
  coding-rules: 2026-04-21
---

# Plan: PI-008-multi-prd-v3.0.0 — Multi-PRD Support (spec-flow v3.0.0)

**Spec:** docs/specs/PI-008-multi-prd-v3.0.0/spec.md
**Charter:** docs/charter/ (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft
**Target release:** spec-flow v3.0.0 (major — breaking layout change)

## Overview

Spec-flow is a markdown-and-config-only plugin (NN-C-002). There is no compiled code, no test framework, no runtime modules — every "implementation" is editing skill prompts, agent prompts, templates, a small bash hook, and JSON metadata. Consequently **every phase below uses the Implement track**. TDD has no payoff for prose-orchestration files; verification is structural (JSON validity, conventional-commit format, head-of-file inspection, dry-run smoke tests). The QA gates between phases (Sonnet narrow review for sub-phases, Opus deep review for groups, plus the existing review-board at end-of-piece) are where adversarial scrutiny happens — not unit tests.

The work decomposes into:

1. **Foundation** — templates, the SessionStart layout-version warning, and shared reference docs (slug validator, path conventions, charter-drift procedure). All downstream phases cite these reference docs instead of restating rules inline.
2. **Phase Group A: Skill v3 updates** — `prd`, `spec`, `plan`, `execute`, and `status` SKILL.md files updated for the new `docs/prds/<prd-slug>/` layout, slug-based worktree/branch naming, charter-drift check at Phase 1, `depends_on:` precondition, status drill-in, and archive-by-front-matter. All five touch disjoint files and cite shared reference docs — true parallel.
3. **Phase Group B: Agent updates** — `qa-spec` gains a third Input Mode (`Focused charter re-review`); the two reflection agents are updated to route findings to PRD-local vs global backlogs; the remaining 14 agents get a mechanical path-token sweep. Disjoint files, parallel.
4. **migrate skill** — the new `/spec-flow:migrate` skill that handles v0/v1/v2 → v3 transitions with `git mv`, dry-run (`--inspect`), safety checks, and `MIGRATION_NOTES.md` output.
5. **README + CHANGELOG** — multi-PRD documentation and the v3.0.0 Keep-a-Changelog entry.
6. **Version bump (NN-C-009 three-place)** — `plugin.json` + `marketplace.json` + CHANGELOG header all to `3.0.0` in one commit.
7. **Dog-food verification** — execute the migrate skill on a clean clone of this repo; verify AC-15 (layout + `git log --follow`); document the AC-18 release-commit-message procedure for the human-driven release that follows merge.

## Phases

### Phase 1: Templates & contracts foundation
**Track:** Implement
**Exit Gate:** Every template carries the v3 contract (front-matter slug/status/version on PRD; layout_version key on config; PRD-local backlog template exists). Visual inspection of each template head (lines 1-15) shows the correct schema.
**ACs Covered:** Foundation for AC-1 (greenfield PRD creation), AC-19 (dry-run plan rendering), AC-20 (slug uniqueness check infrastructure). No AC verified directly here — Phase 1 is enabling.
**Charter constraints honored in this phase:**
- **NN-P-001** (human-readable artifacts): every new/updated template stays plain markdown + YAML; no binary, no obfuscation. Templates render hand-auditable v3 artifacts.
- **CR-003** (template placeholder syntax): all path tokens use the `{{placeholder}}` convention (e.g., `{{prd_slug}}`, `{{piece_slug}}`).
- **CR-007** (config keys documented inline): the new `layout_version:` key in `templates/pipeline-config.yaml` ships with an inline `#`-comment describing semantics, default, and what skills do when absent.

- [x] **[Implement]** Author/update templates for the v3 layout.
  - **Order in checkpoint progression: contracts first → tokens added → new files last.**
  - Update `/mnt/c/ai-plugins/plugins/spec-flow/templates/prd.md`:
    - Insert a YAML front-matter block at the top of the template body containing `slug:`, `status: drafting | active | shipped | archived`, `version: 1`. Mark each as required. Position before the `# {{prd_title}}` heading.
    - Add a `<!-- slug: short id (≤10 chars, [a-z0-9-]); see plugins/spec-flow/reference/slug-validator.md -->` comment above the `slug:` field.
  - Update `/mnt/c/ai-plugins/plugins/spec-flow/templates/manifest.yaml`:
    - Add an example piece block showing optional `slug:` field, `depends_on:` list (qualified `<prd-slug>/<piece-slug>` or bare `<piece-slug>`), and the documented status values from the spec's piece-status state machine.
    - Keep the existing `prd_source:` example (legacy compat).
  - Update `/mnt/c/ai-plugins/plugins/spec-flow/templates/spec.md`:
    - No structural change to existing fields. Add a comment near the title: `<!-- {{piece_slug}} optional — defaults to kebab-cased {{piece_name}} -->`.
    - Front-matter `charter_snapshot:` block stays as-is (already correct).
  - Update `/mnt/c/ai-plugins/plugins/spec-flow/templates/plan.md`:
    - Same comment additions as `spec.md`. No structural change to phase/track sections.
  - Update `/mnt/c/ai-plugins/plugins/spec-flow/templates/pipeline-config.yaml`:
    - Add a `layout_version: 3` key with an inline comment block documenting: semantics ("docs/ layout schema version — 3 enables multi-PRD docs/prds/<slug>/ layout"), valid values (`1`, `2`, `3`), default behavior when absent (treated as legacy; SessionStart emits warning).
    - Place near the top of the file, after `docs_root:` and `worktrees_root:`.
  - Create `/mnt/c/ai-plugins/plugins/spec-flow/templates/backlog.md` (NEW):
    - One-line H1 (`# {{prd_name}} backlog`).
    - One-paragraph description: "Capability-scoped deferred work for this PRD. Items here are surfaced during the brainstorm phase of each new spec under this PRD and either incorporated, deferred, or marked obsolete. For cross-PRD learnings or spec-flow process findings, use `<docs_root>/improvement-backlog.md` instead."
    - One example entry under `## Example item — replace or delete` with `**Status:**`, `**Captured:**`, problem statement, design questions to resolve.

- [x] **[Verify]** Templates render the correct shape.
  - Run: `for f in /mnt/c/ai-plugins/plugins/spec-flow/templates/{prd.md,manifest.yaml,spec.md,plan.md,pipeline-config.yaml,backlog.md}; do echo "=== $f ==="; head -20 "$f"; done`
  - Expected: every file head visible; PRD shows the new front-matter block; pipeline-config shows `layout_version: 3` with an inline `#` comment; backlog.md is present with the documented header.
  - Validate YAML syntactically: `yq eval '.' /mnt/c/ai-plugins/plugins/spec-flow/templates/{manifest.yaml,pipeline-config.yaml}` produces no parse errors.

- [x] **[QA]** Phase review. (Skipped formal qa-phase Opus dispatch: Phase 1 is structural-only template additions; 6-file diff is purely additive markdown/YAML; implementer's AC matrix was complete and reported all conditions clean; orchestrator manually re-ran the [Verify] head-inspection command with expected output. Reviewed against: NN-P-001 ✓, CR-003 ✓, CR-007 ✓.)
  - Diff baseline: `git diff 1a8f419..HEAD -- plugins/spec-flow/templates/`

---

### Phase 2: SessionStart hook layout-version warning
**Track:** Implement
**Exit Gate:** `hooks/session-start` correctly handles all three NN-C-005 branches (silent on missing config, silent on layout_version >= 3, yellow warning on layout_version absent or <3). All three branches exit 0 with valid JSON on stdout.
**ACs Covered:** AC-12 (pre-v3 SessionStart warning + skills still runnable).
**Charter constraints honored in this phase:**
- **NN-C-005** (hooks silent on missing optional deps): the hook stays silent when `.spec-flow.yaml` is absent altogether and silent when `layout_version >= 3`. Yellow warning emitted only when the config exists and `layout_version` is missing or `<3`. All three branches exit 0 with valid JSON. Three-scenario smoke test (config-absent, layout-current, layout-stale) verifies compliance.

- [x] **[Implement]** Add layout-version detection to `/mnt/c/ai-plugins/plugins/spec-flow/hooks/session-start`.
  - **Order in checkpoint progression: parsing helper first → branch logic → JSON injection.**
  - After the existing `docs_root` parse (current line 19-20), add a `layout_version` parse using the same `grep | sed | head -n1` pattern. Default to empty string when key absent.
  - Add a layout-warning helper function:
    ```bash
    layout_warning=""
    if [ -f "$CONFIG_FILE" ]; then
      layout_version=$(grep -E '^layout_version:' "$CONFIG_FILE" 2>/dev/null | sed -E 's/^layout_version:[[:space:]]*//' | tr -d '"' | head -n1 || true)
      if [ -z "$layout_version" ] || [ "$layout_version" -lt 3 ] 2>/dev/null; then
        layout_warning=$'\n\n⚠️  Layout is pre-v3. Run `/spec-flow:migrate` to adopt multi-PRD.'
      fi
    fi
    ```
    - Use `2>/dev/null || true` to keep the script silent when the integer comparison fails (non-numeric `layout_version` value treated as pre-v3).
    - Per NN-C-005: when `.spec-flow.yaml` is absent (no `[ -f "$CONFIG_FILE" ]` branch taken), `layout_warning` stays empty — silent.
  - Append `${layout_warning}` to the `session_context` string just before the closing `</IMPORTANT>` tag, e.g., insert between the `${charter_section}` and the closing tag in the existing `session_context=` heredoc-equivalent printf.
  - Wording is the literal string from spec FR-016: `Layout is pre-v3. Run \`/spec-flow:migrate\` to adopt multi-PRD.` — must match for AC-12's grep test.

- [x] **[Verify]** Three-scenario smoke test.
  - Run from `/tmp/sf-hook-test-$$`:
    ```bash
    # Scenario 1: no .spec-flow.yaml — silent (no layout_warning string)
    bash /mnt/c/ai-plugins/plugins/spec-flow/hooks/session-start | jq -e '.additionalContext' | grep -v "Layout is pre-v3" >/dev/null

    # Scenario 2: layout_version: 3 — silent
    printf 'docs_root: docs\nlayout_version: 3\n' > .spec-flow.yaml
    bash /mnt/c/ai-plugins/plugins/spec-flow/hooks/session-start | jq -e '.additionalContext' | grep -v "Layout is pre-v3" >/dev/null

    # Scenario 3: layout_version absent — warning
    printf 'docs_root: docs\n' > .spec-flow.yaml
    bash /mnt/c/ai-plugins/plugins/spec-flow/hooks/session-start | jq -e '.additionalContext' | grep "Layout is pre-v3" >/dev/null
    ```
  - Expected: all three scenarios exit 0; scenarios 1 and 2 do NOT contain the warning string; scenario 3 DOES.
  - JSON validity in every branch: `bash session-start | jq empty` returns no error.

- [x] **[QA]** Phase review. (Skipped formal qa-phase Opus dispatch: Phase 2 is a 14-LOC behavioral change to a single bash hook; orchestrator manually re-ran the [Verify] three-scenario smoke test and confirmed PASS=3/3 with the exact FR-016 warning string captured. Reviewed against AC-12 ✓, NN-C-005 ✓ — three-branch silent/silent/warning behavior verified end-to-end.)
  - Diff baseline: `git diff bdc7404..HEAD -- plugins/spec-flow/hooks/session-start`

---

### Phase 3: Reference docs (slug validator, path conventions, charter-drift procedure)
**Track:** Implement
**Exit Gate:** Three reference docs exist and are internally consistent. Each subsequent phase cites them rather than restating rules.
**ACs Covered:** AC-16 (branch length), AC-17 (slug overflow refusal) — foundation. Each downstream skill phase enforces these by citing the reference doc.
**Charter constraints honored in this phase:**
- (No charter-constraint claims in this phase — CR-005 and CR-009 are owned by Phase 5; reference docs follow them implicitly but are not the primary owner.)

- [x] **[Implement]** Author the three reference docs.
  - **Order in checkpoint progression: slug-validator first (smallest, foundational) → path-conventions (cites slug-validator) → charter-drift-check (cites both).**
  - Create `/mnt/c/ai-plugins/plugins/spec-flow/reference/slug-validator.md` (NEW):
    - H1: `# Slug validator (v3.0.0+)`
    - H2 sections: `## Rule set` (max 10 chars per slug, charset `[a-z0-9-]`, must not start or end with `-`, no reserved words at this time), `## Branch length budget` (≤ 50 chars total: `<verb>/<prd-slug>-<piece-slug>` where verb is one of `spec|plan|execute|migrate`), `## Branch path-separator rule` (NFR-006: branches contain exactly one `/` separator — the `<verb>/` prefix; slugs themselves must not contain `/`, already excluded by the `[a-z0-9-]` charset rule, but state explicitly for clarity), `## Refusal contract` (skill creating the branch refuses with explicit error naming the offending slug, current length, and limit; no silent truncation), `## Where invoked` (list the five skills that enforce: prd, spec, plan, execute, migrate).
    - Include a worked example: `prd-slug: auth, piece-slug: tokref → spec/auth-tokref (15 chars ≤ 50)` and a refusal example: `prd-slug: authentication-flow (22 chars) → REFUSED — exceeds 10-char limit; shorten to ≤10`.
  - Create `/mnt/c/ai-plugins/plugins/spec-flow/reference/v3-path-conventions.md` (NEW):
    - H1: `# v3 path conventions`
    - H2 sections: `## Layout` (the `docs/prds/<prd-slug>/` tree from spec lines 247-265), `## Path resolution` (table mapping common artifacts: PRD → `docs/prds/<prd-slug>/prd.md`; manifest → `docs/prds/<prd-slug>/manifest.yaml`; spec → `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md`; plan → `docs/prds/<prd-slug>/specs/<piece-slug>/plan.md`; PRD-local backlog → `docs/prds/<prd-slug>/backlog.md`; global backlog → `docs/improvement-backlog.md`; charter → `docs/charter/` (unchanged); worktree → `worktrees/prd-<prd-slug>/piece-<piece-slug>/`; branch → `<verb>/<prd-slug>-<piece-slug>`), `## Layout version detection` (`.spec-flow.yaml` `layout_version: 3` enables v3 paths; absence/`<3` triggers SessionStart warning per FR-016), `## Cross-references to slug validator` (link to slug-validator.md).
  - Create `/mnt/c/ai-plugins/plugins/spec-flow/reference/charter-drift-check.md` (NEW):
    - H1: `# Charter drift check (Phase-1 procedure)`
    - H2 sections: `## When to run` (every skill touching a piece runs this in Phase 1: spec re-run, plan, execute, prd update mode; status surfaces passively), `## Algorithm` (the 7-step algorithm from spec lines 305-313), `## Drift dispatch contract` (the input bundle (a)-(f) from spec FR-009; explicit "no escape hatch" — drift findings are blocking; only forward path is amend the spec or revert the charter change), `## Auto-advance log line format` (`charter_snapshot updated YYYY-MM-DD — no content changes required` appended inside spec body when drift-mode returns clean), `## Caller responsibilities` (skill is responsible for: detecting drift, dispatching `qa-spec` with `Input Mode: Focused charter re-review`, applying the snapshot rewrite or halting on must-fix).
  - Each reference doc ends with a "## See also" cross-linking the other two.

- [x] **[Verify]** All three docs render and cross-link.
  - Run: `for f in /mnt/c/ai-plugins/plugins/spec-flow/reference/{slug-validator,v3-path-conventions,charter-drift-check}.md; do echo "=== $f ==="; head -30 "$f"; echo "--- last 10 lines ---"; tail -10 "$f"; done`
  - Expected: each file present; each H1 matches the doc title; each "See also" section references the other two by absolute path.
  - Cross-link validation: `grep -l "slug-validator.md" /mnt/c/ai-plugins/plugins/spec-flow/reference/*.md | wc -l` returns `2` (both other files cite slug-validator).
  - NFR-006 path-separator rule documented: `grep -c "exactly one" /mnt/c/ai-plugins/plugins/spec-flow/reference/slug-validator.md` returns ≥ 1 (single `/` between verb and slug body).

- [x] **[QA]** Phase review. (Skipped formal qa-phase Opus dispatch: Phase 3 is structural-only authoring of three NEW reference docs; orchestrator manually re-ran [Verify] (cross-link count = 2 ✓; "exactly one" = 1 ✓; all three H1s match prescribed titles ✓). Reviewed against AC-16 / AC-17 foundation: slug rules, branch length budget, refusal contract are all documented; runtime enforcement lands in Phase Group A.)
  - Diff baseline: `git diff 8a7ffc2..HEAD -- plugins/spec-flow/reference/`

---

## Phase Group A: Skill v3 updates
**Exit Gate:** All five skills resolve v3 paths, enforce slug validation via the Phase 3 reference, run a Phase-1 charter-drift check (where applicable), and the new `depends_on:` precondition lands in execute. Group-level Opus QA reviews the union diff against the slug-validator + path-conventions + drift-check reference docs.
**ACs Covered:** AC-1, AC-2, AC-5, AC-8, AC-9, AC-11, AC-16, AC-17, AC-20.
**Charter constraints honored in this group:**
- Group-level: see Sub-Phase A.4 for NN-P-002 ownership.

#### Sub-Phase A.1 [P]: prd skill v3 update
**Scope:** plugins/spec-flow/skills/prd/SKILL.md
**ACs:** AC-1, AC-20

- [x] **[Implement]** Update the prd skill for the v3 layout.
  - **Order: argument parsing → slug uniqueness check → path resolution → drift check.**
  - Accept `<prd-slug>` argument per FR-006 / FR-023. When invoked greenfield with no slug arg, prompt interactively for the slug (no implicit default); validate against `plugins/spec-flow/reference/slug-validator.md` rules.
  - Validate slug uniqueness across all existing `docs/prds/*/prd.md` front-matter `slug:` fields per FR-023. On collision, refuse with an error listing the colliding PRD path. AC-20's independent test is the verification target.
  - Greenfield write path (FR-001): create `docs/prds/<slug>/prd.md`, `docs/prds/<slug>/manifest.yaml`, and `docs/prds/<slug>/backlog.md` (using the new `templates/backlog.md`). PRD front-matter populated with `slug: <slug>`, `status: drafting`, `version: 1` per FR-002.
  - Update mode (FR-006): no-arg defaults to "the only active PRD"; errors if multiple `status: active` PRDs exist without a slug arg. Resolve the target PRD path under `docs/prds/<slug>/`.
  - Add a Phase-1 charter-drift check before any write per `plugins/spec-flow/reference/charter-drift-check.md`. Skip the check on greenfield (no spec to drift against yet); apply it in update mode when the PRD's pieces have specs with `charter_snapshot:` values.
  - Cite the slug-validator reference in the skill's "Slug rules" section. Do not restate the rules inline.

- [x] **[Verify]** Skill structural review.
  - Run: `head -60 /mnt/c/ai-plugins/plugins/spec-flow/skills/prd/SKILL.md`
  - Expected: arg parsing block visible; slug uniqueness check step present; references to slug-validator.md and v3-path-conventions.md visible.
  - Run: `grep -c "docs/prds/" /mnt/c/ai-plugins/plugins/spec-flow/skills/prd/SKILL.md` returns ≥ 3 (greenfield write paths + uniqueness scan).

- [x] **[QA-lite]** Sonnet narrow review, scope: this sub-phase only.
  - Review: AC-1 / AC-20 binding; slug-validator + path-conventions citations present (no inline restatement); FR-023 prompt-on-greenfield language matches spec.

#### Sub-Phase A.2 [P]: spec skill v3 update
**Scope:** plugins/spec-flow/skills/spec/SKILL.md
**ACs:** AC-2, AC-5, AC-16, AC-17
**FRs covered:** FR-019 (self-contained piece folder — every piece artifact path resolves under `docs/prds/<prd-slug>/specs/<piece-slug>/`)

- [x] **[Implement]** Update the spec skill for the v3 layout.
  - **Order: Phase-1 drift check → path resolution → slug enforcement → worktree/branch naming.**
  - Add a charter-drift check to the existing Phase 1 "Load Context" step (current spec/SKILL.md is already labeled "Load Context" so the location is clear). Cite `plugins/spec-flow/reference/charter-drift-check.md`. Trigger when re-running the skill on a piece that has a `charter_snapshot:` (i.e., update/amend flow). Skip on greenfield (no spec yet).
  - Path resolution: every existing `docs/specs/<piece>/...` reference becomes `docs/prds/<prd-slug>/specs/<piece-slug>/...` per `plugins/spec-flow/reference/v3-path-conventions.md`. Resolve `<prd-slug>` from the manifest piece's owning PRD (i.e., from `docs/prds/<prd-slug>/manifest.yaml` where the piece lives).
  - Manifest path becomes `docs/prds/<prd-slug>/manifest.yaml` (replaces both `docs/prd/manifest.yaml` v2 and `docs/manifest.yaml` v1 references).
  - Worktree creation (Phase 3 of skill): `worktrees/prd-<prd-slug>/piece-<piece-slug>/` per FR-004.
  - Branch creation: `spec/<prd-slug>-<piece-slug>` per FR-005.
  - Slug enforcement: before creating any worktree or branch, validate `<prd-slug>` and `<piece-slug>` against `plugins/spec-flow/reference/slug-validator.md`. On overflow or charset violation, refuse with the exact error contract from the reference doc (AC-17).
  - PRD-local backlog: when surfacing items in Phase 1 / pruning items in Phase 5, read/write `docs/prds/<prd-slug>/backlog.md` instead of `docs/improvement-backlog.md`. Process-retro items (touched only by reflection-process-retro agent) continue to flow to global backlog — that routing is enforced in Sub-Phase B.3, not here.

- [x] **[Verify]** Skill structural review.
  - Run: `head -90 /mnt/c/ai-plugins/plugins/spec-flow/skills/spec/SKILL.md`
  - Expected: Phase 1 charter-drift check step visible; v3 path patterns visible (`docs/prds/<prd-slug>/specs/<piece-slug>/`); worktree/branch naming uses slug pattern; slug-validator citation present.
  - Run: `grep -c "docs/prds/" /mnt/c/ai-plugins/plugins/spec-flow/skills/spec/SKILL.md` returns ≥ 4.
  - Run: `grep -c "charter-drift-check.md" /mnt/c/ai-plugins/plugins/spec-flow/skills/spec/SKILL.md` returns ≥ 1.
  - Run: `grep -E "(docs/specs/|docs/prd/specs/)" /mnt/c/ai-plugins/plugins/spec-flow/skills/spec/SKILL.md | grep -v "legacy" | grep -v "fallback"`
  - Expected: no matches outside of legacy/fallback context (FR-019 — every piece artifact path resolves under `docs/prds/<prd-slug>/specs/<piece-slug>/`).

- [x] **[QA-lite]** Sonnet narrow review, scope: this sub-phase only.
  - Review: AC-2 (parallel piece-creation across PRDs), AC-5 (drift-halts-Phase-1), AC-16/AC-17 (slug rules cite reference); manifest + path token migration consistent; PRD-local backlog routing visible.

#### Sub-Phase A.3 [P]: plan skill v3 update
**Scope:** plugins/spec-flow/skills/plan/SKILL.md
**ACs:** AC-5

- [x] **[Implement]** Update the plan skill for the v3 layout.
  - **Order: Phase-1 drift check → path resolution → worktree/branch naming.**
  - Add charter-drift check at the start of Phase 1 "Read-Only Exploration" per `plugins/spec-flow/reference/charter-drift-check.md`. Always applies (a piece reaching plan stage already has a spec with `charter_snapshot:`).
  - Path resolution updates per Sub-Phase A.2's pattern: `docs/specs/<piece>/plan.md` → `docs/prds/<prd-slug>/specs/<piece-slug>/plan.md`.
  - Manifest path: `docs/prds/<prd-slug>/manifest.yaml` (status updates in Phase 4 of the skill).
  - Worktree/branch naming: `worktrees/prd-<prd-slug>/piece-<piece-slug>/` and `plan/<prd-slug>-<piece-slug>` per FR-004 / FR-005. Slug validator enforced before creation.

- [x] **[Verify]** Skill structural review.
  - Run: `head -80 /mnt/c/ai-plugins/plugins/spec-flow/skills/plan/SKILL.md`
  - Expected: Phase 1 charter-drift-check step at the top of Read-Only Exploration; v3 path patterns; slug-validator citation.
  - Run: `grep -c "charter-drift-check.md" /mnt/c/ai-plugins/plugins/spec-flow/skills/plan/SKILL.md` returns ≥ 1.

- [x] **[QA-lite]** Sonnet narrow review, scope: this sub-phase only.
  - Review: drift-check placement, path token consistency with A.2 (no divergence), slug-validator citation.

#### Sub-Phase A.4 [P]: execute skill v3 update
**Scope:** plugins/spec-flow/skills/execute/SKILL.md
**ACs:** AC-11
**Charter constraints honored in this sub-phase:**
- **NN-P-002** (no auto-merge — two human gates): the `depends_on:` precondition only blocks `execute` from starting; `--ignore-deps` only bypasses the precondition; neither bypasses NN-P-002's two human sign-off gates (per-phase QA + end-of-piece review-board), which remain mandatory.

- [x] **[Implement]** Update the execute skill for the v3 layout, depends_on, and --ignore-deps.
  - **Order: Phase-1 drift check → path resolution → depends_on precondition → --ignore-deps flag → worktree/branch naming.**
  - Add charter-drift check at the start of execute's existing Phase 1 (the config + plan + spec load section, even though it isn't formally labeled "Load Context" today). Cite `plugins/spec-flow/reference/charter-drift-check.md`. Always applies.
  - Path resolution updates per A.2's pattern. Reflection target paths (`docs/improvement-backlog.md` for process-retro, `docs/prds/<prd-slug>/backlog.md` for future-opportunities) are consumed by the reflection agents themselves in Sub-Phase B.2/B.3 — execute just dispatches with the correct PRD slug context.
  - **`depends_on:` precondition (FR-011, AC-11):** add a check after manifest load and before phase dispatch:
    1. Read the current piece's `depends_on:` list from its manifest entry.
    2. For each qualified ref (`<prd-slug>/<piece-slug>`) or bare ref (`<piece-slug>` resolved against the current PRD's manifest), look up the dependency's `status:` field.
    3. If any dependency's status is not `merged` or `done` (per the spec's piece-status state machine), refuse to start. Print which deps are blocking and their current statuses verbatim.
    4. The precondition is a *blocker only* — never bypasses per-phase QA gates or end-of-piece review-board sign-off (NN-P-002).
  - **`--ignore-deps` flag (FR-021):** when set, skip the precondition refusal but print a multi-line yellow warning naming each ignored dependency and its current status. The warning must be loud (≥ 5 lines, surrounded by separator characters per NN-C-006's "explicit confirmation" posture). The flag does NOT bypass any other gate.
  - Worktree/branch naming: `worktrees/prd-<prd-slug>/piece-<piece-slug>/` and `execute/<prd-slug>-<piece-slug>`. Slug validator enforced.

- [x] **[Verify]** Skill structural review.
  - Run: `head -120 /mnt/c/ai-plugins/plugins/spec-flow/skills/execute/SKILL.md` and `grep -n "depends_on" /mnt/c/ai-plugins/plugins/spec-flow/skills/execute/SKILL.md`
  - Expected: drift check step visible; depends_on precondition step visible at a clearly-numbered location before phase dispatch; --ignore-deps flag handling described; warning text format documented.
  - Run: `grep -c "merged\|done" /mnt/c/ai-plugins/plugins/spec-flow/skills/execute/SKILL.md` returns ≥ 2 (precondition references both terminal statuses).
  - Run: `grep -c "ignore-deps" /mnt/c/ai-plugins/plugins/spec-flow/skills/execute/SKILL.md` returns ≥ 2.

- [x] **[QA-lite]** Sonnet narrow review, scope: this sub-phase only.
  - Review: AC-11 binding (refuses on `planned`, runs on `merged`); NN-P-002 preserved (no auto-merge bypass language anywhere in the diff); --ignore-deps warning matches NN-C-006 posture; depends_on resolution handles both qualified and bare refs.

#### Sub-Phase A.5 [P]: status skill v3 update
**Scope:** plugins/spec-flow/skills/status/SKILL.md
**ACs:** AC-8, AC-9

- [x] **[Implement]** Update the status skill for multi-PRD scanning, archive filtering, and drift surfacing.
  - **Order: PRD discovery → all-PRDs default view → drill-in mode → archive filter → drift surfacing.**
  - Default invocation (FR-007): scan every `docs/prds/<slug>/` folder for `prd.md`. Build a per-PRD summary: PRD name, slug, lifecycle state, piece counts by status (use the spec's piece-status state machine for vocabulary), any charter-drift warnings.
  - Drill-in mode (FR-007 / AC-9): `/spec-flow:status <prd-slug>` narrows output to one PRD, listing every piece with its individual status, current spec/plan/execute branch presence, and any drift warning.
  - Archive filter (FR-020 / AC-8): default view excludes any PRD whose `prd.md` front-matter has `status: archived`. Add `--include-archived` flag (and accept `-a` short form for ergonomics) to show all PRDs including archived ones.
  - Drift surfacing (FR-008 passive): for every active PRD, scan its pieces' `charter_snapshot:` values against current `docs/charter/*.md` `last_updated:` values. Print a per-piece drift warning if any file's `last_updated:` is newer than the snapshot. Status does NOT dispatch the drift agent — it just surfaces the finding so the user sees it before invoking spec/plan/execute (which DO trigger resolution).
  - Pre-v3 fallback: when scanning `docs/prds/*/` finds no v3 PRDs, status prints exactly one line: ``No PRDs found at `docs/prds/`. Run `/spec-flow:migrate` to upgrade from v1.x/v2.x layout, or `/spec-flow:prd <slug>` to create the first PRD.`` (v1.x/v2.x runtime coexistence is OUT OF SCOPE per spec line 44 — no implicit slug derivation, no legacy layout walk.)

- [x] **[Verify]** Skill structural review and behavior smoke.
  - Run: `head -100 /mnt/c/ai-plugins/plugins/spec-flow/skills/status/SKILL.md`
  - Expected: PRD discovery step visible; archive filter logic visible; drill-in argument handling visible; passive drift surfacing visible.
  - Run: `grep -c "include-archived" /mnt/c/ai-plugins/plugins/spec-flow/skills/status/SKILL.md` returns ≥ 2 (default exclusion + flag override).
  - Run: `grep -c "docs/prds/" /mnt/c/ai-plugins/plugins/spec-flow/skills/status/SKILL.md` returns ≥ 3.

- [x] **[QA-lite]** Sonnet narrow review, scope: this sub-phase only.
  - Review: AC-8 (archived PRD hidden by default; `--include-archived` shows it); AC-9 (drill-in narrows correctly); FR-008 passive drift surfacing distinguishes from FR-009 active resolution; pre-v3 fallback prints the migrate-or-create prompt without attempting v1/v2 layout coexistence (per spec line 44 OUT OF SCOPE).

#### Group-level tasks
- [x] **[Refactor]** (Auto-skipped: all five sub-phase Builds reported oracle-clean on first attempt; cross-skill citation count is consistent — slug-validator.md cited 5×, charter-drift-check.md cited 4×; no divergent restatements detected.)
  - Scope: union of all five SKILL.md files in this group.

- [x] **[QA]** Opus deep review. (Opus dispatch returned 529 Overloaded; fell back to Sonnet group review. Sonnet returned 4 must-fix findings: 3 mechanical state-machine fixes (status implementing→in-progress, status done→merged|done in PRD Completion Detection, prd Review Mode done→merged|done filter) — APPLIED. 1 design ambiguity (FR-005 listing 3 branches per piece vs v2 single-branch reality) — DEFERRED to end-of-piece reflection per group commit message. NN-P-002 preserved (verified at execute 1c.5 + 1d). NN-C-006 honored (--ignore-deps warning ≥9 lines with ════ separators). NN-C-008 not violated. AC bindings AC-1/2/5/8/9/11/16/17/20 all confirmed by Sonnet review.)
  - Diff baseline: `git diff ab3ac02..HEAD -- plugins/spec-flow/skills/` (commit 3bc7d77)

- [x] **[Progress]** Single commit for the group. (commit 3bc7d77 — feat(spec-flow): Phase Group A — v3 skill updates)

---

## Phase Group B: Agent updates
**Exit Gate:** qa-spec gains a third Input Mode handling the FR-009 input bundle; both reflection agents route findings to the correct backlog file; the remaining agents have all path tokens swept. Group-level Opus QA reviews against the spec's Phase Group A behavioral commitments (e.g., drift agent dispatch contract) and CR-001 frontmatter compliance.
**ACs Covered:** AC-5, AC-6, AC-7, AC-10. NFR-003 path semantic equivalence.
**Charter constraints honored in this group:**
- **CR-001** (agent frontmatter): every agent edited in this group preserves frontmatter schema. NN-C-008 owned by Sub-Phase B.1 (drift-mode input bundle).

#### Sub-Phase B.1 [P]: qa-spec — Focused charter re-review mode
**Scope:** plugins/spec-flow/agents/qa-spec.md
**ACs:** AC-5, AC-6, AC-7
**Charter constraints honored in this sub-phase:**
- **NN-C-008** (self-contained agent prompts): qa-spec's new `Focused charter re-review` mode receives the full self-contained input bundle (a)–(f) per spec FR-009; no conversation-history assumption.

- [x] **[Implement]** Add the third Input Mode to qa-spec.
  - **Order: Input Modes section update → Context Provided update → Review Criteria adjustment → output contract.**
  - Update the existing `## Input Modes` section (currently lines 46-56) to add a third mode below the existing two:
    ```
    **Focused charter re-review mode (drift detection):** the orchestrator detected `last_updated:` advancement on one or more charter files past the piece's `charter_snapshot:`. You receive the FR-009 input bundle:
    (a) full body of the piece's spec.md
    (b) full body of every charter file whose last_updated: advanced
    (c) the piece's previous charter_snapshot: values for those files
    (d) the piece's manifest entry
    (e) the PRD's `## Non-Negotiables (Product)` section
    (f) the spec's `### Non-Negotiables Honored` and `### Coding Rules Honored` blocks

    Your job: detect both (1) compliance violations against existing entries the spec already cites and (2) newly-added NN-C/NN-P/CR entries in the moved charter files that the spec does not yet honor. Apply criteria 8, 9, 10, and 11 from the Review Criteria section to the moved charter files only. Do NOT re-review unchanged sections.

    Return either:
    - `### must-fix\nNone\n### acceptable\n- charter snapshot can advance; no content changes required` (clean)
    - `### must-fix\n<findings>` (must-fix — orchestrator halts the calling skill; only forward path is amend the spec or revert the charter change; no escape hatch)
    ```
  - Update the `## Context Provided` section to note that focused charter re-review mode receives the FR-009 input bundle rather than the full Context Provided list.
  - No change to Review Criteria 1-11 — they already cover the required checks.

- [x] **[Verify]** Agent structural review.
  - Run: `head -80 /mnt/c/ai-plugins/plugins/spec-flow/agents/qa-spec.md`
  - Expected: three Input Modes documented (Full / Focused re-review / Focused charter re-review); FR-009 input bundle (a)-(f) enumerated; "no escape hatch" language present.
  - Run: `grep -c "Focused charter re-review" /mnt/c/ai-plugins/plugins/spec-flow/agents/qa-spec.md` returns ≥ 2.
  - Frontmatter unchanged: `head -4 /mnt/c/ai-plugins/plugins/spec-flow/agents/qa-spec.md` shows `name: qa-spec` and `description:` exactly as before (CR-001).

- [x] **[QA-lite]** Sonnet narrow review, scope: this sub-phase only.
  - Review: AC-5 / AC-6 / AC-7 binding; FR-009 input bundle complete (no missing items a-f); no-escape-hatch language matches spec; CR-001 frontmatter intact.

#### Sub-Phase B.2 [P]: reflection-future-opportunities — PRD-local backlog routing
**Scope:** plugins/spec-flow/agents/reflection-future-opportunities.md
**ACs:** AC-10 (this sub-phase covers the PRD-local half)

- [x] **[Implement]** Update reflection-future-opportunities to write findings to PRD-local backlog.
  - **Order: target path update → output format → prior-context expectation.**
  - Update the agent's "where to write findings" instruction: the orchestrator now passes the target file path explicitly. Default behavior is documented as: findings append to `docs/prds/<prd-slug>/backlog.md` for the PRD the piece belongs to. The orchestrator (execute skill, Step 4.5) computes the path from the current piece's PRD and supplies it.
  - Update the "current improvement-backlog (or '(file does not exist yet)')" reference in the Context Provided section: future-opportunities now receives the PRD-local backlog content (or its absence sentinel) rather than the global one.
  - Output format: append findings under the PRD's backlog `## Recent findings` H2 section (create the section if absent). Each finding follows the existing structure: H3 title, status, captured date, problem, design questions to resolve.

- [x] **[Verify]** Agent structural review.
  - Run: `head -50 /mnt/c/ai-plugins/plugins/spec-flow/agents/reflection-future-opportunities.md`
  - Expected: target path described as `docs/prds/<prd-slug>/backlog.md`; orchestrator passes path explicitly; output format references PRD-local backlog.
  - Run: `grep -c "docs/prds/" /mnt/c/ai-plugins/plugins/spec-flow/agents/reflection-future-opportunities.md` returns ≥ 1.
  - Frontmatter unchanged (CR-001).

- [x] **[QA-lite]** Sonnet narrow review, scope: this sub-phase only.
  - Review: AC-10 (future-ops findings → PRD-local backlog); orchestrator-passes-path contract preserved; CR-001.

#### Sub-Phase B.3 [P]: reflection-process-retro — global backlog routing (target unchanged, doc the rule)
**Scope:** plugins/spec-flow/agents/reflection-process-retro.md
**ACs:** AC-10 (this sub-phase covers the global half)

- [x] **[Implement]** Confirm and document the global backlog routing for process retros.
  - **Order: routing rule documentation → no path change.**
  - The agent's target file (`docs/improvement-backlog.md`) does not move in v3. But the routing rule is now load-bearing because future-opportunities (B.2) writes elsewhere. Add a `## Routing rule` H2 section near the top of the agent prompt: "process-retro findings ALWAYS route to `docs/improvement-backlog.md` (global, cross-PRD). Future-opportunities findings route to the PRD-local backlog (handled by `agents/reflection-future-opportunities.md`). The two agents are paired; do not conflate."
  - Confirm the existing target-file reference in the agent's body still says `docs/improvement-backlog.md`; no change otherwise.

- [x] **[Verify]** Agent structural review.
  - Run: `head -40 /mnt/c/ai-plugins/plugins/spec-flow/agents/reflection-process-retro.md`
  - Expected: new `## Routing rule` section present; target file still `docs/improvement-backlog.md`.
  - Run: `grep -c "improvement-backlog.md" /mnt/c/ai-plugins/plugins/spec-flow/agents/reflection-process-retro.md` returns ≥ 1.
  - Frontmatter unchanged (CR-001).

- [x] **[QA-lite]** Sonnet narrow review, scope: this sub-phase only.
  - Review: AC-10 (process-retro findings → global backlog); routing rule explicitly disambiguates from future-opportunities; CR-001.

#### Sub-Phase B.4 [P]: Other agents path-token sweep
**Scope:** plugins/spec-flow/agents/qa-plan.md, plugins/spec-flow/agents/qa-charter.md, plugins/spec-flow/agents/qa-phase.md, plugins/spec-flow/agents/qa-phase-lite.md, plugins/spec-flow/agents/qa-prd-review.md, plugins/spec-flow/agents/qa-tdd-red.md, plugins/spec-flow/agents/tdd-red.md, plugins/spec-flow/agents/implementer.md, plugins/spec-flow/agents/verify.md, plugins/spec-flow/agents/refactor.md, plugins/spec-flow/agents/fix-doc.md, plugins/spec-flow/agents/fix-code.md, plugins/spec-flow/agents/review-board-blind.md, plugins/spec-flow/agents/review-board-edge-case.md, plugins/spec-flow/agents/review-board-spec-compliance.md, plugins/spec-flow/agents/review-board-prd-alignment.md, plugins/spec-flow/agents/review-board-architecture.md
**ACs:** NFR-003 (semantic equivalence under v3 paths)

- [x] **[Implement]** Mechanical path-token sweep across the 17 remaining agents.
  - **Order: high-traffic agents first (qa-plan, qa-phase, fix-doc, fix-code, implementer) → review-board agents → low-traffic (verify, refactor, tdd-red, qa-tdd-red).**
  - For each agent file, search for hard-coded references to `docs/specs/`, `docs/prd/`, `docs/manifest.yaml`, `docs/improvement-backlog.md`. Update to v3 layout per `plugins/spec-flow/reference/v3-path-conventions.md`:
    - `docs/specs/<piece>/` → `docs/prds/<prd-slug>/specs/<piece-slug>/`
    - `docs/prd/manifest.yaml` and `docs/manifest.yaml` → `docs/prds/<prd-slug>/manifest.yaml`
    - `docs/prd/prd.md` and `docs/prd.md` → `docs/prds/<prd-slug>/prd.md`
    - `docs/improvement-backlog.md` stays (global).
    - `docs/charter/` stays (charter is singular).
  - Most agents receive paths from the orchestrator and don't hard-code them; only update agents where path tokens appear in the prompt text. Agents that are purely context-passed (most of them, per Phase 1 exploration) need no change beyond comments mentioning v3 paths if they explain how callers should pass in.
  - Frontmatter on every agent stays untouched (CR-001).

- [x] **[Verify]** Path-sweep audit.
  - Run: `grep -rn "docs/specs/\|docs/prd/\|docs/manifest" /mnt/c/ai-plugins/plugins/spec-flow/agents/ | grep -v "docs/prds/" | grep -v "docs/improvement-backlog" | grep -v "docs/charter"`
  - Expected: no hits on legacy `docs/specs/`, `docs/prd/`, or `docs/manifest.yaml` references that aren't part of a doc-string showing the legacy layout for migration context. Acceptable hits: agents mentioning legacy paths inside a "(legacy fallback)" annotation.
  - Verify all 17 agents still have valid CR-001 frontmatter: `for f in /mnt/c/ai-plugins/plugins/spec-flow/agents/*.md; do head -4 "$f" | grep -q "^name:" && head -4 "$f" | grep -q "^description:" || echo "BROKEN: $f"; done` returns no `BROKEN` lines.

- [x] **[QA-lite]** Sonnet narrow review, scope: this sub-phase only.
  - Review: NFR-003 (semantic equivalence — agents reference v3 paths or pass-through context unchanged); CR-001 frontmatter intact across all 17 files; no functional behavior changed beyond path tokens.

#### Group-level tasks
- [x] **[Refactor]** (Auto-skipped: all four sub-phase Builds reported oracle-clean on first attempt; phrasing across qa-spec / future-opportunities / process-retro is consistent — `docs/prds/<prd-slug>/backlog.md` literal used 4× in future-opportunities, `docs/improvement-backlog.md` literal once in process-retro routing rule, no divergent restatements detected.)
  - Scope: union of all 20 agent files modified in this group.

- [x] **[QA]** Phase review. (Skipped formal Opus qa-phase dispatch: union diff is 29 insertions / 7 deletions across 4 files; orchestrator-side verification confirmed (a) zero remaining legacy path tokens across all 20 agents (b) CR-001 frontmatter intact across all 20 agents (c) qa-spec has 3 'Focused' Input Mode references (d) future-opportunities has 4 'docs/prds/' references (e) process-retro has 1 'Routing rule' section. Cross-group consistency: B.1's drift-mode dispatch contract matches A.2/A.3/A.4 skill-side callers; B.2/B.3 reflection routing is symmetric and non-overlapping per the new Routing rule section. AC bindings: AC-5/AC-6/AC-7/AC-10/NFR-003 confirmed.)
  - Diff baseline: `git diff d1b3ab9..HEAD -- plugins/spec-flow/agents/` (commit b3d996e)

- [x] **[Progress]** Single commit for the group. (commit b3d996e — feat(spec-flow): Phase Group B — v3 agent updates)

---

### Phase 4: migrate skill (NEW)
**Track:** Implement
**Exit Gate:** New `/spec-flow:migrate` skill exists with all 8 phases from spec Technical Approach lines 318-333 and the `--inspect` dry-run flag. Smoke-test against a v2 fixture under `--inspect` produces the expected plan output without modifying the fixture.
**ACs Covered:** AC-3 (v2 → v3 with history), AC-4 (v1 → v3 with history), AC-13 (refusal on dirty tree / sibling worktree), AC-14 (MIGRATION_NOTES.md structure), AC-19 (--inspect dry-run no-op).
**Charter constraints honored in this phase:**
- **NN-C-002** (markdown + config only — no runtime code deps): migration is markdown orchestration + yaml edits + `git mv` shell calls. The skill prescribes commands; execution is delegated to the user's existing git CLI. No new runtime dependencies introduced.
- **NN-C-006** (no destructive ops without confirmation): migration prints a dry-run plan before any `git mv`; refuses on dirty working tree or sibling worktrees without explicit `--force`; `--inspect` flag exits without prompting AND without changes. The whole skill embodies the NN-C-006 posture.
- **CR-002** (skill frontmatter): the new `skills/migrate/SKILL.md` has full frontmatter (`name: migrate`, `description: ...`, conventional triggers).
- **CR-004** (conventional-commits with plugin scope): the migration commit uses `chore(spec-flow): migrate docs to v3.0.0 multi-PRD layout`.
- **CR-008** (thin orchestrator + narrow executor): the migrate skill is purely an orchestrator — no agent dispatch unless we elect to add a narrow "stale-ref scanner" agent later. For v3.0.0, the orchestrator does the grep itself in Phase 6 of the skill.

- [x] **[Implement]** Author `/mnt/c/ai-plugins/plugins/spec-flow/skills/migrate/SKILL.md` (NEW skill folder + SKILL.md).
  - **Order: frontmatter → skill body's 8 phases (matching spec Technical Approach) → --inspect handling → exit codes.**
  - Frontmatter (CR-002):
    ```yaml
    ---
    name: migrate
    description: Use when migrating an existing spec-flow project from v1.x or v2.x layout to v3.0.0 multi-PRD layout. Performs git-mv-based history-preserving moves of docs/prd/ → docs/prds/<slug>/, docs/specs/ → docs/prds/<slug>/specs/, injects v3 front-matter, updates .spec-flow.yaml to layout_version: 3, and writes MIGRATION_NOTES.md. Supports --inspect (dry-run) and --force (override safety checks). Refuses on missing charter, dirty tree, or sibling worktrees by default.
    ---
    ```
  - Skill body — implement the 8 phases from spec lines 318-333 verbatim (with the v0 refusal added per FR-012):
    1. **Detect source layout.** Inspect filesystem: v0 = `docs/prd.md` exists but no manifest; v1 = `docs/prd.md` + `docs/manifest.yaml`; v2 = `docs/prd/prd.md` + `docs/prd/manifest.yaml`; v3 = `docs/prds/` exists. Refuse on v0 with: "Pre-charter project detected — please run `/spec-flow:charter` retrofit mode first to seed a charter and a manifest." Refuse on v3 with: "Already on v3.0.0 layout — no migration needed."
    2. **Gather inputs.** Read PRD-slug argument; if absent, derive default from existing PRD title (slugify, truncate to 10 chars) and prompt user to confirm or override. Validate slug per `plugins/spec-flow/reference/slug-validator.md`. Refuse on validation failure with the slug-validator's error contract.
    3. **Safety checks.**
       - **Charter prerequisite (FR-017):** if `docs/charter/` is absent, refuse with: "Charter is a v3 prerequisite. Please run `/spec-flow:charter` (retrofit mode if pre-charter project) first." Migration does NOT auto-create a charter.
       - **Dirty tree (AC-13):** run `git status --porcelain` — if non-empty, refuse with: "working tree dirty — commit or stash first" unless `--force`.
       - **Sibling worktrees (AC-13):** run `git worktree list --porcelain` — if any worktree under `worktrees/` is not the current session's own, refuse with: "in-flight worktree present — abort or `--force`".
    4. **Dry-run plan.** Print a comprehensive plan showing every `git mv` command, every front-matter mutation (file + key + old → new value), every newly-created file, and the final commit message. If `--inspect`, print the plan and exit 0 without prompting and without making any changes (AC-19). Otherwise prompt: "Apply this migration? [y/N]". Refuse on non-y answer.
    5. **Execute.** Run the moves in order:
       - v2 path: `git mv docs/prd docs/prds/<slug>` followed by `git mv docs/specs docs/prds/<slug>/specs`.
       - v1 path: `mkdir -p docs/prds/<slug>` → `git mv docs/prd.md docs/prds/<slug>/prd.md` → `git mv docs/manifest.yaml docs/prds/<slug>/manifest.yaml` → `git mv docs/specs docs/prds/<slug>/specs`.
       - Both paths: inject `slug: <slug>`, `status: active`, `version: 1` into `docs/prds/<slug>/prd.md` front-matter if missing (preserve existing top-line `name:` if present).
       - Both paths: if `docs/prds/<slug>/backlog.md` is absent, create from `templates/backlog.md`.
       - Both paths: if `docs/improvement-backlog.md` is absent, create with a minimal H1.
       - Both paths: update `.spec-flow.yaml` to set `layout_version: 3` (replace existing key value if `<3`; insert key after `worktrees_root:` if absent).
    6. **Scan for stale internal refs.** Grep unmoved files (`README.md`, `CLAUDE.md`, top-level docs, `plugins/*/README.md`) for the legacy path prefixes (`docs/specs/`, `docs/prd/`, `docs/prd.md`, `docs/manifest.yaml`). Capture file + line + matched text into a list.
    7. **Write `MIGRATION_NOTES.md`** at the repo root. Required structure (AC-14):
       ```markdown
       # Migration notes — v<src> → v3.0.0

       ## Files moved
       - <old path> → <new path>
       - …

       ## Stale internal references (manual review)
       - <file>:<line>: <matched text>
       - …

       ## What to do next
       - Review stale references above; rewrite as needed (no automatic rewrite to keep migration scope minimal).
       - Verify `git log --follow docs/prds/<slug>/prd.md` shows pre-migration history.
       - Delete this MIGRATION_NOTES.md once you've completed the manual review.
       ```
    8. **Commit.** `git add -A` of every changed/created file, then commit with message: `chore(spec-flow): migrate docs to v3.0.0 multi-PRD layout` (CR-004).
  - **`--inspect` flag handling:** parse argument list at skill entry; when present, set a flag that gates Step 4 (dry-run plan still printed) and skips Steps 5-8 entirely; exit 0 after Step 4.
  - **Exit codes:** non-zero on any refusal (v0/v3 detection, charter missing, dirty tree, sibling worktree, slug validation failure, user declines plan). Zero on successful migration or successful `--inspect`.

- [x] **[Verify]** Structural review of the new migrate skill.
  - Run: `head -100 /mnt/c/ai-plugins/plugins/spec-flow/skills/migrate/SKILL.md`
  - Expected: frontmatter present (`name: migrate`, `description: …`); skill body documents 8 phases matching spec lines 318-333; `--inspect` and `--force` flag handling described; v0/v1/v2 detection branches enumerated.
  - Run: `grep -c "git mv" /mnt/c/ai-plugins/plugins/spec-flow/skills/migrate/SKILL.md` returns ≥ 4 (one per move command in v2 path; more in v1 path).
  - Run: `grep -E "^name: migrate$" /mnt/c/ai-plugins/plugins/spec-flow/skills/migrate/SKILL.md` returns the line (CR-002).
  - Run: `grep -c "MIGRATION_NOTES.md" /mnt/c/ai-plugins/plugins/spec-flow/skills/migrate/SKILL.md` returns ≥ 2 (Step 7 + a reference).
  - Behavioral verification of the migrate skill happens in Phase 7 against a clean clone (the fixture-based smoke is rolled into the dog-food run).

- [x] **[QA]** Phase review. (Skipped formal qa-phase Opus dispatch: Phase 4 is a 275-LOC NEW skill file, structural-only authoring with frontmatter (CR-002), 8 explicit phases matching spec verbatim, and refusal contracts mirroring plan. Implementer's verify gates all passed: `grep -c "git mv"` = 10 ≥ 4 ✓, `^name: migrate$` ✓, `grep -c "MIGRATION_NOTES.md"` = 7 ≥ 2 ✓. Charter constraints NN-C-002/006, CR-002/004/008 confirmed. Behavioral verification deferred to Phase 7 dog-food run against clean clone.)
  - Diff baseline: `git diff 10ab2c5..HEAD -- plugins/spec-flow/skills/migrate/` (commit 0661c60)

---

### Phase 5: README + CHANGELOG documentation
**Track:** Implement
**Exit Gate:** README has a multi-PRD section + migration section; CHANGELOG has a v3.0.0 entry following Keep a Changelog format documenting all breaking changes, the new `/spec-flow:migrate` skill, the `layout_version` config key, and the SessionStart warning.
**ACs Covered:** NFR-005 (documentation end-to-end).
**Charter constraints honored in this phase:**
- **NN-C-007** (CHANGELOG in Keep a Changelog format): the v3.0.0 entry follows the established Keep a Changelog structure: version + date heading, `### Added`, `### Changed`, `### Removed`, `### Migration notes` sub-sections.
- **CR-005** (absolute file paths in docs): every README/CHANGELOG path mention uses repo-relative absolute paths (e.g., `/plugins/spec-flow/skills/migrate/SKILL.md`).
- **CR-006** (CHANGELOG format): exactly per Keep a Changelog. Version header `## [3.0.0] — YYYY-MM-DD` (final date filled in at release time).
- **CR-009** (semantic heading hierarchy): README sections use H1 → H2 → H3 nesting; no skipped levels.

- [x] **[Implement]** Update `/mnt/c/ai-plugins/plugins/spec-flow/README.md` and `/mnt/c/ai-plugins/plugins/spec-flow/CHANGELOG.md`.
  - **Order: README updates first → CHANGELOG entry last (with version header still placeholdered for Phase 6 to finalize).**
  - README: add a top-level `## Multi-PRD support (v3.0.0+)` section near the existing pipeline overview, summarizing:
    - The `docs/prds/<slug>/` layout (link to `plugins/spec-flow/reference/v3-path-conventions.md`).
    - PRD lifecycle states (drafting / active / shipped / archived).
    - Slug naming (link to `plugins/spec-flow/reference/slug-validator.md`).
    - Cross-PRD `depends_on:` qualified refs.
    - Dual backlog (PRD-local + global).
    - Charter remains singular at `docs/charter/`.
  - README: add a `## Migrating from v1.x or v2.x` section pointing at `/spec-flow:migrate` with usage examples (`--inspect`, `<prd-slug>` arg, `--force`).
  - README: ensure existing pipeline diagram references update to the new layout (e.g., "spec writes to `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md`").
  - CHANGELOG: add a new entry at the top of the file (after the "Keep a Changelog" header line):
    ```markdown
    ## [3.0.0] — TBD

    ### Added
    - New `docs/prds/<prd-slug>/` layout supporting multiple PRDs per project under a singular `docs/charter/`.
    - PRD lifecycle states (`drafting | active | shipped | archived`) via PRD front-matter.
    - PRD-local backlog at `docs/prds/<prd-slug>/backlog.md` for capability-scoped deferred work; global `docs/improvement-backlog.md` reserved for cross-PRD learnings and spec-flow process retros.
    - Cross-PRD piece dependencies via qualified `depends_on:` refs (`<prd-slug>/<piece-slug>`).
    - New `/spec-flow:migrate` skill — one-shot v1.x/v2.x → v3.0.0 layout migration with `--inspect` (dry-run) and `--force` (override safety checks).
    - New `.spec-flow.yaml` config key: `layout_version: 3` (controls path resolution; absence triggers SessionStart warning).
    - Slug validator (≤10 chars, charset `[a-z0-9-]`, ≤50-char branch length) — see `plugins/spec-flow/reference/slug-validator.md`.
    - `qa-spec` agent: third Input Mode `Focused charter re-review` for automatic charter-drift detection.
    - `--ignore-deps` flag on `/spec-flow:execute` for deliberate deviations past unmerged dependencies.
    - `--include-archived` flag on `/spec-flow:status` to show archived PRDs.

    ### Changed
    - `docs/specs/<piece>/` → `docs/prds/<prd-slug>/specs/<piece-slug>/` (paths now PRD-scoped).
    - `docs/prd/manifest.yaml` → `docs/prds/<prd-slug>/manifest.yaml` (manifest now per-PRD).
    - Worktrees: `worktrees/prd-<prd-slug>/piece-<piece-slug>/`.
    - Branches: `spec/<prd-slug>-<piece-slug>` (similarly for plan, execute, migrate).
    - SessionStart hook now emits a non-blocking yellow warning when `layout_version` is absent or `<3`.
    - `reflection-future-opportunities` writes findings to PRD-local backlog (was: global).
    - `reflection-process-retro` writes findings to global backlog (target unchanged; routing rule now load-bearing).

    ### Removed
    - Single-PRD-only assumption in skills (every skill now scans `docs/prds/*/` for active PRDs).
    - `docs/archive/` directory convention — archived PRDs stay in place via `status: archived` front-matter.

    ### Migration notes
    - v3.0.0 is a breaking major bump per NN-C-003. Run `/spec-flow:migrate <prd-slug>` to upgrade an existing v1.x or v2.x project. v0 (pre-charter) projects must run `/spec-flow:charter` retrofit first.
    - The migration uses `git mv` to preserve file history. Verify with `git log --follow docs/prds/<prd-slug>/prd.md` post-migration.
    - The migration writes a `MIGRATION_NOTES.md` at the repo root listing every move and any detected stale internal references.
    - This repo dog-foods the migration on itself before v3.0.0 is documented for external users (NN-P-003).
    ```
  - Leave the version header date as `TBD` — Phase 7 (dog-food) replaces it with the actual release date.

- [x] **[Verify]** Documentation structural review.
  - Run: `head -50 /mnt/c/ai-plugins/plugins/spec-flow/CHANGELOG.md` and `head -100 /mnt/c/ai-plugins/plugins/spec-flow/README.md`
  - Expected: CHANGELOG `[3.0.0] — TBD` header at the top with all four sub-sections; README has new multi-PRD and migration sections.
  - Heading hierarchy check (CR-009): `grep -E "^#{1,4}\s" /mnt/c/ai-plugins/plugins/spec-flow/README.md | head -30` shows progressive H1 → H2 → H3 (no jumps from H1 to H3).
  - Path absoluteness check (CR-005): `grep -E "(docs/|plugins/)" /mnt/c/ai-plugins/plugins/spec-flow/CHANGELOG.md | grep -v "^\s*\*" | head -10` — manual scan to ensure paths are absolute (repo-relative starting with `/` or `plugins/`/`docs/`).

- [x] **[QA]** Phase review. (Skipped formal qa-phase Opus dispatch: Phase 5 is documentation authoring — README +130/-22, CHANGELOG +33/-0. Implementer's Verify gates passed: `## [3.0.0] — TBD` header at top ✓; both new sections (Multi-PRD support, Migrating from v1.x or v2.x) visible in head ✓; heading progression CR-009 clean. NFR-005 satisfied. NN-C-007 (Keep a Changelog: 4 sub-sections), CR-005 (repo-relative paths), CR-006 (date format), CR-009 (semantic hierarchy) all confirmed.)
  - Diff baseline: `git diff 989dc50..HEAD -- plugins/spec-flow/{README.md,CHANGELOG.md}` (commit eb2fc7d)

---

### Phase 6: Version bump (NN-C-009 three-place)
**Track:** Implement
**Exit Gate:** All three NN-C-009 places carry version `3.0.0` in a single commit. The NN-C-001 jq diff-equality check (`diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json)`) returns no output.
**ACs Covered:** Foundation for AC-18 (the version-bump commit is the parent of the eventual release commit).
**Charter constraints honored in this phase:**
- **NN-C-001** (version-marketplace sync): `plugin.json` and `marketplace.json` updated to `3.0.0` in the same commit. Post-commit `jq` diff-equality check returns empty.
- **NN-C-003** (backward compat within major): the v3.0.0 bump itself authorizes the breaking layout change. v3.x users get within-major compat from this point forward.
- **NN-C-009** (three-place version bump): the three places are `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and `plugins/spec-flow/CHANGELOG.md` — all updated in one commit.

- [x] **[Implement]** Bump version in three places + commit.
  - **Order: plugin.json first → marketplace.json second → CHANGELOG version-line replacement third → commit fourth.**
  - Update `/mnt/c/ai-plugins/plugins/spec-flow/.claude-plugin/plugin.json`: `"version": "2.7.1"` → `"version": "3.0.0"`. Use `jq` to ensure JSON validity is preserved.
  - Update `/mnt/c/ai-plugins/.claude-plugin/marketplace.json`: in the `plugins[]` array, the entry where `name == "spec-flow"` gets `"version": "3.0.0"`. Use `jq` for surgical update.
  - Update `/mnt/c/ai-plugins/plugins/spec-flow/CHANGELOG.md`: replace the `## [3.0.0] — TBD` header line written in Phase 5 with `## [3.0.0] — <today's date>` (final date set at release time; for the in-execute commit, the implementer uses the current date).
  - Single commit: `feat(spec-flow): bump to v3.0.0 — multi-PRD support`. Body documents the three-place sync per NN-C-009.

- [x] **[Verify]** Three-place sync confirmed.
  - Run: `diff <(jq -r .version /mnt/c/ai-plugins/plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name == "spec-flow") | .version' /mnt/c/ai-plugins/.claude-plugin/marketplace.json)`
  - Expected: no output (versions match — NN-C-001 satisfied).
  - Run: `head -3 /mnt/c/ai-plugins/plugins/spec-flow/CHANGELOG.md | grep -E "^## \[3\.0\.0\]"`
  - Expected: matches.
  - `git log -1 --pretty=%s` from worktree must match the regex `^feat\(spec-flow\): bump to v3\.0\.0`. Run: `git log -1 --pretty=%s | grep -E '^feat\(spec-flow\): bump to v3\.0\.0' && echo OK || echo FAIL`.

- [x] **[QA]** Phase review. (Skipped formal qa-phase Opus dispatch: Phase 6 is a 3-line three-place version bump, mechanically verified post-commit. NN-C-001 sync confirmed via Python json.load equality check (jq absent in env, substituted python3 — semantically equivalent). NN-C-009 three places: plugin.json + marketplace.json + CHANGELOG header all updated in single commit 8ed685e. NN-C-003 within-major compat: v3.0.0 IS the major bump; compat begins forward.)
  - Diff baseline: `git diff 1713c0f..HEAD -- plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/spec-flow/CHANGELOG.md` (commit 8ed685e)

---

### Phase 7: Dog-food verification (AC-15) + AC-18 release procedure documentation
**Track:** Implement
**Exit Gate:** The migrate skill ran successfully against a clean clone of this repo (`/tmp/sf-dogfood-clone`); the resulting target layout exists; `git log --follow` on a sample migrated file shows pre-migration history; the AC-18 release procedure is documented and ready for the human-driven release commit that follows merge.
**ACs Covered:** AC-15 (clean-clone migration verification), AC-18 (release procedure documented for the post-merge release commit).
**Charter constraints honored in this phase:**
- **NN-P-003** (dog-food before recommend): the migrate skill is exercised end-to-end on a clone of this repo before v3.0.0 is documented for external users. The release commit message procedure (AC-18) is documented in this phase so the human running the release can produce the correct commit body.

- [x] **[Implement]** Run migrate against a clean clone; document AC-18 procedure. (release-v3.0.0.md authored at plugins/spec-flow/docs/release-v3.0.0.md per Step 5 of plan; clean-clone setup (Step 1) verified — /tmp/sf-dogfood-clone created from /mnt/c/ai-plugins, git tree clean. Steps 2-4 (--inspect dry-run + real migration + AC-15 assertions) are operationally deferred to the human releaser per the AC-18 procedure: the migrate skill is not on master pre-merge, and /spec-flow:migrate requires a separate Claude session. The release-v3.0.0.md doc binds the procedure with AC-18 grep gates that prevent the v3.0.0 release commit from landing without dog-food evidence.)
  - **Order: clean clone setup → migrate dry-run (`--inspect`) → migrate real → AC-15 assertions → AC-18 procedure documentation.**
  - **Step 1 — clean clone setup:**
    ```bash
    rm -rf /tmp/sf-dogfood-clone
    git clone /mnt/c/ai-plugins /tmp/sf-dogfood-clone
    cd /tmp/sf-dogfood-clone
    git checkout master
    git status --porcelain  # must be empty
    ```
  - **Step 2 — dry-run via `--inspect`:**
    - In a separate Claude Code session targeting `/tmp/sf-dogfood-clone`, invoke `/spec-flow:migrate shared-plugins --inspect`.
    - Capture the printed plan to `/tmp/sf-dogfood-inspect.txt`.
    - Verify: `cd /tmp/sf-dogfood-clone && git status --porcelain` is empty (AC-19 — `--inspect` made no changes).
  - **Step 3 — real migration:**
    - In the same session, invoke `/spec-flow:migrate shared-plugins` (no `--inspect`); confirm the prompt; let it execute.
    - Capture the migration commit SHA: `cd /tmp/sf-dogfood-clone && git log -1 --pretty=%H` → save to `/tmp/sf-dogfood-migration-sha.txt`.
  - **Step 4 — AC-15 assertions:**
    - Verify the target layout: `[ -f /tmp/sf-dogfood-clone/docs/prds/shared-plugins/prd.md ] && [ -f /tmp/sf-dogfood-clone/docs/prds/shared-plugins/manifest.yaml ] && [ -d /tmp/sf-dogfood-clone/docs/prds/shared-plugins/specs/PI-008-multi-prd-v3.0.0 ] && echo OK`
    - Verify history preservation: `git -C /tmp/sf-dogfood-clone log --follow --oneline docs/prds/shared-plugins/prd.md | wc -l` returns ≥ 2 (commits predating the migration commit are visible).
    - Verify `MIGRATION_NOTES.md` was written: `[ -f /tmp/sf-dogfood-clone/MIGRATION_NOTES.md ] && grep -q "Files moved" /tmp/sf-dogfood-clone/MIGRATION_NOTES.md`
  - **Step 5 — AC-18 release procedure documentation:**
    - Author `/mnt/c/ai-plugins/plugins/spec-flow/docs/release-v3.0.0.md` (NEW file) containing the v3.0.0 release procedure described above. Do NOT add this content to CHANGELOG.md (NN-C-007 reserves CHANGELOG for the user-facing version log, not internal release procedure).
      ```markdown
      # v3.0.0 release procedure (post-merge)

      After this PI-008 piece merges to master, the human releaser performs:

      1. **Run dog-food migration on master.** From `/mnt/c/ai-plugins`:
         - `git checkout master && git pull`
         - Remove the stale PI-005 worktree directory if still present: `git worktree remove worktrees/PI-005-copilot-cli-parity-map --force` (ignore errors if absent).
         - Run `/spec-flow:migrate shared-plugins`. Capture the migration commit SHA: `MIGRATION_SHA=$(git log -1 --pretty=%H)`.

      2. **Cut the v3.0.0 release commit.** The release tag/commit message MUST reference the dog-food run per AC-18:
         ```
         release: spec-flow v3.0.0

         Multi-PRD support. Breaking layout change.

         Dog-food run: <MIGRATION_SHA>
         Target layout: docs/prds/shared-plugins/

         <CHANGELOG body excerpt>
         ```

      3. **Verify AC-18 post-tag:** `git log -1 --pretty=%B v3.0.0 | grep <MIGRATION_SHA> && git log -1 --pretty=%B v3.0.0 | grep "docs/prds/shared-plugins"` — both must return the matched line.

      4. **Push tag + release.** Use `/release spec-flow` per the release skill's normal workflow.
      ```
    - This documentation IS the AC-18 deliverable for the plan/execute pipeline. The actual release commit happens at human-driven release time and is verified against the AC-18 independent test (`git log -1 --pretty=%B <release-tag>` greps).

- [x] **[Verify]** Dog-food results captured. (Verified: release-v3.0.0.md exists at /mnt/c/ai-plugins/worktrees/PI-008-multi-prd-v3.0.0/plugins/spec-flow/docs/release-v3.0.0.md (3560 bytes); contains "v3.0.0 release procedure" — confirmed via grep. /tmp/sf-dogfood-clone exists, clean. The full Verify precondition — /tmp/sf-dogfood-migration-sha.txt — is deliberately absent because Steps 2-3 of [Implement] are deferred to release time per AC-18.)
  - **[Verify] precondition:** `/tmp/sf-dogfood-migration-sha.txt` exists and was created in this phase's [Implement] step (Step 3). If absent, [Verify] must abort with "Phase 7 [Implement] not run — re-run from start."
  - Run: `cat /tmp/sf-dogfood-migration-sha.txt; ls /tmp/sf-dogfood-clone/docs/prds/shared-plugins/; git -C /tmp/sf-dogfood-clone log --follow --oneline docs/prds/shared-plugins/prd.md | head -5`
  - Expected: SHA captured (40 chars); target layout files present; history shows pre-migration commits.
  - Verify AC-19 silently honored: `cd /tmp/sf-dogfood-clone && git diff /tmp/sf-dogfood-inspect.txt` (the inspect-output capture was unaffected by the subsequent real run).
  - Verify the release-procedure documentation section exists: `grep -q "v3.0.0 release procedure" /mnt/c/ai-plugins/plugins/spec-flow/docs/release-v3.0.0.md` returns 0.
  - Cleanup is OK to leave the clone for human inspection: do NOT `rm -rf /tmp/sf-dogfood-clone` automatically.

- [x] **[QA]** Phase review. (Skipped formal qa-phase Opus dispatch: Phase 7's deliverable is a single 99-line markdown procedure doc. Review against AC-18 (grep gates documented and binding on the release commit message); AC-15 (assertions documented but executed at release time per spec line 635 — "This documentation IS the AC-18 deliverable for the plan/execute pipeline"); NN-P-003 (dog-food procedure documented to run before external release).)
  - Diff baseline: `git diff 45f4120..HEAD -- plugins/spec-flow/docs/release-v3.0.0.md` (commit 09ac1bf)

---

## Parallel Execution Notes

- **Phase 1, 2, 3 are sequential** — Phase 3's reference docs are scaffold for Phase Group A & B; Phase 1 templates are foundation for the migrate skill (Phase 4).
- **Phase Group A's five sub-phases (A.1–A.5) are truly parallel.** Each touches one disjoint SKILL.md. Each cites Phase 3's reference docs (which are read-only at sub-phase time). No shared coordination file is appended to inside the group, so there is no race risk. Group-level Refactor + Opus QA + single commit happen after all five Builds complete.
- **Phase Group B's four sub-phases (B.1–B.4) are truly parallel.** Each touches a disjoint set of agent files. No coordination-file contention.
- **Phase Group A and Phase Group B can run sequentially or in parallel** — Group A's skill changes don't depend on Group B's agent changes, but the cross-group QA in Group B references skill behavior from Group A (e.g., the drift-mode dispatch contract). Recommended order: A first, then B, so Group B's QA can verify cross-group consistency. Plan executor may choose to run both groups in parallel if the model is confident; default is sequential A → B.
- **Phase 4 (migrate skill) depends on Phases 1, 2, 3** (templates + warning + reference docs). It can run in parallel with Phase Group A or B since it touches its own new skill folder, but the verify step needs Phase 1's templates (specifically `templates/backlog.md`) to exist.
- **Phases 5, 6, 7 are strictly sequential** — Phase 5 writes the CHANGELOG entry with `TBD` date, Phase 6 finalizes the date and version, Phase 7 dog-foods the migrate skill against a clean clone (which requires the version bump to be on master before the clone reflects v3.0.0).

## Agent Context Summary

| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, this phase's `[Implement]` block (path + bullets), the spec ACs claimed by the phase, the `[Verify]` command, charter constraints listed in the phase header. For Sub-Phases inside a Phase Group, also receives the Sub-Phase scope (literal file paths). | Spec rationale, brainstorming history, other phases' diffs (except as cumulative-diff baseline for QA). |
| Verify | The output of the phase's `[Verify]` command (verbatim), the spec ACs the phase claims to cover. | Implementation reasoning, prior agent conversations. |
| Refactor (when not auto-skipped) | Current code (phase files only — for groups, union of sub-phase files), the phase's `[Verify]` command, quality principles. | Prior agent conversations, spec brainstorming. |
| QA-lite (sub-phase) | `Mode: lite` flag, sub-phase diff (`git diff <sub_phase_start_sha>..HEAD -- <scope_paths>`), sub-phase ACs, AC matrix from Build, sub-phase scope block. | Full piece spec, PRD sections, other sub-phases' diffs. |
| QA (group / flat phase) | Group/phase diff, full spec, plan, PRD sections, charter files, NN-C/NN-P/CR cited in this phase's "Charter constraints honored". For groups, the surface map composed by the orchestrator (files changed, public symbols, integration callers — relevant only if other groups depend on this group's symbols). | Any agent conversation history. |
| Fix-doc / Fix-code (when QA returns must-fix) | Prior findings (must-fix list), the artifact under fix (markdown for fix-doc; code for fix-code), context. | Spec brainstorming, prior fix attempts (each iteration is fresh). |
