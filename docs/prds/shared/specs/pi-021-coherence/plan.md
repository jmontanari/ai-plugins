---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-01
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
tdd: false
fast: false
---

# Plan: pi-021-coherence

**Spec:** docs/prds/shared/specs/pi-021-coherence/spec.md
**PRD Sections:** G-2, FR-004, NN-P-002
**Status:** final-review-pending

## Overview

Ship a deterministic bash coherence linter over `skills/*/SKILL.md` (4 invariants — step-reference
integrity, pointer/cross-ref integrity, config-branch parity are blocking; state-field
producer→consumer is a warning), wire it as an execute pre-Final-Review self-check + standalone/CI,
and add P2/P3 plan-authoring discipline enforced by qa-plan. No new review agent. Minor bump 5.1.0.

**Non-TDD mode:** all phases use the Implement track. Phase 1 (the linter — real bash) follows
`[Implement]` → `[Write-Tests]` (a shell-assertion runner over fixtures) → `[Verify]` (run the runner).
Phases 2–4 are docs-as-code edits whose `[Verify]` structural-grep oracle IS the test (pi-014
convention) — `[Implement]` → `[Verify]` → `[QA]`, no separate `[Write-Tests]`. The AC Coverage Matrix
is included for traceability; QA and Final Review remain intact. CR-007 (inline config-key docs) is
N/A — this piece adds no `.spec-flow.yaml` knob.

**Why serial (whole plan):** Phases 2–4 touch disjoint file scopes (execute/SKILL.md;
plan/SKILL.md + templates/plan.md + qa-plan.md; README + version files) and could be a parallel
Phase Group. But under the current default `deferred_commit: auto` (shipped by pi-015), Phase Groups
run **serially** anyway — concurrency was carved to pi-016 — so a Phase Group would add group-QA +
barrier overhead for **zero** parallelism gain. Serial flat phases are strictly cheaper here. Phase 1
must also precede 2–4 (the linter must exist before execute wires it and README documents it).

## Architectural Decisions

### ADR-1: Linter is a CLI tool housed in `hooks/`, not a harness hook
**Context:** charter-tools permits "POSIX Bash 4+ (hooks only)"; the only bash home in the plugin is `hooks/` (holds `session-start`). The linter is bash but is invoked manually / by the orchestrator / in CI, not by the harness at SessionStart.
**Decision:** place `lint-skill-coherence` in `plugins/spec-flow/hooks/` (charter-compliant bash home, same tool-class as the anticipated `jq` version-sync CI check) but treat it as a CLI with a non-zero-exit + itemized-text contract; do NOT register it in any `hooks.json`; the NN-C-005 silent-no-op / JSON-on-stdout hook contract does not apply.
**Alternatives considered:** (a) a new `scripts/` dir — deviates from the established `hooks/` bash home and charter-architecture's enumerated layout; (b) inline grep procedure in execute prose — not reusable standalone/CI, which the spec requires.
**Consequences:** reuses the existing bash location; a reader must not assume hook semantics (documented in Technical Approach + this ADR).
**Charter alignment:** charter-tools (bash, no deps), CR-008 (logic in the script), NN-C-005 (explicitly out of scope for a CLI).

### ADR-2: Config-branch parity is grounded in `pipeline-config.yaml`, not heuristic colon-matching
**Context:** invariant (3) must distinguish a real config branch (`deferred_commit: auto`) from any incidental `word: word` colon in prose.
**Decision:** the linter reads `plugins/spec-flow/templates/pipeline-config.yaml` as the authoritative key+enum source; only keys present there are subject to parity; "branch region" = nearest heading at/above a mention to the next same-or-higher heading; violation = a missing other enum value in the region.
**Alternatives considered:** (a) match any `key: value` colon — unbounded false positives; (b) a hardcoded key list in the linter — drifts from the real config.
**Consequences:** parity tracks the real config automatically; the linter has a read dependency on `pipeline-config.yaml`'s format.
**Charter alignment:** NFR (deterministic), CR-008.

### ADR-3: No new review agent — existing Final Review board is the human read
**Context:** pi-015's gaps were caught by the board's blind + integration reviewers; the linter mechanizes detection but human whole-file judgment already exists.
**Decision:** the linter is the only new gate; P1's "human whole-file read" is delegated to the existing board. The manifest's "≥3-phase dispatched-human-pass" P1 trigger is retired.
**Alternatives considered:** a dispatched coherence-review agent — added per-piece Opus cost for redundant coverage (rejected at spec brainstorm).
**Consequences:** lowest cost/scope; relies on the board continuing to read the whole diff.
**Charter alignment:** NN-P-002 (linter additive before the board, never bypassing it).

