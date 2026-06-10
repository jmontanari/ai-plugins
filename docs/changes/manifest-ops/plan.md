---
charter_snapshot:
  architecture: 2026-06-09
  non-negotiables: 2026-06-09
  tools: 2026-06-09
  processes: 2026-06-09
  flows: 2026-06-09
  coding-rules: 2026-06-09
legacy_deferred_rows: false
fast: false
tdd: false
---

# Plan: manifest-ops — Manifest query + state tool

**Brief:** docs/changes/manifest-ops/brief.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates honored NN-C/CR entries)
**Status:** final-review-pending

## Overview

Ship a deterministic manifest query/mutation tool plus a `manifest` skill that
wraps it. The tool is a bash entry point (`manifest-query`) carrying a complete
pure-awk implementation, plus an optional `python3` fast path it dispatches to when
`python3` is present. Five subcommands: `open`, `deps`, `ready`, `table`,
`set-status`. All phases use the Implement track (`tdd: false`): build first, then
golden-output shell tests against in-repo fixtures.

## Architectural Decisions

### ADR-1: One bash entry point with an optional python fast path
**Context:** FR-7 requires a `python3` fast path AND a complete pure-bash fallback,
auto-selected. `yq` is not installed; `jq` is JSON-only. The manifest is regular
(2-space-indented list items, one field per line, inline `[]` lists), so awk parses
it without a YAML library.
**Decision:** `manifest-query` (bash) holds the full awk implementation. At startup
it `exec`s `manifest-query.py` when `command -v python3` succeeds and
`MANIFEST_QUERY_NO_PY` is unset; otherwise it runs the awk path. The env toggle lets
the parity test force the bash path.
**Alternatives considered:** (a) python-only — rejected, breaks the bash fallback
requirement. (b) two sibling scripts with a separate dispatcher file — rejected,
more files for no gain; the bash entry IS the fallback.
**Consequences:** Two implementations must stay output-identical — enforced by the
Phase 3 parity test, not by trust. NN-C-002 is knowingly violated (owner-accepted,
see brief).
**Charter alignment:** NN-C-002 overridden (owner-accepted); NN-C-005 honored (bash
path runs when python3 is absent).

### ADR-2: Ship in-repo fixture snapshots for reproducible tests
**Context:** AC-6 validates against the `prop_firm` manifest, which lives outside
this repo and won't exist on other machines or CI.
**Decision:** Snapshot `prop_firm`'s `prop-firm/manifest.yaml` into
`scripts/tests/fixtures/` so shipped golden tests are reproducible. Live `prop_firm`
remains a manual local validation target only.
**Alternatives considered:** Reference the external path directly — rejected, non-
reproducible and breaks zero-install testing.
**Consequences:** Fixtures are checked in; if the real manifest schema evolves the
fixtures must be refreshed.
**Charter alignment:** NN-C-002 rationale (works on a fresh machine) honored for the
test suite.

## Phases

### Phase 1 (Implement track): Bash/awk tool core
**Exit Gate:** `manifest-query {open,deps,ready,table,set-status}` work end-to-end via
the awk path (python absent), with golden tests green against the fixtures.
**ACs Covered:** AC-1, AC-2, AC-3, AC-4, AC-5
**In scope:** `plugins/spec-flow/scripts/manifest-query` (awk implementation + arg
parsing + the five subcommands); `scripts/tests/fixtures/` (snapshots of exec-ready,
shared, prop-firm manifests); `scripts/tests/test-manifest-query.sh` (golden tests).
**NOT in scope:** the python fast path (Phase 2); the dispatch guard (Phase 3); the
skill (Phase 4).
**Charter constraints honored in this phase:**
- NN-C-005 (graceful degradation): the awk path is self-sufficient with no runtime deps.

