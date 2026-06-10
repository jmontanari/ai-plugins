---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: pipeline-e2e — Pipeline end-to-end smoke test

**PRD Sections:** FR-013, G-1
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** none

## Goal

Give the pipeline's orchestration prose (5,200+ skill lines, 26 agents) an executable regression check, peer to the coherence linter: a three-layer bash harness under the plugin's test tree that asserts the pipeline's *observable contract* — artifact existence and ordering, dispatch sequence, and manifest status transitions — deterministically where possible, and via operator-driven live runs where a model is genuinely required. A deliberate skill-contract break must turn the harness red; a missing capability must report `SKIPPED`, never a false green.

### Design constraints discovered at brainstorm (binding context)

1. **No on-disk dispatch log exists.** Agent dispatches live in orchestrator runtime output. The two disk-level evidence sources are (a) side-effect commits with stable conventional subjects, and (b) the Claude Code session transcript (`.jsonl` under `~/.claude/projects/`), which records every Agent/Skill tool invocation (the superpowers-suite pattern, PRD R7).
2. **Squash-merge destroys ordering evidence on `master`.** Per-stage commits exist only on live piece branches. Real merged piece directories can prove artifact *shape*, never *ordering* — hence the replay fixture.
3. **Replay fixtures cannot detect skill edits.** A fixture replays *correct* history regardless of what the prose says — hence the L1 static layer, which is where the deliberate-break AC lives.
4. **The deferred-commit journal is ephemeral** (deleted at the barrier commit). Only its *absence* in a completed tree is deterministically assertable.
5. **No metrics artifact exists yet** (FR-010 unshipped). Its assertion is capability-gated, not dropped.
6. **The harness spends zero tokens.** No `claude` invocation exists anywhere in the harness. Live runs are operator-driven in an interactive session; the harness only sets up before and verifies after.

## In Scope

- New test tree `plugins/spec-flow/tests/e2e/`: runner `run-e2e.sh`, shared assertion library, fixture builder, live-fixture setup script, committed fixture content, golden snapshot dir, README.
- **L1 — static contract checks:** ordered token assertions on the skill prose itself (dispatch sequence and artifact-contract anchors in `plugins/spec-flow/skills/execute/SKILL.md` and peers).
- **L2 — fixture replay + audit mode:** a scripted builder materializes a minimal piece's git history in a temp repo from committed plain-file fixture content; the assertion core checks artifacts, ordering, and transitions; broken-fixture variants prove every assertion fires; the same shape-checks run against any real piece directory on demand (audit mode).
- **L3 — live verification:** a baked, executable fixture project (committed spec + plan: ≥1 TDD phase with Test Data, ≥1 Implement phase, exactly one `[SPIKE]` phase, one TDD phase with no Test Data block); the operator drives `/spec-flow:execute` interactively; `--verify-live` asserts the post-run tree and greps the session transcript for the ordered dispatch sequence. Explicit cases for the two never-exercised round-trips: `[SPIKE]`-resolution → test-data consumption, and the `[TEST-DATA-ABSENT]` fallback.
- **Golden snapshot:** the verified footprint of a live run is recorded and committed, so the live contract re-asserts deterministically (and token-free) on every subsequent default run.
- Result semantics: `PASS` / `FAIL` / `SKIPPED: <capability>` / `ERROR`, linter-style summary line, meaningful exit code.
- **Charter sanctioning edit set** (minimal, one line each) authorizing the new `tests/` location and bash usage there:
  - `.claude/skills/charter-architecture/SKILL.md` plugin-internal layer list gains a `tests/ — on-demand verification suites (e2e smoke, hook tests)` entry, so the layout is enumerated rather than unsanctioned.
  - `.claude/skills/charter-tools/SKILL.md` language/runtime line is amended so POSIX Bash is sanctioned for `hooks/`, `scripts/`, and `tests/` (today it reads "hooks only" — already inaccurate since the manifest-ops change shipped `scripts/` on 2026-06-09; this edit makes the line true).
  - `.claude/skills/charter-tools/SKILL.md` "Test runner: None" claim is already false (the manifest-ops change shipped `scripts/tests/test-manifest-query.sh` without updating it); its Test runner section is amended to name all three on-demand suites — this piece's e2e runner, the coherence-linter test, and the manifest-query test (the file's own header mandates the edit).
- spec-flow minor version bump across all version-bearing files + CHANGELOG entry (NN-C-009).

