# research.md — exec-ready / pipeline-e2e

## Brainstorm Inference Digest

**Piece purpose.** Build an executable end-to-end smoke test for the spec-flow pipeline's *observable contract*, as a peer to the existing coherence linter (`hooks/lint-skill-coherence` + `hooks/tests/test-lint-skill-coherence.sh`). The deliverable is a committed fixture project + a scripted bash scenario that drives a minimal piece (≥1 TDD phase, ≥1 Implement phase) and asserts: artifact existence + ordering, the required dispatch sequence (tdd-red → qa-tdd-red → implementer → verify → QA gate → board), and manifest status transitions. Plus explicit cases for two never-exercised round-trips ([SPIKE]-resolution → test-data consumption, and the [TEST-DATA-ABSENT] fallback). Failure mode: capabilities absent → report `SKIPPED: <capability>` per stage, **never false green**. Covers FR-013 (a constraint / regression insurance, not a measured feature). CI wiring is explicitly out of scope (deferred to pi-022-vsync-ci).

**The single largest design constraint — what is NOT assertable from disk.** The pipeline is LLM-orchestrated: the dispatch sequence (tdd-red, qa-tdd-red, implementer, verify, qa-phase, the 8–9 review-board agents) lives in the *orchestrator's runtime output*, not in any committed file. There is **no on-disk dispatch log**. The only durable git artifacts are commits and the files they touch. Therefore the FR-013 assertion "required dispatches occurred (tdd-red → … → board)" is **NOT directly assertable from the committed worktree** by a pure-bash test that inspects files/git. The brainstorm MUST resolve how the scenario proves dispatch order. Realistic tiers:
  - **Tier A — committed-artifact replay (fully bash, deterministic, charter-compliant):** ship a *pre-recorded* fixture worktree whose git history + files already encode the contract (research commit before first brainstorm commit; plan.md with Test Data blocks; spikes/<id>.md; learnings.md; .discovery-log.md rows; manifest status-transition commits). The test asserts against that committed history. The deliberate-break case (AC-2, "removing the qa-tdd-red step makes the test fail") is realized by a *second, broken fixture* missing the contract trace, which the test must flag — exactly the linter's clean-fixture vs defect-fixture pattern.
  - **Tier B — live-run (a real Sonnet drives execute):** not bash-only, non-deterministic, needs a model + network → these become `SKIPPED: <capability>` stages on a CI box. This is the natural home of the never-false-green SKIPPED reporting.
  The brainstorm must pick the tier split: almost certainly Tier A is the committed default (so the test runs anywhere with bash + git), and the live-run is the optional SKIPPED tier.