## Phases

### Phase 1: Coherence linter + fixtures + tests
**In scope:** CREATE `plugins/spec-flow/hooks/lint-skill-coherence` (the 4-invariant bash linter) and `plugins/spec-flow/hooks/tests/` (3 fixtures + a shell-assertion runner).
**NOT in scope:** execute wiring (Phase 2); plan/qa-plan P2/P3 (Phase 3); README docs + version bump (Phase 4).
**ACs Covered:** AC-1, AC-2, AC-3, AC-4 (invocation forms), AC-8, AC-9.
**Charter constraints honored in this phase:** CR-008 (all coherence logic lives in the linter script), NN-P-001 (findings are plain text), CR-009 (the linter mechanically defends step-heading reference integrity).

- [x] **[Implement]**
  - T-1: CREATE `plugins/spec-flow/hooks/lint-skill-coherence`
    Pattern (hook bash style, from `plugins/spec-flow/hooks/session-start:1-5`):
    ```
    #!/usr/bin/env bash
    set -euo pipefail
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    ```
    Structure:
    1. **Arg handling:** accept one or more paths; a directory arg expands to its `*SKILL.md` (and `skills/*/SKILL.md` when given a skills root). Build the target file list.
    2. **Per-file parse (one pass each):** collect the set of heading anchors (`^#{2,4} ` lines, normalized: strip leading `#`/space, lowercase, collapse spaces). Collect for cross-checks: (a) `Step <id>` references in prose (`Step G?[0-9]+[a-z]?`, `Step [0-9]+`); (b) pointers `§<heading>` and `reference/<doc>.md §<heading>`; (c) config-branch mentions.
    3. **Invariant 1 (step-reference integrity, BLOCK):** every referenced `Step <id>` must resolve, in the same file, to EITHER a heading anchor whose text contains that step id OR a `**Step <id>:**` bold-marker step definition (some skills define their steps as bold markers, not headings) OR a top-level ordered-list item (`N.` / `N.M`) for that id. A reference qualified with another skill's path — `<skill>/SKILL.md Step N`, `Step N of <skill>`, or `<skill>:Step N` — is an out-of-scope **cross-skill reference** (the linter cannot resolve another file's step inventory) and is NOT flagged. Otherwise unmatched → finding.
    4. **Invariant 2 (pointer/cross-ref integrity, BLOCK):** every `§<heading>` resolves to an anchor in the same file; every `reference/<doc>.md §<heading>` resolves to an anchor in that target file (read the target under `PLUGIN_ROOT/reference/`). The `reference/<doc>.md` path is commonly wrapped in inline-code backticks (e.g. `` `reference/x.md` §Heading ``) — the linter must tolerate (strip) the backticks when resolving the target. Skip `§<placeholder>` pointers whose heading text begins with an angle-bracket metavariable (output-template placeholders like `§<heading>`) — these are templates, not real anchors. Unresolved → finding.
    5. **Invariant 3 (config-branch parity, BLOCK):** read `${PLUGIN_ROOT}/templates/pipeline-config.yaml`; build `key → {enum values}` from the commented value lines (`#   <value> — …`) in the `# <key>:` captioned comment block that **precedes** each `<key>: <default>` assignment line (NOT the lines under the assignment — those belong to the next key's block). Keys: `refactor`, `merge_strategy`, `tdd`, `phase_groups`, `deferred_commit`, `reflection`. A branch region (nearest heading at/above to next same-or-higher heading) is a **branch-documentation region** for a key ONLY when it mentions **≥2 DISTINCT enum values** of that key; only then is a missing value a violation. A region mentioning a single enum value is an incidental prose reference and NEVER violates. **Consequence:** since a 2-value key needs both values present to even qualify as a branch-doc region, only ≥3-value keys (`refactor`, `tdd`, `phase_groups`) can produce a violation (region mentions ≥2 of their ≥3 values and omits another). **Boolean-pair guard:** a region whose only mentioned values of a key are exactly `{true, false}` is documenting a resolved boolean front-matter field, not the 3-value config branch — it does NOT trigger the parity check and never violates. Within a qualifying branch-documentation region, any OTHER documented enum value of the key absent from the region → finding.
    6. **Invariant 4 (state-field producer→consumer, WARNING only):** collect candidate field tokens (e.g. `[a-z_]+_(sha|hashes|manifest|state)` and journal-style snake_case keys); a token that appears in only a "write"-shaped context or only a "read"-shaped context (heuristic) → emit `WARNING: …` on stderr; NEVER change exit code.
    7. **Output + exit:** print each blocking finding as `<file>:<line> — <invariant-N> — <detail>` to stdout; print warnings as `WARNING: <file>:<line> — <detail>`. Exit non-zero iff ≥1 invariant-1–3 finding; else exit 0.
    Done: the script exists, is executable (`chmod +x`), uses only bash + grep/awk/sed, reads pipeline-config.yaml for invariant 3, and exits per invariants 1–3 only.
    Verify: see [Verify] + [Write-Tests].
  - T-2: CREATE `plugins/spec-flow/hooks/tests/fixture-clean.md` — a small SKILL.md-shaped file with ≥3 `### Step` headings, internally-consistent step refs, one valid `§` pointer, and a `deferred_commit:` region mentioning BOTH `auto` and `off`. (Lints clean.)
  - T-3: CREATE `plugins/spec-flow/hooks/tests/fixture-3defect.md` — like clean but with (a) a `Step G9z` reference and NO `### Step G9z` heading and no `**Step G9z:**` bold marker, (b) a `§Nonexistent heading` pointer, (c) a branch-documentation region for the 3-value key `phase_groups` that mentions `auto` and `always` (≥2 distinct values → a genuine branch doc) but omits the third value `off`. (Three blocking findings.)
  - T-4: CREATE `plugins/spec-flow/hooks/tests/fixture-orphan-field.md` — clean for invariants 1–3, but contains a state-field token written and never read. (One WARNING, exit 0.)
  - T-4b: CREATE `plugins/spec-flow/hooks/tests/fixture-real-conventions.md` — the regression guard for the refinements. Exercises the four real corpus conventions, each in its tolerated form, so the file lints CLEAN (exit 0): (a) a backtick-wrapped `` `reference/<doc>.md` §<heading> `` cross-ref that resolves to a real anchor in the target reference doc; (b) a `**Step <id>:**` bold-marker step definition that a `Step <id>` reference resolves to (no heading for it); (c) a cross-skill `<skill>/SKILL.md Step N` reference that the linter SKIPS (no local step N for that id); (d) an incidental single-value config mention (e.g. a `tdd: false` clause, and a `phase_groups: auto` aside) that is NOT a branch-documentation region and so never triggers parity. (Lints clean — exit 0; guards every refinement against regression.)
- [x] **[Write-Tests]**
  - T-5: CREATE `plugins/spec-flow/hooks/tests/test-lint-skill-coherence.sh`
    A plain-bash assertion runner (no test framework). For each case, run `"${SCRIPT_DIR}/../lint-skill-coherence" <fixture>`, capture stdout + exit code, and assert:
    - clean fixture → exit 0, zero `—` finding lines.
    - 3-defect fixture → exit ≠ 0, stdout contains a step-reference finding AND a pointer finding AND a branch-parity finding (grep one each).
    - orphan-field fixture → a `WARNING` line present AND exit 0.
    - real-conventions fixture → exit 0, zero `—` finding lines (the refinement regression guard: backtick cross-ref resolves, bold-marker step resolves, cross-skill ref skipped, incidental single-value config mention does not violate).
    - invocation surface: single path, two paths, and a directory each lint the expected file set.
    Print `PASS`/`FAIL` per assertion; exit non-zero if any assertion fails. Make executable.
- [x] **[Verify]** Run the behavioral test runner (this IS the test):
  - `bash plugins/spec-flow/hooks/tests/test-lint-skill-coherence.sh; echo "exit=$?"` — Expected: every assertion prints `PASS`, final line `exit=0`.
  - `plugins/spec-flow/hooks/lint-skill-coherence plugins/spec-flow/hooks/tests/fixture-3defect.md; echo "exit=$?"` — Expected: 3 `—` finding lines (one each: invariant-1, invariant-2, invariant-3) and `exit=` a non-zero value.
  - `plugins/spec-flow/hooks/lint-skill-coherence plugins/spec-flow/hooks/tests/fixture-orphan-field.md; echo "exit=$?"` — Expected: a `WARNING:` line and `exit=0`.
  - AC-8 (performance): `time plugins/spec-flow/hooks/lint-skill-coherence plugins/spec-flow/skills/*/SKILL.md` — Expected: completes; real time < 1s.
  - AC-9 (real-corpus soundness): `plugins/spec-flow/hooks/lint-skill-coherence plugins/spec-flow/skills/*/SKILL.md; echo exit=$?` — Expected: `exit=0` (zero false-positive blocking findings against the real conventions — backtick cross-refs, bold-marker steps, cross-skill refs, incidental single-value config mentions); any `WARNING:` invariant-4 lines are advisory/non-blocking and do not affect the exit code. The synthetic fixtures alone are insufficient — the real corpus is the soundness oracle.
  - `test -x plugins/spec-flow/hooks/lint-skill-coherence && echo OK` — Expected: `OK` (executable bit set).
- [x] **[QA]** ACs: AC-1, AC-2, AC-3, AC-4, AC-8, AC-9. Diff baseline: phase_1_start_sha.
- [x] **[Progress]**

### Phase 2: execute pre-Final-Review self-check wiring
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` — add a pre-board coherence-linter step in Final Review Step 1.
**NOT in scope:** the linter script itself (Phase 1); plan/qa-plan P2/P3 (Phase 3); README/version (Phase 4).
**ACs Covered:** AC-5.
**Charter constraints honored in this phase:** NN-P-002 (the linter is an additive mechanical gate placed BEFORE the board; it routes through the existing fix loop and never replaces the per-phase QA gate or the human review-board sign-off).
**Steps traversed (P2):** Final Review Step 1 (board dispatch) — the new pre-board step is inserted into this existing multi-step flow; it adds a gate before the dispatch, does not reorder or remove the existing final-review-pending marker, `git diff main..HEAD`, or the 8-agent dispatch.
**Dispatch sites (P3):** none — this phase changes no agent-dispatch contract (it adds a shell-invocation gate, not an agent flag). Stated explicitly per the P3 census requirement.

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
    Anchor: `### Step 1: Iteration 1 — Full Review (8 Parallel Agents; 9 in fast mode)` (line 1442); the `git diff main..HEAD` fence is at ~1460 and the board dispatch `Read each template from … dispatch ALL EIGHT concurrently` is at ~1463.
    CURRENT (1460-1463):
    ```
    ```bash
    git diff main..HEAD
    ```

    Read each template from `${CLAUDE_PLUGIN_ROOT}/agents/review-board-<role>.md` and dispatch ALL EIGHT concurrently with `Input Mode: Full`:
    ```
    TARGET: Insert, BETWEEN the `git diff main..HEAD` fence and the "Read each template … dispatch ALL EIGHT" line, a new sub-step **"Step 1a: Pre-board coherence linter self-check"**:
    - When `git diff main..HEAD --name-only` includes any `plugins/*/skills/*/SKILL.md`, run `bash "${CLAUDE_PLUGIN_ROOT}/hooks/lint-skill-coherence" <those changed SKILL.md paths>` before dispatching the board.
    - A non-zero exit (invariant-1–3 violation) is **must-fix**: route the findings through the existing Final-Review fix-code loop (the same loop that handles board must-fix), re-running the linter after each fix until it exits 0 or the 3-iteration circuit breaker fires.
    - `WARNING:` lines (invariant-4) are surfaced advisorily and do NOT block.
    - When the piece's diff touches no `SKILL.md`, the self-check is a silent no-op.
    - State that this is a mechanical gate that runs BEFORE — and never replaces — the human review board (NN-P-002).
    Done: the pre-board linter step exists in Final Review Step 1, with the must-fix routing, advisory-warning handling, and no-op-when-no-SKILL.md, all before the 8-agent dispatch.
    Verify: grep below.
- [x] **[Verify]** Structural oracle:
  - `grep -nE "Pre-board coherence linter|lint-skill-coherence|coherence linter self-check" plugins/spec-flow/skills/execute/SKILL.md` — Expected: the new step present in the Final Review region.
  - `grep -nE "invariant-1.3|must-fix.*fix-code loop|no-op.*SKILL.md|silent no-op" plugins/spec-flow/skills/execute/SKILL.md` — Expected: must-fix routing + no-op handling present.
  - LLM-agent-step: read the Final Review Step 1 region (lines ~1442–1466) and confirm the linter step is positioned BEFORE the "dispatch ALL EIGHT" board line and explicitly states it does not replace the board (NN-P-002).
  - Anti-drift (the board count prose is unchanged): `grep -c "dispatch ALL EIGHT" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1 (the existing board dispatch line is intact).
- [x] **[QA]** ACs: AC-5. Diff baseline: phase_2_start_sha.
- [x] **[Progress]**

### Phase 3: plan + templates + qa-plan P2/P3 discipline
**In scope:** MODIFY `plugins/spec-flow/skills/plan/SKILL.md` (P2/P3 authoring requirement + multi-step-orchestration-file definition); MODIFY `plugins/spec-flow/templates/plan.md` (optional P2/P3 header fields); MODIFY `plugins/spec-flow/agents/qa-plan.md` (criterion 27 enforcing P2/P3).
**NOT in scope:** the linter (Phase 1); execute wiring (Phase 2); README/version (Phase 4).
**ACs Covered:** AC-6.
**Charter constraints honored in this phase:** NN-C-008 (the qa-plan criterion is a check the agent performs from its injected plan context — no conversation-history assumption).
**Steps traversed (P2):** plan/SKILL.md §9b "Phase boundary declarations" (line 448) — the new P2/P3 subsection is inserted adjacent to it; the qa-plan criteria list (ends at 26) — criterion 27 is appended after it. No existing numbered step is reordered or removed.
**Dispatch sites (P3):** none — no agent-dispatch contract changes (qa-plan gains a review criterion, not a new dispatch flag). Stated explicitly per the P3 census requirement.

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/skills/plan/SKILL.md`
    Anchor: end of `9b. **Phase boundary declarations …**` (line 448 through its escalation paragraph ~458).
    TARGET: add a new subsection `9c. **P2/P3 cross-step authoring discipline (pi-021).**` defining:
    - **Definition (multi-step orchestration file):** a `skills/*/SKILL.md` with ≥3 headings matching `^#{3,4} (Step|Phase|Sub-Phase)\b`.
    - **P2:** a phase introducing a new conditional path through an existing multi-step loop/state-machine must enumerate (in a `**Steps traversed (P2):**` header field) every pre-existing step the new path traverses or invalidates.
    - **P3:** a piece changing a cross-cutting agent-dispatch contract must enumerate (in a `**Dispatch sites (P3):**` header field) every (re-)dispatch site of the affected agents; if none, state "none."
    - Both are REQUIRED only when the edited file is a multi-step orchestration file (per the Definition).
    Done: subsection 9c present with the Definition + P2 + P3 + the required-when condition.
  - T-2: MODIFY `plugins/spec-flow/templates/plan.md`
    Anchor: the phase header block fields `**In scope:**` / `**NOT in scope:**` / `**Charter constraints honored in this phase:**`. The template has THREE such header blocks: the TDD-track example (~line 62), the Implement-track example (~line 125), AND the Non-TDD-mode example (~line 180).
    TARGET: add two optional header field placeholders after `**NOT in scope:**` in ALL THREE example phase headers (TDD, Implement, and Non-TDD mode): `**Steps traversed (P2):** {{steps_or_na}}` and `**Dispatch sites (P3):** {{sites_or_none}}`, with an inline comment that they are required only when the phase edits a multi-step orchestration file. (The Non-TDD-mode header MUST carry them too — this very piece is non-TDD and its own phases use these fields.)
    Done: both header fields present in all three phase-header examples in the template.
  - T-3: MODIFY `plugins/spec-flow/agents/qa-plan.md`
    Anchor: end of criterion `26. **Integration allocation …**` (line 147), before `## Output Format` (line 149).
    TARGET: add `27. **P2/P3 cross-step authoring discipline (pi-021).**` — when a plan phase's `In scope:` edits a multi-step orchestration `SKILL.md` (≥3 `^#{3,4} (Step|Phase|Sub-Phase)\b` headings), verify the phase header contains a non-empty `**Steps traversed (P2):**` enumeration AND a `**Dispatch sites (P3):**` field (a value or explicit "none"); absence of either → must-fix. Cite the definition; quote the offending phase header as evidence.
    Done: criterion 27 present with the trigger definition + must-fix condition.
    Verify: grep below.
- [x] **[Verify]** Structural oracle (each gates a specific T-N):
  - **T-1:** `grep -nE "9c\.|P2/P3 cross-step|multi-step orchestration file|Steps traversed \(P2\)|Dispatch sites \(P3\)" plugins/spec-flow/skills/plan/SKILL.md` — Expected: subsection 9c with Definition + P2 + P3.
  - **T-2:** `grep -cE "Steps traversed \(P2\)|Dispatch sites \(P3\)" plugins/spec-flow/templates/plan.md` — Expected: ≥ 6 (both fields × three example headers — TDD, Implement, Non-TDD mode).
  - **T-3:** `grep -nE "^27\. |P2/P3 cross-step|Steps traversed \(P2\)" plugins/spec-flow/agents/qa-plan.md` — Expected: criterion 27 present.
  - **Cross-file consistency (the multi-step definition matches across the 3 files):** `grep -hE "#\{3,4\} \(Step\|Phase\|Sub-Phase\)" plugins/spec-flow/skills/plan/SKILL.md plugins/spec-flow/agents/qa-plan.md` — Expected: the SAME regex definition appears in both the plan skill and qa-plan (no drift).
- [x] **[QA]** ACs: AC-6. Diff baseline: phase_3_start_sha.
- [x] **[Progress]**

### Phase 4: README linter docs + version 5.1.0
**In scope:** MODIFY `plugins/spec-flow/README.md` (linter usage); MODIFY `plugins/spec-flow/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` (spec-flow entry) + `plugins/spec-flow/CHANGELOG.md` → 5.1.0.
**NOT in scope:** any behavior (Phases 1–3).
**ACs Covered:** AC-4 (README documentation half), AC-7.
**Charter constraints honored in this phase:** NN-C-009 (additive minor bump 5.1.0), NN-C-001 (plugin.json ↔ marketplace.json sync), NN-C-007 (Keep a Changelog), CR-004 (conventional commits).

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/README.md`
    Anchor: the `## Configuration` (line 343) / `## Extending` (line 436) region.
    TARGET: add a short `## Coherence linter` subsection documenting `hooks/lint-skill-coherence`: what it checks (the 4 invariants, 1–3 blocking, 4 warning), standalone invocation (`hooks/lint-skill-coherence <file|dir>`), the execute pre-Final-Review self-check, and how to wire it as a pre-commit hook / CI check (a one-line `git diff --name-only | grep SKILL.md | xargs … lint-skill-coherence` example).
    Done: the `## Coherence linter` subsection exists with standalone + pre-commit/CI usage.
  - T-2: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json` — `"version": "5.0.0"` → `"5.1.0"`.
  - T-3: MODIFY `.claude-plugin/marketplace.json` — the **spec-flow** entry's `"version"` → `"5.1.0"` (do NOT touch the `qa` plugin's `1.1.1`).
  - T-4: MODIFY `plugins/spec-flow/CHANGELOG.md` — insert `## [5.1.0] — <today>` below `## [Unreleased]` and above `## [5.0.0]`, with an `### Added` entry naming: the `lint-skill-coherence` coherence linter (4 invariants); the execute pre-Final-Review self-check; the P2/P3 plan-authoring discipline + qa-plan criterion 27.
    Done: README subsection + both version files at 5.1.0 + CHANGELOG 5.1.0 entry.
    Verify: grep below.
- [x] **[Verify]** Structural oracle (cross-file version sync / NN-C-001):
  - `grep '"version"' plugins/spec-flow/.claude-plugin/plugin.json` — Expected: `5.1.0`.
  - `grep -A6 '"name": "spec-flow"' .claude-plugin/marketplace.json | grep version` — Expected: `5.1.0` (and the qa entry still `1.1.1`).
  - LLM-agent-step: confirm plugin.json version == marketplace.json spec-flow entry version (both `5.1.0`) — the NN-C-001 sync invariant.
  - `grep -nE "^## \[5\.1\.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: one match.
  - `grep -nE "lint-skill-coherence|coherence linter|P2/P3" plugins/spec-flow/CHANGELOG.md` — Expected: the linter + P2/P3 named in the 5.1.0 entry.
  - `grep -nE "^## Coherence linter|lint-skill-coherence" plugins/spec-flow/README.md` — Expected: the README subsection present with the script name.
- [x] **[QA]** ACs: AC-4 (README half), AC-7. Diff baseline: phase_4_start_sha.
- [x] **[Progress]**

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | blocking invariants (step-ref, pointer, branch-parity) detected on a 3-defect fixture | COVERED | Phase 1 |
| AC-2 | clean fixture passes (exit 0) | COVERED | Phase 1 |
| AC-3 | invariant-4 warning is non-blocking (warn + exit 0) | COVERED | Phase 1 |
| AC-4 | invocation surface (single/multi/dir) + README documents pre-commit/CI | COVERED | Phase 1 (invocation), Phase 4 (README doc) |
| AC-5 | execute pre-Final-Review self-check wired (must-fix routing, no-op when no SKILL.md) | COVERED | Phase 2 |
| AC-6 | plan P2/P3 discipline + qa-plan enforcement (multi-step-orchestration-file gated) | COVERED | Phase 3 |
| AC-7 | version 5.1.0 sync (plugin.json + marketplace) + CHANGELOG entry | COVERED | Phase 4 |
| AC-8 | linter performance < 1s over all skills/*/SKILL.md | COVERED | Phase 1 |
| AC-9 | real-corpus soundness — no false positives on real skills/*/SKILL.md | COVERED | Phase 1 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `plugins/spec-flow/hooks/lint-skill-coherence plugins/spec-flow/hooks/tests/fixture-3defect.md; echo exit=$?` | 3 `—` findings (invariant-1/2/3), exit non-zero |
| AC-2 | shell | `plugins/spec-flow/hooks/lint-skill-coherence plugins/spec-flow/hooks/tests/fixture-clean.md; echo exit=$?` | no `—` finding lines, `exit=0` |
| AC-3 | shell | `plugins/spec-flow/hooks/lint-skill-coherence plugins/spec-flow/hooks/tests/fixture-orphan-field.md; echo exit=$?` | a `WARNING:` line, `exit=0` |
| AC-4 | shell | `bash plugins/spec-flow/hooks/tests/test-lint-skill-coherence.sh` (invocation cases) + `grep -nE "^## Coherence linter" plugins/spec-flow/README.md` | all assertions PASS; README subsection present |
| AC-5 | shell | `grep -nE "Pre-board coherence linter\|lint-skill-coherence" plugins/spec-flow/skills/execute/SKILL.md` | the self-check step present in Final Review Step 1 |
| AC-6 | shell | `grep -nE "9c\.\|P2/P3 cross-step" plugins/spec-flow/skills/plan/SKILL.md` + `grep -nE "^27\. " plugins/spec-flow/agents/qa-plan.md` | P2/P3 subsection + qa-plan criterion 27 present |
| AC-7 | shell | `grep '"version"' plugins/spec-flow/.claude-plugin/plugin.json` + marketplace spec-flow entry + `grep "^## \[5.1.0\]" plugins/spec-flow/CHANGELOG.md` | all read 5.1.0; CHANGELOG 5.1.0 entry present |
| AC-8 | shell | `time plugins/spec-flow/hooks/lint-skill-coherence plugins/spec-flow/skills/*/SKILL.md` | real time < 1s |
| AC-9 | shell | `plugins/spec-flow/hooks/lint-skill-coherence plugins/spec-flow/skills/*/SKILL.md; echo exit=$?` | exit 0; any findings are genuine (zero false positives vs real conventions) |

## Contracts

No TDD-track phases in this plan (all Implement track, `tdd: false`) — contracts section present for
forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs. (The one
integration boundary — execute orchestrator → linter subprocess — is verified structurally by AC-5,
per the spec's Integration Coverage block; it is a CLI exit-code contract, not a boundary-crossing
code interface, so it is not a `## Contracts` entry per the contracts-vs-integration distinction.)

## Parallel Execution Notes

All phases run **serial** (flat phases). **Why serial:** Phases 2–4 touch disjoint scopes and would
qualify as a parallel Phase Group, but under the current default `deferred_commit: auto` (shipped by
pi-015) Phase Groups dispatch **serially** — concurrency is carved to pi-016 — so a Phase Group would
add group-QA + barrier overhead for zero parallelism gain. Phase 1 must also precede 2–4 (the linter
must exist before execute wires it and the README documents it). No `[P]` markers, no Phase Groups.