## Out of Scope / Non-Goals

- **CI wiring** — FR-013 explicitly defers it to pi-022-vsync-ci. The harness is on-demand only.
- **Headless `claude -p` drive mode** — rejected at brainstorm (operator token constraint; execute's operator gates are unanswerable headlessly). The verify core is drive-agnostic, so a headless mode could be added later without rework, but none ships here.
- **Real metrics-artifact assertion** — capability-gated `SKIPPED: metrics-artifact` until the `metrics` piece ships and documents its path/schema; that piece flips the gate.
- **Mid-run journal observation** — the journal is unobservable post-run by design; only the post-run absence invariant is asserted.
- **Replacing the coherence linter** — the linter remains untouched and is complemented, not replaced (PRD AC-4).
- **Testing spec/plan brainstorm stages live** — Socratic stages are interactive by design; their contracts are covered by L1/L2 only.

## Requirements

### Functional Requirements

- **SF-1 (L1 static contract):** A static check asserts that the required dispatch-sequence tokens — `tdd-red`, `qa-tdd-red`, `implementer`, `verify`, the per-phase QA gate (`qa-phase`), and the Final Review board — appear in `plugins/spec-flow/skills/execute/SKILL.md` in contract order, and that named artifact-contract anchors (unified-commit rule, journal barrier-delete rule, `.discovery-log.md` write, `learnings.md` step, manifest transition steps) are present. The check takes the skill-file path as a parameter (default: the real plugin tree) so a deliberately broken copy is testable.
- **SF-2 (L2 fixture + builder):** Fixture content is committed as plain files (no nested `.git`, no binaries) representing a minimal piece's artifact tree at each pipeline stage, distilled from real merged exec-ready pieces. `build-fixture.sh` git-inits a temp repo (`mktemp -d`) and replays the canonical commit sequence with exact conventional subjects: `research:` → `manifest: … specced` → `spec:` → `plan:`/`manifest: … planned` → `manifest: … in-progress` → unified phase commits (≥1 TDD, ≥1 Implement) → `.discovery-log.md` row commit → `learnings:` → `manifest: … merged`. Documented `--break=<case>` flags produce single-defect variants (at minimum: research-after-spec, missing Test Data block, missing spike artifact, skipped manifest transition, surviving journal file, missing learnings).
- **SF-3 (L2 assertion core):** A target-parameterized assertion library checks, against any piece tree + its git log: (a) relative commit ordering as listed in SF-2; (b) manifest status transition sequence `open → specced → planned → in-progress → merged`; (c) every TDD phase in plan.md carries a `Test Data` block; (d) `spikes/<phase-id>.md` conforms to the spike-artifact schema (`reference/spike-agent.md`) including a `**Test Data:**` section; (e) `.discovery-log.md` rows match the documented row format; (f) `learnings.md` exists and is non-empty; (g) no journal file survives in the completed tree.
- **SF-4 (audit mode):** `run-e2e.sh --audit <piece-dir>` runs the SF-3 shape checks (c)–(g) against a real piece directory. Ordering checks (a)–(b) are reported as excluded with the squash-merge rationale, not as SKIPPED or PASS.
- **SF-5 (L3 live fixture + verify):** `setup-live.sh` materializes a self-contained fixture repo at executable state: committed minimal charter + PRD + manifest (piece status `planned`) + signed-off spec.md + plan.md containing ≥1 TDD phase with a Test Data block, ≥1 Implement phase, exactly one `[SPIKE]` phase, and one TDD phase with no Test Data block; the fixture project's production code is a trivial bash function so the run works on a bare machine. The operator drives `/spec-flow:execute` in a normal interactive session. `run-e2e.sh --verify-live <fixture-repo> [--transcript <jsonl>]` then asserts: the SF-3 checks against the resulting tree; the spike round-trip (spike artifact exists with resolution + Test Data, and the consuming TDD phase's committed tests use the spike's recorded oracle); and, from the session transcript, the ordered dispatch sequence (tdd-red → qa-tdd-red → implementer → verify for the TDD phase; no tdd-red for the Implement phase; board dispatch at Final Review) plus the `[TEST-DATA-ABSENT]` marker emission for the no-Test-Data phase. Transcript resolution: explicit `--transcript` flag, else newest `.jsonl` in the `~/.claude/projects/` directory derived from the fixture path; unresolvable or unparseable → `SKIPPED: transcript` (tree checks still run).
  - **Deterministic substrate (no live run required):** a committed **synthetic post-run fixture** makes the first-pass `--verify-live` assertion code self-testable without an operator run. It has two parts, each with a clean and a broken variant (same clean/defect pair pattern as the L2 builder): (i) a sample completed-run tree fragment (`fixtures/post-run/clean/` and `fixtures/post-run/broken/`) carrying the post-run artifacts the tree + spike round-trip assertions read; and (ii) a hand-authored, sanitized, minimal sample transcript `.jsonl` (`fixtures/transcript/clean.jsonl` and `fixtures/transcript/broken.jsonl`) conforming to the documented transcript shape, so the ordered-dispatch and `[TEST-DATA-ABSENT]` greps are exercised against a fixed input. `run-e2e.sh --verify-live <fixtures/post-run/...> --transcript <fixtures/transcript/...>` therefore runs the full verify-live assertion path deterministically: the clean pair must PASS and each broken variant must FAIL the targeted assertion — with zero tokens and no live run.
- **SF-6 (golden snapshot):** After a `--verify-live` pass with zero FAIL, `--record-golden` writes the run's footprint (file inventory with content digests of contract-bearing files, ordered commit-subject list, ordered dispatch-sequence extract from the transcript) to `tests/e2e/golden/` as plain text for commit. Default `run-e2e.sh` runs re-assert the committed golden footprint deterministically; absent golden → `SKIPPED: live-run`. The README documents when to re-record (any contract change).
- **SF-7 (result semantics):** Every check yields exactly one of `PASS`, `FAIL` (assertion false), `SKIPPED: <capability>` (capability ∈ {`live-run`, `transcript`, `metrics-artifact`}), or `ERROR` (infra fault — builder failure, unreadable target). Summary line `== summary: N passed, M failed, S skipped, E errors ==`; exit 0 iff `M == 0 && E == 0`. A skipped or errored check is never counted or rendered as PASS.
- **SF-8 (runner + docs):** `run-e2e.sh` with no flags runs L1 + L2 + golden re-assert and completes in under 60 seconds on a developer machine. `tests/e2e/README.md` documents every mode (default, `--break` self-test, `--audit`, the manual live procedure, `--verify-live`, `--record-golden`), the capability list, and the token-cost note for live runs (operator-chosen, never harness-initiated).

### Non-Functional Requirements

- **SN-1 (zero-dependency):** Pure POSIX bash 4+ plus `git` and standard userland (`grep`, `sed`, `mktemp`). No jq, no python, no node, no network (NN-C-002 / charter-tools).
- **SN-2 (zero harness token spend):** No code path in the harness invokes `claude` or any model. Live-run tokens are always spent by the operator in a session they drive.
- **SN-3 (fragile-external honesty):** The session-transcript location and schema are an external Claude Code contract. Any drift (path not found, schema mismatch) degrades to `SKIPPED: transcript` with a stderr note — never FAIL, never silent PASS.
- **SN-4 (additive only):** No existing file's behavior changes except the charter sanctioning edit set (one line each in `charter-architecture` SKILL.md's layer list and two lines in `charter-tools` SKILL.md — the language/runtime line and the test-runner section), which document new capability rather than alter behavior. Existing linter, hooks, and skills are untouched (NN-C-003).

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-001 (version/marketplace sync): the release commit bumps all four version-bearing files per `plugins/spec-flow/docs/releasing.md` — `plugins/spec-flow/.claude-plugin/plugin.json`, `plugins/spec-flow/plugin.json` (Copilot CLI host descriptor), the spec-flow entry in `.claude-plugin/marketplace.json`, and `plugins/spec-flow/CHANGELOG.md` — to the same new minor version together.
- NN-C-002 (no runtime deps): harness is bash 4+ + git only (SN-1); fixture project code is bash so the live run needs nothing installed.
- NN-C-003 (backward compat): purely additive minor; no public surface removed or renamed (SN-4).
- NN-C-006 (no destructive ops): `rm -rf` is confined to the harness's own `mktemp -d` temp dirs, mirroring the linter test idiom; no operation touches repo state outside them.
- NN-C-009 (always bump version): ships as a spec-flow **minor** bump across all four version-bearing files per `plugins/spec-flow/docs/releasing.md` — `plugins/spec-flow/.claude-plugin/plugin.json`, `plugins/spec-flow/plugin.json` (Copilot CLI host descriptor), the spec-flow entry in `.claude-plugin/marketplace.json`, and `plugins/spec-flow/CHANGELOG.md`. **Minor is the correct tier** — the change is additive new files inside the plugin (the `tests/e2e/` tree), which is the minor-tier row's "new optional capability / backward-compatible addition." Checking each major-tier trigger explicitly: *"Removed or renamed config keys/skills/agents/templates"* — none removed or renamed (SN-4). *"Changed behavior of existing features"* — no existing feature's behavior changes; the harness only reads existing artifacts (SN-4). *"Changed file-layout expectations affecting existing user projects"* — does **not** fire: the new `tests/` tree ships *inside the plugin*; no user repo's on-disk layout changes, so nothing forces a user to update their project. The charter sanctioning edits document a new capability; they are not a behavior change. No major-tier trigger fires, so minor stands.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-005 (Opus thinking / Sonnet mechanics): the harness never overrides model placement — the live run inherits the pipeline's own policy (execute on Sonnet, spike on Opus); the harness itself invokes no model (SN-2).