**Dispatch-sequence assertion — the indirect handle.** Since dispatch isn't logged, the test can assert the *observable side-effects* each dispatch leaves: a TDD phase leaves a unified commit (Red staged tests + Build production) with the test files committed and immutable; verify/QA leave no file but the phase advance leaves a `git commit` marking plan.md progress; the board leaves Final-Review `.discovery-log.md` rows (source-phase token `final-review`, source-agent ∈ {blind, spec-compliance, architecture, edge-case, prd-alignment, security, ground-truth, integration, verify-piece-full}). The "deliberate skill-contract break" is therefore best modeled as a fixture whose *artifact trace* is missing a required step's footprint — not by editing the live skill (which a smoke test can't observe at runtime anyway).

**Open ambiguities the brainstorm must resolve:**
1. **No metrics file exists.** FR-013 asserts "metrics artifact at end," but the codebase writes NO metrics file. The "session-end metrics summary" (execute SKILL.md ~1815) is *printed into the reflection-process-retro prompt*, never to disk. The end-of-piece durable artifact is `learnings.md` (Step 5). The brainstorm must decide: (a) treat `learnings.md` as the "metrics artifact" the FR means, (b) re-scope the FR's metrics assertion, or (c) propose a new metrics file (scope creep — flag against YAGNI; not in FR-013's own AC list, which names existence/ordering/dispatch/status only).
2. **Journal is ephemeral, not committed.** The deferred-commit journal (`reference/deferred-commit-journal.md`) is a single JSON file that **exists only during a deferred Phase Group and is deleted after the barrier commit; it is NEVER committed**. So "journal during groups" (PRD prose) is observable only mid-run, not in committed history. A committed-replay fixture cannot contain a journal. The brainstorm must decide whether the journal assertion is in-scope at all, and if so it forces a live/intercepted tier (or asserting the journal's *absence-after-barrier* + the barrier work-commit it produces).
3. **Fixture-project shape.** Does the fixture need to be a real runnable project (so a live execute could actually drive it), or just a committed docs/prds/<slug>/ tree + git history? Tier choice (above) decides this. The minimal piece needs ≥1 TDD + ≥1 Implement phase — the fixture's plan.md must encode both tracks.
4. **Bash-only test tree.** Charter NN-C-002 / charter-tools forbids node/python/test-frameworks; tooling MUST be bash. The peer test `test-lint-skill-coherence.sh` is the exact template (plain pass/fail counters, exit non-zero on any fail). Where does the new test live — `hooks/tests/` alongside the linter, or a new `tests/` tree? (Charter says "Test runner: None" but the linter test already lives in `hooks/tests/`; imitate it.)
5. **Spike round-trip fixture.** The [SPIKE]→test-data round-trip needs a fixture with a `[SPIKE]` plan phase, a committed `spikes/<phase-id>.md` artifact carrying a `**Test Data:**` block, and a plan.md whose phase Test Data block was populated from it. The [TEST-DATA-ABSENT] case needs a TDD phase with NO Test Data block (a "plan predating the contract") and proof the fallback emitted the marker without blocking.
6. **SKIPPED reporting granularity.** "Per stage / per capability" — define the capability list (e.g., `git`, `live-model`, `network`) and the exact `SKIPPED: <capability>` line format so it's machine-greppable and never confused with PASS.

## Codebase Conventions

- **Plain-bash assertion runner (no framework).** `hooks/tests/test-lint-skill-coherence.sh` is the canonical peer: `set -uo pipefail`; `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"`; `pass()`/`fail()` increment counters and `printf 'PASS — %s\n'` / `'FAIL — %s\n'`; helper asserters `assert_exit`, `assert_grep`, `assert_no_grep` taking `<want> <label> -- <command...>`; a final `== summary: N passed, M failed ==` line; `exit 1` iff any fail. No node, no python, no jq required.
- **Fixture files committed beside the test.** The linter test ships 6 committed `fixture-*.md` files in `hooks/tests/`; clean fixtures exit 0 / no findings, defect fixtures exit non-zero with greppable finding strings. The clean-vs-defect pair is the established way to prove a check *fires* (defect) and *doesn't false-positive* (clean) — directly reusable for the deliberate-contract-break AC.
- **Finding line grammar (greppable).** Linter blocking findings: `<file>:<line> — invariant-<N> — <detail>`; warnings: `WARNING: <file>:<line> — <detail>`. The ` — ` (space-emdash-space) separator is itself an assertion target (`assert_no_grep ' — '` proves zero findings). The e2e test should pick an equally greppable line grammar.
- **CLI tool, not a hook.** The linter (and by the named-peer analogy, this e2e test) is invoked manually / by orchestrator self-check / in CI — NOT registered in any `hooks.json`. The NN-C-005 silent-no-op + JSON-on-stdout hook contract does NOT apply (stated verbatim in the linter header). Tools live under `hooks/` but run as plain executables; `[ -x "$LINTER" ]` (executable bit) is itself asserted.
- **Conventional-commit subjects are the audit trail.** Every pipeline stage commits with a stable subject grammar (`research: …`, `manifest: mark <prd>/<piece> as <status>`, `spec: add …`, `plan: add …`, `chore(plan): amend — …`, `learnings: …`). `.discovery-log.md` rows reference resolutions by *commit subject* (greppable via `git log --grep`), never by pre-computed SHA. This makes `git log --grep "<subject>"` the primary disk-level assertion handle for "dispatch/transition fired."
- **Version-sync triple (NN-C-009 / NN-C-001).** Any plugin change bumps `plugins/spec-flow/.claude-plugin/plugin.json` (currently `5.8.0`), the root `.claude-plugin/marketplace.json`, and `plugins/spec-flow/CHANGELOG.md` — in lockstep. This piece's own ship must do the same.
- **v3 path layout.** Pipeline artifacts resolve under `docs/prds/<prd-slug>/specs/<piece-slug>/`: `spec.md`, `plan.md`, `research.md`, `learnings.md`, `ac-matrix.md`, plus `spikes/<id>.md` and `.discovery-log.md` (the latter two are the per-piece execute-time artifacts). Manifest at `docs/prds/<prd-slug>/manifest.yaml`; worktree `worktrees/...`; branch `piece/<prd-slug>-<piece-slug>`.
- **Piece-status state machine.** `open → specced → planned → in-progress → merged` (`done` is the v2 alias of `merged`; terminals also `superseded`, `blocked`). Each transition is a committed manifest edit on the piece branch with subject `manifest: mark <prd>/<piece> as <status>`.

## Cluster 1 — Peer test pattern (coherence linter + its bash test)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/hooks/lint-skill-coherence` (24.5K, executable bash) — deterministic 4-invariant linter over `skills/*/SKILL.md`; CLI, not a hook.
- `plugins/spec-flow/hooks/tests/test-lint-skill-coherence.sh` (6.7K) — the named peer: plain-bash assertion runner. **This is the file to imitate.**
- `plugins/spec-flow/hooks/tests/fixture-clean.md`, `fixture-3defect.md`, `fixture-orphan-field.md`, `fixture-phantom-step.md`, `fixture-prefix-falseneg.md`, `fixture-real-conventions.md` — committed clean/defect fixtures.
- `plugins/spec-flow/hooks/hooks.json`, `copilot-hooks.json`, `run-hook.cmd`, `session-start` — hook wiring (the linter is NOT in here; confirms CLI-not-hook).

### Dependency Map
**Dependency Map:** `test-lint-skill-coherence.sh` → invokes `../lint-skill-coherence` with fixture paths; reads only its sibling `fixture-*.md` files via `SCRIPT_DIR`. The linter itself reads `templates/pipeline-config.yaml` and `reference/*.md` (for cross-ref resolution) but the *test* depends only on the linter binary + its fixtures — self-contained, no network, no model. New e2e test should mirror this self-containment (fixtures committed beside it; no external deps).

### Test Landscape
**Test Landscape:** One existing bash test, run on demand (`bash test-lint-skill-coherence.sh`). No CI wiring, no test framework, no runner config. Pattern: per-assertion PASS/FAIL print, counter summary, non-zero exit on any failure. Clean-vs-defect fixtures prove both directions. Directory-arg expansion + temp-dir cases use `mktemp -d` with a `/tmp/...-$$` fallback and `rm -rf` cleanup.

### Pattern Catalog
**Pattern Catalog:**
```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
pass() { printf 'PASS — %s\n' "$1"; PASSES=$((PASSES + 1)); }
fail() { printf 'FAIL — %s\n' "$1"; FAILS=$((FAILS + 1)); }
assert_exit() {            # assert_exit <want> <label> -- <command...>
  local want="$1" label="$2"; shift 3
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$want" ]; then pass "${label} (exit ${got})"; else fail "${label} (want ${want}, got ${got})"; fi
}
```
```bash
echo "== summary: ${PASSES} passed, ${FAILS} failed =="
if [ "$FAILS" -ne 0 ]; then exit 1; fi
exit 0
```

## Cluster 2 — Execute orchestration observables (dispatch trace + execute-time artifacts)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/execute/SKILL.md` (2016 lines) — the orchestrator. Defines the per-phase loop, dispatch sequence, QA gates, Final Review board, and every committed artifact.
- `plugins/spec-flow/reference/deferred-commit-journal.md` (19.6K) — journal schema + lifecycle (ephemeral, never committed, deleted at barrier).
- `plugins/spec-flow/reference/ac-matrix-contract.md` (9.7K) — AC matrix schema (Build report section, persisted to orchestrator state, NOT a standalone committed file by execute — note `docs/.../ac-matrix.md` is listed in v3 layout but written elsewhere).
- `plugins/spec-flow/reference/qa-iteration-loop.md`, `coordinator-contract.md`, `flywheel.md` (`docs/patterns.yaml` lazy registry).

### Dependency Map
**Dependency Map:** execute reads plan.md + spec.md + manifest.yaml; dispatches agents (`tdd-red`, `qa-tdd-red`, `implementer`, `verify`, `refactor`, `qa-phase`, then 8–9 review-board agents). Committed outputs on the piece branch: the per-phase **unified commit** (Red staged tests + Build code), optional Refactor commit, plan.md progress commit (Step 7), `.discovery-log.md` rows (Step 6c / Step 8 / Step 4.5), `learnings.md` (Step 5), `spikes/<phase-id>.md` (Step 1c, if a `[SPIKE]` phase), manifest `in-progress` commit (before first phase). **No metrics file, no dispatch log.** Journal is written/updated/deleted entirely within a deferred Phase Group and never enters a commit.

### Test Landscape
**Test Landscape:** Zero existing tests for execute. The only verifiable disk traces a bash test can assert: (1) commit subjects via `git log --grep`; (2) committed file existence (`spikes/<id>.md`, `learnings.md`, `.discovery-log.md`); (3) Test-file immutability across the unified commit (the content-hash gate's own evidence — the staged-then-committed test paths); (4) manifest `status:` field value over the branch's commit history. The dispatch *order* is provable only via commit ordering of the side-effect commits, not via any dispatch record.

### Pattern Catalog
**Pattern Catalog:**
```
| tdd-red | staged-test manifest (paths + SHA) + summary |
| qa-tdd-red | theater-pattern verdict list |
| implementer | unified-commit SHA + AC matrix + deviations summary |
| verify | pass/fail + AC coverage summary |
| qa-phase / qa-phase-lite / mid-piece | must-fix/should-fix finding list |
| review-board (×8–9) | per-reviewer finding list by severity |
```
```markdown
| Phase | Discovery type | Source agent | Finding (1-line) | Triage choice | Resolution commit |
|---|---|---|---|---|---|
| phase_3 | requires-amendment | qa-phase | Auth helper missing X | amend | abc1234 chore(plan): amend — ... |
```
```text
Final Review .discovery-log.md rows: Phase column = literal `final-review`;
source-agent ∈ {blind, spec-compliance, architecture, edge-case,
prd-alignment, security, ground-truth, integration, verify-piece-full(fast)}.
```

## Cluster 3 — Spec/plan stage observables (ordering + status transitions)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/spec/SKILL.md` — pre-brainstorm research dispatch + `research:` commit; spec.md write; manifest `specced` transition.
- `plugins/spec-flow/skills/plan/SKILL.md` — introspection.md (uncommitted working file); plan.md write with Test Data blocks; manifest `planned` transition; spike-scan finalize.
- `plugins/spec-flow/reference/research-artifact.md` (7.7K) — research.md contract + markers.
- `plugins/spec-flow/reference/plan-concreteness.md` (12.6K, §5) — the `Test Data` block schema + [TEST-DATA-ABSENT] absent-block fallback.
- `plugins/spec-flow/templates/plan.md` (20.2K), `templates/spec.md`, `templates/manifest.yaml`.

### Dependency Map
**Dependency Map:** spec → (research agent writes research.md) → `git commit "research: add <prd>/<piece> codebase research"` **before any spec write** (this is the FR-013 "research.md before first brainstorm commit" ordering — provable by commit order). Then `manifest: mark … as specced`, then `spec: add …`. plan → `manifest: mark … as planned`, then `plan: add …`. Test Data blocks live in plan.md's `[TDD-Red]`/`[Write-Tests]` phases (plan-concreteness §5); tdd-red transcribes them verbatim; [TEST-DATA-ABSENT] is emitted when the block is absent (backward-compat). Manifest status field is the single status-transition assertion point across all three stages.

### Test Landscape
**Test Landscape:** No tests. Disk-assertable contract: (a) commit-subject ordering `research:` precedes `spec:` and any brainstorm commit; (b) plan.md contains `**Test Data:**` blocks on test-authoring phases (greppable); (c) manifest `status:` walks `open → specced → planned`; (d) [TEST-DATA-ABSENT] fixture: a plan phase with a `[TDD-Red]` step and NO Test Data block + evidence (a learnings/log line or the absence of a BLOCKED) that the fallback path ran without blocking.

### Pattern Catalog
**Pattern Catalog:**
```bash
git add docs/prds/<prd-slug>/specs/<piece-slug>/research.md
git commit -m "research: add <prd-slug>/<piece-slug> codebase research"   # BEFORE any spec write
```
```bash
git commit -m "manifest: mark <prd-slug>/<piece-slug> as specced"   # spec stage
git commit -m "manifest: mark <prd-slug>/<piece-slug> as planned"   # plan stage
git commit -m "plan: add <prd-slug>/<piece-slug> implementation plan"
```
```text
[TEST-DATA-ABSENT: no Test Data block in phase]   # tdd-red fallback, non-blocking (agents/tdd-red.md:46)
present-but-incomplete Test Data block → STOP, report `BLOCKED — Test Data gap: <case>` → Step 6c
```

## Cluster 4 — Spike round-trip + TEST-DATA-ABSENT fallback (the two never-tested paths)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/reference/spike-agent.md` (4.7K) — spike modes (`resolve`/`scope`), artifact schema, location `docs/prds/<prd>/specs/<piece>/spikes/<id>.md`, optional `**Test Data:**` block.
- `plugins/spec-flow/agents/tdd-red.md` — [TEST-DATA-ABSENT] emission (line 46) + transcribe-only contract (line 142).
- `plugins/spec-flow/skills/execute/SKILL.md` Step 1c (lines ~393–426) — [SPIKE]-phase resolution: run spike `resolve` before implementer; write its Test Data into plan.md's phase block; guard-skip if `spikes/<phase-id>.md` already exists; malformed-STATUS re-dispatch.
- `plugins/spec-flow/reference/plan-concreteness.md` §5 — Test Data block schema (canonical, cited not restated).

### Dependency Map
**Dependency Map:** [SPIKE] round-trip: execute Step 1c detects `[SPIKE:]` in a phase → dispatches spike `resolve` (Opus, isolated, ≤2K digest, `STATUS: OK|BLOCKED`) → writes `spikes/<phase-id>.md` → if artifact carries `**Test Data:**`, splices it into plan.md's phase `Test Data` block → tdd-red (Step 2.7) transcribes verbatim. Guard: if `spikes/<phase-id>.md` exists, skip re-dispatch (resume-safe); if its first `STATUS:` line is neither OK nor BLOCKED → malformed → re-dispatch. BLOCKED-but-TDD-phase-needs-data → `requires-amendment` discovery → Step 6c (no implementer). [TEST-DATA-ABSENT]: tdd-red sees a phase with no Test Data block → emits the marker → falls back to authoring from `[TDD-Red]`/`[Implement]` assertions without blocking (NN-C-003 backward-compat).

### Test Landscape
**Test Landscape:** Both round-trips are explicitly called out in FR-013 as *never tested*. Disk-assertable: (1) spike round-trip — a committed `spikes/<phase-id>.md` with a `**Test Data:**` block AND the same data appearing in plan.md's phase Test Data block AND in the committed test file → proves the splice+transcribe chain. (2) [TEST-DATA-ABSENT] — a phase with `[TDD-Red]` and no Test Data block + a committed test file authored anyway + the marker surfaced in the run (the marker itself is runtime output, so a committed-replay fixture asserts the *outcome*: tests exist, no BLOCKED commit, plan unchanged). The "STATUS:" first-line check on the spike artifact is a clean greppable assertion.

### Pattern Catalog
**Pattern Catalog:**
```text
Spike artifact: docs/prds/<prd-slug>/specs/<piece-slug>/spikes/<id>.md
**Mode:** resolve | scope
**Trigger:** <unknown or change text>
**Resolution:** <concrete answer>     # resolve mode
**Test Data:** <plan-concreteness §5 schema>   # optional — the round-trip handle
```
```text
Step 1c guard: if spikes/<phase-id>.md exists → skip dispatch (resume-safe);
read first STATUS: line — neither OK nor BLOCKED ⇒ malformed ⇒ re-dispatch.
BLOCKED + TDD phase needs data ⇒ requires-amendment discovery ⇒ Step 6c (no implementer).
```

## Cluster 5 — Plugin test-tree, hook wiring, version-sync layout

### File Inventory
**File Inventory:**
- `plugins/spec-flow/.claude-plugin/plugin.json` (version `5.8.0`), `hooks.json`.
- `plugins/spec-flow/hooks/hooks.json`, `copilot-hooks.json`, `run-hook.cmd`, `session-start` — hook wiring (linter absent → confirms CLI-not-hook).
- `plugins/spec-flow/hooks/tests/` — the existing test tree (only the linter test today).
- `.claude-plugin/marketplace.json` (repo root) — marketplace version mirror.
- `plugins/spec-flow/CHANGELOG.md` (151K) — version log.
- `plugins/spec-flow/reference/v3-path-conventions.md` — canonical artifact path table.

### Dependency Map
**Dependency Map:** Hooks are registered in `hooks/hooks.json` (SessionStart only today); the linter and any e2e test are NOT registered there — they run as plain executables. Version-sync is a hard triple: plugin.json ↔ marketplace.json ↔ CHANGELOG.md must move together (NN-C-009/NN-C-001). The new test most naturally lands in `plugins/spec-flow/hooks/tests/` beside the linter test (the only precedent), with its committed fixtures beside it — though the brainstorm may argue for a sibling `tests/` tree given the fixture *project* is larger than a single .md file.

### Test Landscape
**Test Landscape:** `hooks/tests/` is the only test directory; convention is one `test-*.sh` + sibling `fixture-*` files, run on demand. No runner, no CI config in-repo. The e2e fixture project (a full `docs/prds/<slug>/...` tree + git history) is materially larger than the linter's single-file fixtures — the brainstorm must decide whether to (a) commit a pre-built fixture git bundle / nested repo, (b) script the fixture's construction inside the test via `git init` + scripted commits in a temp dir, or (c) commit a flat fixture tree the test copies into a temp `git init`. Option (b)/(c) keep everything bash + git, no model.

### Pattern Catalog
**Pattern Catalog:**
```json
// plugins/spec-flow/.claude-plugin/plugin.json
{ "name": "spec-flow", "version": "5.8.0", "hooks": "./.claude-plugin/hooks.json" }
```
```text
v3 artifact tree (assertion targets):
docs/prds/<prd-slug>/specs/<piece-slug>/{spec.md,plan.md,research.md,learnings.md,ac-matrix.md}
                                        /spikes/<id>.md   /.discovery-log.md
docs/prds/<prd-slug>/manifest.yaml      # status: open|specced|planned|in-progress|merged
```
```bash
# temp-dir + cleanup idiom already used by the peer test:
TMPDIR_CASE="$(mktemp -d 2>/dev/null || echo /tmp/e2e-$$)"; mkdir -p "$TMPDIR_CASE"
# ... git init, scripted commits, assertions ...
rm -rf "$TMPDIR_CASE"
```
