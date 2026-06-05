---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-01
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: pi-021-coherence

**PRD Sections:** G-2, FR-004, NN-P-002
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** none

## Goal

Catch the class of cross-step wiring defect that per-phase QA structurally cannot see — where each phase's edit to a large multi-step orchestration file (`skills/*/SKILL.md`) passes its own isolated QA, yet the *assembled* file is internally incoherent (a step references another step that doesn't exist; a `§heading` pointer is dangling; a config-branch documents `auto` but forgets `off`). This is the exact failure mode that produced ~6 must-fix findings at pi-015's end-of-piece review board after every per-phase QA had passed clean. The fix is a deterministic **bash/grep coherence linter** over `skills/*/SKILL.md`, wired as an execute pre-Final-Review self-check (so a piece's own edits are caught before the board) and runnable standalone / in CI (repo-wide drift), plus lightweight plan-authoring discipline (P2/P3) that qa-plan enforces. No new review agent — the existing Final Review board remains the human read.

## In Scope

- A POSIX-bash coherence linter (`plugins/spec-flow/hooks/lint-skill-coherence`) checking, over one or more `SKILL.md` files: (1) step-reference integrity, (2) pointer/cross-ref integrity, (3) config-branch parity — these three are **blocking** (non-zero exit) — plus (4) state-field producer→consumer as a **non-blocking warning**.
- Standalone invocation: one file, multiple files, or all `skills/*/SKILL.md`; documented for use as a pre-commit hook / CI check.
- An execute-skill pre-Final-Review self-check: run the linter over the piece's edited `skills/*/SKILL.md`; treat invariant-1–3 violations as must-fix (routed through the existing fix loop), invariant-4 warnings as advisory. Skipped when the piece touches no `SKILL.md`.
- Plan-authoring discipline (additions to the plan skill + plan template): **P2** — a phase introducing a new conditional path through an existing multi-step loop/state-machine must enumerate every pre-existing step the path traverses or invalidates; **P3** — a piece changing a cross-cutting agent-dispatch contract must enumerate every (re-)dispatch site of the affected agents. qa-plan flags a missing P2/P3 enumeration as must-fix when the plan edits a multi-step orchestration file.
- Minor version bump (additive) to 5.1.0 across `plugin.json`, the `marketplace.json` spec-flow entry, and `CHANGELOG.md`.

## Out of Scope / Non-Goals

- **No new coherence-review agent.** The linter is the mechanical gate; the existing Final Review board (blind + integration reviewers) is the human whole-file read. (The "human-gate-centric" and "both/balanced" approaches were considered and rejected for cost/scope.)
- **No semantic data-flow verification.** Invariant (4) is a syntactic heuristic warning only — the linter does not attempt to prove a field written in step A is correctly consumed in step B (beyond name presence); semantic correctness remains the board's job.
- **Not a general markdown linter.** It checks only the four cross-step invariants over `skills/*/SKILL.md`; it does not enforce prose style, spelling, or full CommonMark conformance. (CR-009 heading hierarchy beyond what invariant 1 implies is out of scope.)
- **No mandatory CI wiring.** The piece ships the linter and documents how to wire it as a pre-commit/CI check; it does not force a CI configuration onto consumer projects (NFR-002/charter-tools: no required runtime).
- **Retires the manifest's P1 dispatched-human-pass trigger.** The manifest's P1 "≥3-phase single-file, dispatched between the last phase's QA and Final Review" human-pass trigger is intentionally REPLACED by (a) the mechanical linter self-check on any `SKILL.md`-touching diff (FR-4) and (b) the existing Final Review board as the whole-file human read — no separate dispatched pass and no "≥3 phases" gate.

## Requirements

### Functional Requirements

**Definition (multi-step orchestration file):** a `skills/*/SKILL.md` is a **multi-step orchestration file** if it contains ≥3 headings matching `^#{3,4} (Step|Phase|Sub-Phase)\b`. This definition is reused by FR-5, FR-6, and AC-6.