### Coding Rules Honored

- CR-004 (conventional commits): all piece commits use `<type>(spec-flow): …`; the fixture builder reproduces the pipeline's documented commit subjects verbatim.
- CR-005 (repo-root-relative paths): README and all docs reference files repo-root-relative.
- CR-009 (heading hierarchy): README and this spec use semantic H1/H2/H3 levels.

## Acceptance Criteria

AC-1: Given the unmodified plugin tree, When `run-e2e.sh` runs with no flags, Then L1 reports PASS for the ordered dispatch-sequence tokens and the artifact-contract anchors in `execute/SKILL.md`, and the default run completes in under 60 seconds.
  Independent Test: run on a clean checkout; check summary counters and `time` output.

AC-2: Given a temp copy of `execute/SKILL.md` with the qa-tdd-red step removed, When L1 runs against that copy via its path parameter, Then the run FAILs naming `qa-tdd-red` as the missing/misordered token.
  Independent Test: `sed`-delete the step in a temp copy, point L1 at it, assert non-zero exit + named token in output. (This is PRD AC-2's deliberate-break case, made deterministic.)

AC-3: Given the clean replay fixture from `build-fixture.sh`, When the L2 assertion core runs against it, Then all SF-3 checks PASS — including `research:` preceding the first spec-stage commit, the full manifest transition sequence in order, a Test Data block on every TDD phase, a schema-conformant spike artifact, well-formed `.discovery-log.md` rows, non-empty `learnings.md`, and no surviving journal file.
  Independent Test: run builder + core in a temp dir on a machine with only bash + git.

AC-4: Given each documented `--break=<case>` fixture variant (minimum six per SF-2), When the assertion core runs, Then exactly the targeted check FAILs and the run exits non-zero — proving each assertion fires.
  Independent Test: loop all `--break` cases; assert per-case the expected check name appears as FAIL.

AC-5: Given a real merged piece directory (e.g. `docs/prds/exec-ready/specs/flywheel-repo`), When `run-e2e.sh --audit <dir>` runs, Then shape checks (c)–(g) execute against it, ordering checks are reported as excluded with the squash-merge rationale, and the exit code reflects shape results only.
  Independent Test: run against flywheel-repo's committed tree; verify exclusion note and per-check output.

AC-6: Given `setup-live.sh`, When run, Then it produces a self-contained fixture repo at executable state per SF-5 (planned manifest, signed-off spec + plan with ≥1 TDD phase with Test Data, ≥1 Implement phase, exactly one `[SPIKE]` phase, one TDD phase without a Test Data block), and the L2 shape checks targeting it confirm the baked artifacts are well-formed.
  Independent Test: run setup, then `--audit` the fixture's piece dir; inspect plan.md for the four required phase shapes.

AC-7: Given the live fixture's post-run tree assertions (including the spike round-trip: `spikes/<phase-id>.md` exists with a resolution and `**Test Data:**` section, and the consuming TDD phase's committed tests embed the spike's recorded oracle values — asserts the real wired path, not isolation), When `run-e2e.sh --verify-live` runs them, Then they PASS on a correct tree and FAIL on a defective one.
  Independent Test (deterministic, on-demand): run `--verify-live` against the committed synthetic post-run fixture — `fixtures/post-run/clean/` PASSes; `fixtures/post-run/broken/` FAILs the targeted tree/round-trip assertion; round-trip values greppable in both spike artifact and committed test file. No tokens, no live run.
  Independent Test (live integration, FR-013 round-trip): one operator-driven `/spec-flow:execute` run on the baked live fixture (operator tokens), then pure-bash `--verify-live <fixture-repo>` over the real resulting tree. This exercises the real pipeline writing the tree; it is no longer the only path to exercising the assertion code (the deterministic test above covers that).

AC-8: Given a session transcript, When `--verify-live` resolves it (flag or newest-`.jsonl` default), Then transcript assertions PASS on a well-formed transcript: tdd-red → qa-tdd-red → implementer → verify in order for the TDD phase, no tdd-red dispatch for the Implement phase, a Final Review board dispatch, and a `[TEST-DATA-ABSENT]` marker emission for the no-Test-Data phase; FAIL on a defective transcript; Given no resolvable transcript, Then those checks report `SKIPPED: transcript` while tree checks still run.
  Independent Test (deterministic, on-demand): run `--transcript fixtures/transcript/clean.jsonl` → transcript checks PASS; `--transcript fixtures/transcript/broken.jsonl` (e.g. out-of-order dispatch or missing `[TEST-DATA-ABSENT]`) → targeted check FAILs; corrupt the jsonl path → `SKIPPED: transcript` branch with tree checks still running. No tokens, no live run.
  Independent Test (live integration, FR-013 round-trip): resolve the real transcript from the operator-driven run of AC-7's live half (flag or newest-`.jsonl` default) and assert the same ordered-dispatch sequence against it.

AC-9: Given a `--verify-live` pass with zero FAIL, When `--record-golden` runs, Then a plain-text footprint (file inventory + digests, ordered commit subjects, dispatch-sequence extract) lands under `tests/e2e/golden/` and subsequent no-flag runs re-assert it deterministically; Given no committed golden, Then the default run reports `SKIPPED: live-run` for that section.
  Independent Test: record, re-run default (PASS), mutate one golden line (FAIL), delete golden dir (SKIPPED).

AC-10: Given the metrics artifact does not exist (FR-010 unshipped), When any mode runs, Then the metrics check reports `SKIPPED: metrics-artifact` — and the check is implemented as a capability probe so it flips to a real assertion when the metrics piece documents its artifact path.
  Independent Test: assert the SKIPPED line today; create a stub file at the probed path and assert the check engages.

AC-11: Given any combination of PASS/FAIL/SKIPPED/ERROR results, When a run completes, Then the summary line `== summary: N passed, M failed, S skipped, E errors ==` is printed, exit code is 0 iff `M == 0 && E == 0`, and no skipped or errored check is rendered as PASS anywhere in the output.
  Independent Test: drive each outcome class (clean run, --break run, no-golden run, unreadable target) and assert summary + exit code per class.

AC-12: Given the piece ships, When the release lands, Then `tests/e2e/README.md` documents every mode and the manual live procedure with its token-cost note; the charter sanctioning edit set is present — `charter-architecture` SKILL.md's plugin-internal layer list includes a `tests/` entry, `charter-tools` SKILL.md's language/runtime line sanctions bash for `hooks/`, `scripts/`, and `tests/`, and its test-runner section names all three on-demand suites; the coherence linter and its test are unmodified; and all four version-bearing files per `plugins/spec-flow/docs/releasing.md` (`plugins/spec-flow/.claude-plugin/plugin.json`, `plugins/spec-flow/plugin.json`, the spec-flow entry in `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md`) carry the same new minor version. The bump is **minor, not major**: the only file-layout change is a new `tests/` tree *inside the plugin* (no existing user project's layout changes — user repos are untouched), nothing is removed or renamed, and no existing feature's behavior changes (SN-4); the charter edits document a new optional capability, they do not alter existing behavior — see the NN-C-009 honoring line for the per-trigger justification.
  Independent Test: NN-C-001 jq diff; `git diff` shows no linter changes and the three charter edits present; README section checklist.

## Technical Approach

**Layout** (new tree; nothing under `hooks/` because this is not a hook test). This `tests/` tree is a *new* plugin-internal layer not previously enumerated by charter-architecture; the In-Scope charter sanctioning edit set resolves the deviation by adding `tests/` to charter-architecture's plugin-internal layer list and sanctioning bash there in charter-tools, so the location is charter-blessed rather than ad hoc:

```
plugins/spec-flow/tests/e2e/
├── run-e2e.sh            # entry point; mode dispatch; summary + exit code (SF-7/8)
├── lib/assert.sh         # target-parameterized assertion core (SF-3)
├── lib/static.sh         # L1 ordered-token checks (SF-1)
├── build-fixture.sh      # L2 replay builder + --break variants (SF-2)
├── setup-live.sh         # L3 baked fixture repo materializer (SF-5)
├── fixtures/
│   ├── replay/           # per-stage artifact files the builder commits (L2)
│   ├── live-project/     # charter/PRD/manifest/spec/plan + trivial bash code (L3 live)
│   ├── post-run/         # synthetic completed-run tree: clean/ + broken/ (verify-live deterministic substrate, SF-5)
│   └── transcript/       # hand-authored sample transcripts: clean.jsonl + broken.jsonl (verify-live deterministic substrate, SF-5)
├── golden/               # committed live-run footprint (SF-6)
└── README.md             # modes, capabilities, live procedure, re-record policy (SF-8)
```

**Data flow:** committed fixture files → builder replays commits into `mktemp -d` repo → assertion core reads `git log --format` + files → counters → summary + exit. Audit mode and `--verify-live` point the same core at real trees. Transcript checks `grep` the session `.jsonl` for ordered Agent-dispatch records (superpowers pattern). Cleanup is `rm -rf` of the harness's own temp dirs only.

**Assertion granularity:** ordering asserts *relative* order of the SF-2 subject sequence (robust to extra interleaved commits like fix-ups); subjects are grepped as anchored prefixes (`research:`, `manifest: mark`, etc.). Dispatch-sequence transcript greps match the agent identifiers recorded in tool-use entries, in document order.

**Fixture content provenance:** distilled (minimal, sanitized) from real merged exec-ready pieces, not verbatim copies — realistic shapes at minimal size; regenerating guidance lives in the README.

**Result vocabulary** is fixed in `lib/assert.sh` so every layer reports identically; capability probes are single functions (`have_golden`, `have_transcript`, `have_metrics_artifact`) — one place to flip when FR-010 ships.

## Testing Strategy

- **Self-test via fixture pairs (unit-equivalent, ~60%):** every assertion is proven both ways — clean fixture PASS (AC-3) and `--break` variant FAIL (AC-4); L1 proven via the deliberate-break copy (AC-2); the `--verify-live` tree, spike-round-trip, and transcript assertions proven against the committed synthetic post-run fixture and sample transcripts — clean PASS, broken FAIL (AC-7/AC-8 deterministic halves) — with no live run. The clean/defect pair pattern is inherited from `hooks/tests/test-lint-skill-coherence.sh`.
- **Integration (~30%):** audit mode against a real merged piece (AC-5); golden-snapshot record/re-assert/mutate cycle (AC-9); capability-gate branches (AC-8, AC-10).
- **E2E (~10%, operator-driven):** one manual live run through the baked fixture exercising both never-tested round-trips end-to-end (AC-7/AC-8 live halves) — the integration-level validation that the real pipeline writes the asserted tree and transcript — then recorded as golden so the cost is paid once per contract change. The assertion code itself is already covered deterministically by the synthetic post-run fixture (above), so this run validates the pipeline, not the harness.
- Track choice (TDD vs Implement) per phase is decided at plan time per `.spec-flow.yaml` `tdd: auto`; the assertion library and builder are behavior-bearing bash and TDD-eligible.

## Integration Coverage

- Integration: harness→git — inside: builder + assertion core; doubled externals: none (real git exercised in every run); AC-3/AC-4; completes with L2.
- Integration: harness→session-transcript (external Claude Code contract) — inside: `--verify-live` transcript checks; doubled external: committed sample transcripts (`fixtures/transcript/clean.jsonl` + `broken.jsonl`) drive the parse/grep path deterministically, plus the transcript-absence path (`SKIPPED: transcript`, AC-8) and the committed golden extract as the durable stand-in; AC-8/AC-9.
- Integration: pipeline→fixture (the real `/spec-flow:execute` writing the live fixture tree) — operator-driven, asserted post-hoc by the same core; AC-7. No `claude` invocation exists inside the harness boundary (SN-2).

## Open Questions

None. (Transcript resolution defaulting, metrics gating, and journal scope were resolved at brainstorm — see Design constraints and SF-5/SF-6/SF-7.)