- [x] **[Implement]**
  **Change Specifications:**

  **T-1: CREATE plugins/spec-flow/scripts/manifest-query**
  - Target: executable bash. Usage: `manifest-query <subcommand> [args] [--file <path>]`.
    Default `--file` = `docs/prds/<first>/manifest.yaml` is NOT assumed — `--file` is
    required (explicit path), erroring with usage when absent.
  - Parser: an awk pass keyed on indentation. A list item begins at `^  - name:` /
    `^  - slug:`; fields `slug`, `name`, `status`, `dependencies`, `prd_sections`
    are captured at `^    <field>:`. `dependencies: []` / `[a, b]` parsed as a comma
    list; `description: |` blocks are skipped (consumed until the next `^  - ` or
    `^  [a-z]`). Stop piece parsing at the top-level `coverage:` key.
  - Subcommands:
    - `open` — print slugs where `status != merged`, one per line, manifest order.
    - `deps <slug>` — print that slug's `dependencies`, one per line.
      `deps <slug> --reverse` — print slugs whose `dependencies` contain `<slug>`.
    - `ready` — print slugs where `status == open` AND every dep's status is `merged`.
    - `table` — aligned columns `slug | status | deps | prd_sections`.
    - `set-status <slug> <new>` — see T-2.
  - Unknown slug (deps/set-status) → stderr error + exit 2. Unknown subcommand → usage
    + exit 64.
  - Done: all five subcommands produce output against the exec-ready fixture.
  - Verify: `bash manifest-query open --file <exec-ready-fixture>` lists 3 slugs.

  **T-2: MODIFY plugins/spec-flow/scripts/manifest-query (set-status mutation)**
  - Target: `set-status <slug> <new>` validates `<new>` ∈ {open, specced, planned,
    in-progress, merged} (status vocabulary; confirm exact set against the status
    skill state-machine table during implement). On a valid, known slug, rewrite only
    that piece's `status:` line in place (awk/sed scoped to the matched piece block);
    leave all other bytes unchanged. Unknown slug or status → stderr error, exit 2,
    no write.
  - Done: a re-parse after `set-status` shows the new value; `git diff` touches one line.
  - Verify: see Write-Tests T-5.

  **T-3: CREATE scripts/tests/fixtures/{exec-ready,shared,prop-firm}.yaml**
  - Target: copy `docs/prds/exec-ready/manifest.yaml` and `docs/prds/shared/manifest.yaml`
    into the fixtures dir; snapshot `/Volumes/joeData/prop_firm/repo/docs/prds/prop-firm/manifest.yaml`
    as `prop-firm.yaml`.
  - Done: three fixture files exist and parse.

- [x] **[Write-Tests]** scripts/tests/test-manifest-query.sh
  - **T-4 (AC-1/2/3/4):** golden assertions, python forced off (`MANIFEST_QUERY_NO_PY=1`):
    - `open --file exec-ready` → exactly `spec-preresearch\nflywheel-repo\nflywheel-global`.
    - `deps spike-agent --file exec-ready` → `plan-concrete\nsonnet-coord`.
    - `deps research-unify --reverse --file exec-ready` → includes `plan-concrete` and
      `spec-preresearch`.
    - `ready --file exec-ready` → exactly `flywheel-repo`.
    - `table --file exec-ready` → 8 data rows, column-aligned (assert header + row count).
  - **T-5 (AC-5):** copy a fixture to a temp file; `set-status flywheel-repo specced`;
    assert the entry's status is now `specced` and `diff` vs original shows exactly one
    changed line; `set-status bogus-slug specced` exits non-zero and leaves the temp file
    byte-identical.
  - Expected: all assertions pass, 0 failures.

- [x] **[Verify]**
  - Run: `bash plugins/spec-flow/scripts/tests/test-manifest-query.sh`
  - Expected: all checks pass, exit 0.

### Phase 2 (Implement track): Python fast path
**Exit Gate:** `manifest-query.py` produces output identical to the Phase 1 awk path
for all subcommands on all three fixtures.
**ACs Covered:** AC-6 (python half)
**In scope:** `plugins/spec-flow/scripts/manifest-query.py`.
**NOT in scope:** the dispatch guard (Phase 3).
**Charter constraints honored in this phase:**
- NN-C-002: OVERRIDDEN (owner-accepted) — this is the python dependency the brief documents.

- [x] **[Implement]**
  **T-1: CREATE plugins/spec-flow/scripts/manifest-query.py**
  - Target: `python3` CLI with the same subcommands/flags/exit codes as T-1/T-2 above.
    Parse YAML with the stdlib only if available (`import yaml` is NOT stdlib — do NOT
    depend on PyYAML; parse the same regular structure by hand, or note that PyYAML is a
    further dependency and is rejected). Output formatting must match the awk path
    byte-for-byte (same column widths, same ordering, same separators).
  - Done: direct invocation matches awk output on exec-ready.
  - Verify: Write-Tests T-2.

- [x] **[Write-Tests]**
  - **T-2 (AC-6, python half):** extend test-manifest-query.sh: for each subcommand and
    each fixture, diff `python3 manifest-query.py <args>` against the awk path
    (`MANIFEST_QUERY_NO_PY=1 manifest-query <args>`); assert empty diff.
  - Expected: zero diff across all subcommand × fixture combinations.

- [x] **[Verify]**
  - Run: `bash plugins/spec-flow/scripts/tests/test-manifest-query.sh`
  - Expected: all checks pass, exit 0.

### Phase 3 (Implement track): Dispatcher + parity
**Exit Gate:** `manifest-query` auto-uses python when present and the awk path when
`python3` is masked, with identical stdout.
**ACs Covered:** AC-6 (dispatch + parity half)
**In scope:** the dispatch guard at the top of `manifest-query`.
**NOT in scope:** skill, version bump.
**Charter constraints honored in this phase:**
- NN-C-005: with `python3` absent the tool still works (bash path).

- [x] **[Implement]**
  **T-1: MODIFY plugins/spec-flow/scripts/manifest-query (top-of-file guard)**
  - Anchor: immediately after arg capture, before the awk dispatch.
  - Target: `if command -v python3 >/dev/null 2>&1 && [ -z "${MANIFEST_QUERY_NO_PY:-}" ]; then exec python3 "$(dirname "$0")/manifest-query.py" "$@"; fi`
  - Done: with python3 on PATH the python path runs; with `MANIFEST_QUERY_NO_PY=1` the awk path runs.
  - Verify: Write-Tests T-2.