- **FR-1 (linter — blocking invariants):** `plugins/spec-flow/hooks/lint-skill-coherence` accepts one or more `SKILL.md` paths (or a directory) and checks: (1) **step-reference integrity** — every `Step <id>` / `Step G<n>` referenced in prose resolves, in the same file, to **either** an actual heading **or** a `**Step <id>:**` bold-marker step definition (some skills define their steps as bold markers, not headings); a reference qualified with another skill's path (e.g. `execute/SKILL.md Step 6c`, `<skill>/SKILL.md Step N`) is an out-of-scope **cross-skill reference** and is NOT flagged (the linter cannot resolve another file's step inventory); (2) **pointer/cross-ref integrity** — every `§<heading>` and `reference/<doc>.md §<heading>` pointer (the `reference/<doc>.md` path is commonly wrapped in inline-code backticks — the linter must tolerate that) resolves to a real heading in the target file; (3) **config-branch parity** — for every config key documented in `plugins/spec-flow/templates/pipeline-config.yaml`, a **branch-documentation region** for that key must mention ALL of the key's documented values. Defined precisely:
  - **Authoritative key+value set:** `plugins/spec-flow/templates/pipeline-config.yaml` is the source of truth. The linter reads it to learn the set of config keys and each key's documented value enum (e.g. `deferred_commit: {auto, off}`, `phase_groups: {auto, always, off}`). Only keys present in `pipeline-config.yaml` are subject to the parity check — this distinguishes a real config branch from an incidental `word: word` colon in prose.
  - **Config-branch mention:** a prose occurrence of `<key>: <value>` (in inline code or plain text) where `<key>` is one of those authoritative keys and `<value>` is one of that key's enum values.
  - **Branch region:** the enclosing section — from the nearest heading at or above the mention to the next heading of the same-or-higher level.
  - **Branch-documentation region (the parity trigger):** a branch region is a *branch-documentation region* for a key only when it mentions **≥2 DISTINCT enum values** of that key. A region that mentions only a single enum value of a key is an **incidental prose reference** (e.g. an explanatory "the plan uses non-TDD mode (`tdd: false`)" clause) — NOT a branch doc — and is never a parity violation for that key. This is the false-positive guard: parity is enforced only where the prose is actually documenting a branch (≥2 values), not wherever a value is mentioned in passing.
  - **Violation:** within a *branch-documentation region* of a key (≥2 distinct values present), any OTHER documented enum value of that key that does not also appear (in prose or code) somewhere in that region. (Consequence: a 2-value key like `deferred_commit: {auto, off}` can only violate when a region mentions exactly one of `auto`/`off` — which is NOT a branch-documentation region — so a 2-value key never produces a violation; parity violations require a ≥3-value key, e.g. `phase_groups: {auto, always, off}`, whose region mentions 2 values and omits the 3rd.)
  Any violation of 1–3 → the script exits non-zero and prints an itemized finding (`<file>:<line> — <invariant> — <detail>`).
- **FR-2 (linter — warning invariant):** the script additionally emits invariant (4) **state-field producer→consumer** findings (a journal/state field name written in one step with no read elsewhere, or read with no write) as non-blocking **WARNING** lines that never change the exit code.
- **FR-3 (linter — invocation surface):** the script runs over a single file, an explicit file list, or all `skills/*/SKILL.md` repo-wide; it reads only the given files (no network, no writes), and its usage as a pre-commit hook and a CI check is documented in `plugins/spec-flow/README.md` (or a reference doc).
- **FR-4 (execute pre-Final-Review self-check):** when a piece's cumulative diff (`git diff <merge-base>..HEAD`) touches any `skills/*/SKILL.md`, the execute skill runs the linter over those changed files immediately before dispatching the Final Review board. Invariant-1–3 violations are **must-fix** — routed through the existing fix-code loop (the same loop that handles board must-fix), re-running the linter until clean or the circuit breaker fires. Invariant-4 warnings are surfaced advisorily and do not block. When the piece touches no `SKILL.md`, the self-check is a silent no-op. **Trigger asymmetry (intentional):** the linter self-check (FR-4) fires on a diff to ANY `skills/*/SKILL.md`, NOT only multi-step orchestration files — step-ref and pointer integrity benefit any skill, and config-branch parity is simply a no-op on a file with no config branches. The P2/P3 plan discipline (FR-5/FR-6), by contrast, fires only when the edited file is a *multi-step orchestration file* (per the definition above), because P2/P3 only matter where a multi-step loop exists. The two triggers differ by design.
- **FR-5 (plan-authoring discipline P2/P3):** the plan skill and plan template require, for a phase that introduces a new conditional path through an existing multi-step loop/state-machine, an explicit enumeration of every pre-existing step the new path traverses or invalidates (P2); and, for a piece that changes a cross-cutting agent-dispatch contract, an enumeration of every (re-)dispatch site of the affected agents (P3).
- **FR-6 (qa-plan enforcement):** qa-plan flags a missing P2 or P3 enumeration as a **must-fix** finding when the plan under review edits a multi-step orchestration `SKILL.md` (per the Definition above); it does not require the enumeration for plans that touch no such file.
- **FR-7 (version + changelog):** bump `plugins/spec-flow/.claude-plugin/plugin.json` and the `marketplace.json` spec-flow entry to `5.1.0`, and add a Keep-a-Changelog `## [5.1.0]` entry documenting the linter + the execute self-check + the P2/P3 plan discipline. Additive minor bump (NN-C-009).

### Non-Functional Requirements