- [x] **[Write-Tests]**
  - **T-2 (AC-6):** parity harness — for each subcommand × fixture, assert
    `manifest-query <args>` (python auto) == `MANIFEST_QUERY_NO_PY=1 manifest-query <args>`
    (awk) byte-for-byte. Also assert that in an environment with `python3` absent (simulate
    by `MANIFEST_QUERY_NO_PY=1`) the tool still exits 0 and produces correct output.
  - Expected: zero diff; both paths exit 0.

- [x] **[Verify]**
  - Run: `bash plugins/spec-flow/scripts/tests/test-manifest-query.sh`
  - Expected: all checks pass, exit 0.

### Phase 4 (Implement track): manifest skill
**Exit Gate:** `/spec-flow:manifest` documents and invokes the tool; SKILL.md frontmatter valid.
**ACs Covered:** FR-8 (skill wrapper)
**In scope:** `plugins/spec-flow/skills/manifest/SKILL.md`.
**NOT in scope:** version bump (Phase 5).
**Charter constraints honored in this phase:**
- NN-C-003/NN-C-004: `name:` is the bare local name (`manifest`), not plugin-prefixed.
- charter-coding-rules: SKILL.md frontmatter schema (name + description).

- [x] **[Implement]**
  **T-1: CREATE plugins/spec-flow/skills/manifest/SKILL.md**
  - Target: frontmatter `name: manifest`, `description:` covering triggers ("read the
    manifest", "what's open", "what can I work on next", "what depends on X", "mark X as
    Y"). Body documents each subcommand with one concrete example invocation against a
    real manifest path, and states the python-fast-path / bash-fallback behavior.
  - Branch-enumeration ACs (one per subcommand): document `open`, `deps`/`deps --reverse`,
    `ready`, `table`, `set-status` (incl. the unknown-slug error path).
  - Done: SKILL.md parses; each subcommand has a documented invocation.

- [x] **[Verify]**
  - Run: `bash plugins/spec-flow/hooks/lint-skill-coherence plugins/spec-flow/skills/manifest/SKILL.md` (if the linter accepts a path arg; else run the repo's skill-coherence check)
  - Expected: no coherence errors for the new skill.

### Phase 5 (Implement track): status drift fix + version sync
**Exit Gate:** the `status` skill reads the real manifest fields; plugin + marketplace at 5.8.0.
**ACs Covered:** AC-7, AC-8
**In scope:** `plugins/spec-flow/skills/status/SKILL.md` (field names);
`plugins/spec-flow/.claude-plugin/plugin.json`; `.claude-plugin/marketplace.json`.
**NOT in scope:** any other status-skill behavior change.
**Charter constraints honored in this phase:**
- NN-C-001 (version sync): plugin.json and marketplace.json bump together.

- [x] **[Implement]**
  **T-1: MODIFY plugins/spec-flow/skills/status/SKILL.md**
  - Anchor: the manifest-read instruction (currently "Read the fields `id:`, `name:`,
    `status:`, and `depends_on:`" and the `grep -E '^\s{0,4}(id|name|status|depends_on):'`).
  - Target: replace `id` → `slug`, `depends_on` → `dependencies` in both the prose and the
    grep pattern, so the skill reads the schema real manifests use. Verify no other
    `id`/`depends_on` manifest references remain in the file.
  - Done: grep for `depends_on` / `\bid:` in the manifest-read section returns nothing.

  **T-2: MODIFY plugin.json + marketplace.json**
  - Target: `plugins/spec-flow/.claude-plugin/plugin.json` `"version": "5.7.0"` → `"5.8.0"`;
    `.claude-plugin/marketplace.json` spec-flow entry `"version": "5.7.0"` → `"5.8.0"`.
  - Done: both files read 5.8.0.

- [x] **[Verify]**
  - Run: `grep -nE 'depends_on|\bid:' plugins/spec-flow/skills/status/SKILL.md` (manifest-read section) — Expected: no manifest-field matches.
  - Run: version match — `grep '"version"' plugins/spec-flow/.claude-plugin/plugin.json` and the marketplace spec-flow entry both show 5.8.0.
  - Expected: fields fixed, versions in sync.

## AC Coverage Matrix

| AC | Phase | Verify step |
|----|-------|-------------|
| AC-1 | 1 | T-4 `open` golden |
| AC-2 | 1 | T-4 `deps` golden |
| AC-3 | 1 | T-4 `ready` golden |
| AC-4 | 1 | T-4 `table` golden |
| AC-5 | 1 | T-5 set-status mutation + unknown-slug |
| AC-6 | 2,3 | py-vs-awk diff + dispatch parity |
| AC-7 | 5 | version-match grep |
| AC-8 | 5 | status-skill field grep |