- **Performance:** the linter completes in < 1s wall-clock over the full `skills/*/SKILL.md` set on a warm cache (it is grep/awk over a handful of markdown files). This < 1s bound is the SLO; it is the budget that makes the linter cheap enough to run on every pre-Final-Review and as a pre-commit hook. Verified by **AC-8**.
- **NFR-001/002 (offline, no deps):** the linter uses only POSIX bash + standard text utilities (grep/awk/sed) already required by the toolchain — no new runtime dependency, no network. Runs fully offline.
- Latency / throughput / observability / operational-readiness SLOs: **N/A** — this is skill/tooling content, not a runtime service.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- **NN-C-009** (always bump version, per-semver scope): additive feature (new linter gate + plan discipline, no existing behavior removed) → **minor** bump 5.1.0 across `plugin.json` + `marketplace.json` + `CHANGELOG.md`.
- **NN-C-001** (plugin.json ↔ marketplace.json version sync): both move to 5.1.0 together; the linter itself is unrelated to NN-C-001 (that sync check is pi-022's CI job).
- **NN-C-007** (Keep a Changelog): a 5.1.0 entry documents the linter, the execute self-check, and the P2/P3 plan discipline.
- **NN-C-008** (self-contained agent prompts): the qa-plan change is a check the agent performs from its injected plan context; it adds no conversation-history assumption.

**Product (NN-P — from `docs/prds/shared/prd.md`):**
- **NN-P-002** (no auto-merge without explicit human sign-off at two gates): the linter is an **additive mechanical gate placed before** the Final Review board — it never replaces or bypasses the per-phase QA gate or the end-of-piece human review board. A clean linter run is a precondition the board still runs on top of; a linter must-fix routes through the same fix loop, then the board still adjudicates.
- **NN-P-001** (artifacts human-readable): the linter and its findings are plain text; no binary output.

### Coding Rules Honored

- **CR-008** (thin-orchestrator skills, narrow-executor agents): the coherence-check logic lives in the linter script (a hook-class tool) and is *invoked* by the execute orchestrator; the qa-plan agent gains a plan-completeness check but no orchestration logic, and no agent spawns sub-agents.
- **CR-009** (semantic heading hierarchy): honored in the edited SKILL/README/CHANGELOG sections — and, recursively, invariant (1) of the linter mechanically defends a subset of this rule (step-heading reference integrity) going forward.
- **CR-004** (conventional commits with plugin scope): all commits use conventional messages.
- **CR-007** (config keys documented inline): N/A — this piece adds no new config key (the linter has no `.spec-flow.yaml` knob; it runs unconditionally on SKILL.md-touching pieces).

## Acceptance Criteria

**AC-1 (blocking invariants detected):** Given a fixture `SKILL.md` containing (a) a `Step G9z` reference with no `### Step G9z` heading and no `**Step G9z:**` bold-marker definition, (b) a `§Nonexistent heading` pointer, and (c) a branch-documentation region for the 3-value key `phase_groups` that mentions `auto` and `always` but omits `off` (a genuine ≥2-values branch doc missing a value — not an incidental single-value mention), When `lint-skill-coherence <fixture>` runs, Then it exits non-zero and prints one itemized finding per violation naming the invariant and the offending line.
  Independent Test: run the linter on the three-defect fixture; assert exit code ≠ 0 and that stdout contains a step-reference finding, a pointer finding, and a branch-parity finding (one each).

**AC-2 (clean file passes):** Given a fixture `SKILL.md` with all step references, pointers, and config branches internally consistent, When the linter runs, Then it exits 0 with no blocking findings.
  Independent Test: run the linter on the clean fixture; assert exit code 0 and no `—` finding lines on stdout.

**AC-3 (warning is non-blocking):** Given a fixture with a state-field name written but never read (invariant 4), When the linter runs and there are no invariant-1–3 violations, Then it prints a `WARNING` line for the orphan field AND exits 0.
  Independent Test: run the linter on the orphan-field fixture; assert a `WARNING` line is emitted AND exit code is 0.

**AC-4 (invocation surface):** Given the linter, When invoked with a single path, with multiple paths, and with a directory of `SKILL.md` files, Then each form is accepted and lints exactly the resolved set; and the README documents the pre-commit-hook and CI invocation.
  Independent Test: run all three invocation forms over fixtures and assert each lints the expected file set; grep the README for the pre-commit/CI usage section.

**AC-5 (execute pre-Final-Review self-check wired):** Given a piece whose cumulative diff touches a `skills/*/SKILL.md`, When execute reaches end-of-piece, Then it runs the linter over the changed `SKILL.md` file(s) before dispatching the Final Review board, treats invariant-1–3 violations as must-fix (routed through the fix loop), surfaces invariant-4 as advisory, and no-ops when no `SKILL.md` is touched.
  Independent Test: grep the execute `SKILL.md` Final-Review section for the pre-board linter step, the must-fix routing of invariant-1–3, the advisory handling of invariant-4, and the no-SKILL.md no-op.

**AC-6 (plan P2/P3 discipline + qa-plan enforcement):** Given a plan whose phase edits a multi-step orchestration `SKILL.md` (≥3 `^#{3,4} (Step|Phase|Sub-Phase)\b` headings, per the Definition under Functional Requirements), When the plan omits the P2 step-enumeration or the P3 dispatch-site census, Then qa-plan flags it as must-fix; and the plan skill + plan template document both requirements.
  Independent Test: grep the plan skill + `templates/plan.md` for the P2 and P3 requirements; grep the qa-plan agent for the must-fix flag conditioned on a multi-step-orchestration-file edit.

**AC-7 (version + changelog sync):** Given the release, Then `plugin.json`, the `marketplace.json` spec-flow entry, and `CHANGELOG.md` all read `5.1.0`, and the `## [5.1.0]` entry names the linter + execute self-check + P2/P3 discipline.
  Independent Test: assert version equality across the two version-bearing files (== 5.1.0) and a single `## [5.1.0]` CHANGELOG entry that mentions the linter.

**AC-8 (performance bound):** Given the linter run over all `skills/*/SKILL.md`, When timed on a warm cache, Then wall-clock < 1s.
  Independent Test: `time` the linter over the repo's `skills/*/SKILL.md`; assert elapsed < 1s.

**AC-9 (real-corpus soundness — no false positives):** Given the linter run over the actual `plugins/spec-flow/skills/*/SKILL.md` corpus (which uses the codebase's real conventions: backtick-wrapped `` `reference/x.md` §Heading `` cross-refs, `**Step N:**` bold-marker step definitions, cross-skill `<skill>/SKILL.md Step N` references, and incidental single-value config mentions in prose), When the linter runs, Then every blocking finding it emits is a GENUINE incoherence (not a false positive from a real convention it should tolerate). The acceptance bar is that the linter is usable as the Phase-2 merge gate: a clean real corpus exits 0, and any non-zero exit corresponds to a real defect a maintainer would agree must be fixed.
  Independent Test: run `lint-skill-coherence plugins/spec-flow/skills/*/SKILL.md`; manually confirm the finding set (if any) contains zero false positives against the four real conventions above — the synthetic fixtures alone are insufficient; the real corpus is the soundness oracle.

## Technical Approach

The linter is a single POSIX-bash script in `plugins/spec-flow/hooks/` (the established home for bash in this plugin, per charter-tools "Bash 4+ (hooks only)" and the same tool-class as the anticipated `jq`-based version-sync CI check). The script lives in `plugins/spec-flow/hooks/` (the charter-tools bash home) but is a manually/orchestrator-invoked CLI with a non-zero-exit + itemized-text-findings contract; it is NOT a SessionStart-style harness hook, is NOT registered in `hooks.json`, and the NN-C-005 silent-no-op / JSON-on-stdout hook contract does not apply to it. It parses each target file once: it builds the set of heading anchors (`^#{2,4} ` lines, normalized), then scans prose for `Step <id>` references, `§<heading>` / `reference/*.md §...` pointers, and `<key>: <value>` config-branch mentions, reporting any reference/pointer with no matching anchor and any config key whose documented value set is not fully covered in its branch region. Invariant (4) collects candidate state/field tokens (e.g. journal keys) and flags name-level orphans as warnings only. Exit code reflects invariant 1–3 only.

Wiring: the execute skill's Final Review section gains a pre-board step that, when the piece diff touches `skills/*/SKILL.md`, runs the linter over those files and routes invariant-1–3 findings through the existing must-fix fix-code loop. The plan skill + `templates/plan.md` gain the P2/P3 requirements; the qa-plan agent gains a check that flags their absence when the plan edits a multi-step orchestration file. This piece dogfoods itself — its own edit to `execute/SKILL.md` is linted by the very linter it ships, during its own Final Review.

## Testing Strategy

Two test classes, matching the two artifact kinds:
- **Linter (behavioral, TDD-amenable):** the linter is real bash with deterministic behavior, tested via shell assertions against fixture `SKILL.md` files — a clean fixture (exit 0), a three-defect fixture (exit ≠ 0, three findings), an orphan-field fixture (warning + exit 0), and the invocation-surface forms. These are genuine red→green behavioral tests, not doc-presence greps.
- **Skill/template/agent prose (structural oracles, pi-014 convention):** the execute/plan/qa-plan/README/CHANGELOG edits are verified by structural grep oracles asserting the documented wiring is present (the self-check step, the P2/P3 requirements, the qa-plan flag, the version sync).

Rough mix: the linter phase(s) are unit-level behavioral (~70%); the wiring/prose is structural (~30%). No e2e harness — the execute integration is verified structurally (the orchestrator-invokes-linter boundary) rather than by running a full piece through execute.

## Integration Coverage

One integration boundary in scope: **execute orchestrator → linter script** (the orchestrator invokes `lint-skill-coherence` over the piece's changed `SKILL.md` files and acts on its exit code / findings). The true external being exercised is the linter as a subprocess with a real exit-code contract. Allocated to **AC-5**. The contract (input: file paths; output: itemized findings + exit code where non-zero ⇒ invariant-1–3 violation) is the seam; AC-5 verifies the wiring asserts it. The qa-plan → plan-completeness check is a within-agent review, not a cross-component wiring, so it carries no separate integration test (covered structurally by AC-6).

## Open Questions

None — all design decisions resolved during brainstorm (approach: linter-centric; invariants 1–3 blocking + 4 warning; placement: execute pre-Final-Review + standalone/CI, qa-plan for P2/P3, no new agent; linter in `hooks/`; minor bump 5.1.0).
