# spec-flow throughput — v2 proposals backed by observed session data

> **Reader note (2026-04-19):** this document was written against the v1.2 doctrine. The shipped v1.3.0 state is summarized in *Rollout order (revised — shipped as v1.3.0-lean)* near the end. Earlier sections discussing `--no-verify` intermediates and Step 6b consolidation loops describe v1.2 behavior; v1.3.0-lean reverted P7 and removed those mechanisms.

**Author:** spec-flow user (`prop_trader` / phase-0b-historical-adapters, session 2026-04-18)
**Data window:** ~14-hour continuous orchestration session covering Phases 5a → 10 (in flight)
**Prior docs:**
- `proposals/build-orchestration-efficiency.md` (shipped as v1.1.1)
- `proposals/execution-throughput.md` (partial v1.2.0: P3 conditional Verify, P6 race-safe add, P7 single-commit mode with `--no-verify` intermediates)

**Target:** close the gap between v1.2.0 observed behavior (≥77 min/phase) and the
user's mental budget (~30 min/phase). The limiting factor is no longer prompts
or orchestration — it is **pre-commit hook round-trips and unnecessary
orchestration steps**.

## Session evidence

Commit counts from `git log --since="14h"`:

- 36 commits in 14 hours.
- 6 progress commits (end-of-phase markers).
- **30 non-progress commits**, of which ~15 are labelled `(intermediate)` —
  these are the artifacts of v1.2.0's "intermediate commits use `--no-verify`
  then consolidation runs hooks once." In practice each intermediate still
  runs hooks on NEXT consolidation, so "once" becomes 2–6 times per phase.

Per-phase commit + hook counts (conservative):

| Phase | Commits | Consolidation rounds | Hook runs |
|-------|---------|---------------------|-----------|
| 5a | 6 | 1 | 5 |
| 6 | 7 | 1 | 7 |
| 7 | 7 | **6** | 8 |
| 8 | 5 | **3** | 7 |
| 9 | 8 | **4** | 9 |
| 11 | 7 | **2** | 8 |
| 10 (partial) | 3 so far | TBD | TBD |

Each hook run = 90–160 seconds of `pytest-quick` (full 1250-test suite). The
worst phase (Phase 7) burned ~15 minutes on pre-commit hook time alone across
its 8 runs. Across the session, pre-commit overhead is **~90–120 minutes**, or
one-sixth of elapsed wall time.

Per-phase wall-time (from git commit timestamps — **Red commit → progress commit**):

| Phase | Red | Progress | **Wall time** | Notes |
|-------|-----|----------|--------------|-------|
| 6 | — | 14:22 | ~77 min | Pre-v1.2, clean |
| 7 | 15:21 | 21:09 | **5h 48m** | BLOCKED scope amendment + 6 consolidation rounds |
| 8 | 14:36 | 19:23 | **4h 47m** | Concurrent-agent race; Phase 8 Build commingled into Phase 7 Red |
| 11 | 21:21 | 01:35 | **4h 15m** | v1.2.0 lessons applied — still this slow |
| 9 | 01:48 | 04:52 | **3h 04m** | 4 consolidation rounds; Build needed 3 internal iterations |
| 10 | 05:05 | (3h+ and counting) | 3h+ min | Build needed 6 internal iterations; Verify fired 4 must-fix |

**Median phase wall time: ~4 hours. Target was ≤46 min.** That's ~5×
over target, not the 2.6× the first version of this doc claimed. **v1.2.0
improvements were invisible at this scale** — the wall-time regressed versus
Phases 5a/6 (pre-v1.2) despite Red now skipping hooks and intermediates
being `--no-verify`.

Two hypotheses for why v1.2.0 didn't help as much as projected:

1. The dominant cost is NOT hook round-trips (v1.2.0's target) but
   **Opus agent inference time** (QA, Verify) plus **Sonnet Build internal
   iteration count**. Those are unchanged.
2. `--no-verify` intermediates shift hook work to consolidation, but
   consolidation itself becomes a mini-loop (2–6 rounds in observed
   phases) — net-zero savings when Red-phase lint debt accumulates.

## What v1.2.0 fixed vs. what it didn't

| Proposal | Status in v1.2.0 | Observed impact |
|----------|-----------------|-----------------|
| P6 race-safe `git add` | Shipped | Zero contamination incidents Phase 9 onward ✓ |
| P3 conditional Verify (Audit/Full) | Shipped (both modes) | Every phase still used Full mode — Builds never emitted a clean AC coverage matrix |
| P7 single-commit-per-phase via `--no-verify` intermediates | Partially shipped | Intermediates DO skip hooks, but consolidation still runs ALL hooks multiple times when ruff-format / mypy flags lint debt |
| P1 per-phase pytest-quick scope | Not shipped | **Biggest remaining win** |
| P2 Scaffold phase | Not shipped | N/A this session (no composite spec with [Scaffold] block) |
| P4 parallel fix-code | Not shipped | Would save 10–15 min/phase when QA returns disjoint fixes |
| P5 parallel QA iter 1 | Not shipped | Would save 15 min when two [P] phases collide |

## Observed new bottlenecks (not in v1 proposals)

### New-1 — `pytest-quick` runs full suite ignorantly

Every non-Red commit's pre-commit hook runs the ENTIRE unit suite (1250 tests,
~100s). When a commit touches ONE adapter file, only ~20 tests actually apply.
P1 is the stated remedy and is still unshipped. On this session 30 hook runs
× ~100s = **50 minutes** of avoidable test time.

### New-2 — "ruff autofix wiggle" during consolidation

Ruff's `--check` fails when formatting differs; its own hook runs the fix,
but the fix itself counts as "file modified by hook" → pre-commit exits 1,
forcing an orchestrator re-run. If the fix produces new rule violations
(UP035/UP037/TCH003/DTZ001 from quoted annotations / naive datetimes),
another round. Phase 7 consumed 6 consolidation rounds from this alone.

Observed root cause: Red-phase tests are committed with `--no-verify` (by
design), so `ruff --check` never sees them until consolidation. By that point
the cumulative lint debt surfaces. Phase 9's consolidation cycle went
4 rounds for exactly this reason.

### New-3 — Build agent internal iterations

Phase 9 Build: 3 internal iterations. Phase 10 Build: **6 internal iterations**.
Each iteration is an agent self-correction attempt, observable in the
task-notification's `duration_ms` (49 min and 58 min respectively). The
Build's prompt template doesn't surface common mock/fixture pitfalls
(descriptor binding, wrong `parents[N]` index, fixture-path drift after
rename) so the agent learns them the hard way each phase.

### New-4 — `--no-verify` intermediate proliferation

v1.2.0 tells the orchestrator to commit fix-code diffs with `--no-verify`
and run pre-commit once at consolidation. In practice, consolidation has
been breaking into 2–6 rounds because each hook failure → fix-code commit →
re-run. The "one hook run per phase" promise becomes 2–6 runs, with every
extra run paying full pytest-quick cost.

### New-5 — Verify + Refactor + QA iter 2 are often low-yield

Across Phases 5a–11, observed yield:

- Verify: found must-fix in Phases 7, 9, 10, 11. Found no-op in Phases 5a, 6, 8.
  **Hit rate: 4/7 (57%).**
- Refactor: averaged −3 to −48 LOC; all comment cleanups or small dedup.
  **No QA-iter-1 finding was ever attributed to a Refactor defect.**
- QA iter 2: found 0 new must-fix in 5 of 6 runs. Phase 11 iter 2 found 1
  (stale fixture references) that iter-1 had missed. **Hit rate: 1/6 (17%).**

Combined Verify + Refactor + QA iter 2 wall-time: **30–50 minutes per phase.**
Conditional skipping would reclaim most of that on clean phases.

## Proposals (stacked on v1.2.0)

Ranked by observed minutes-saved-per-phase.

### Q1 — Ship P1 (pytest-quick change-scoped selection)

**Deferred from the earlier throughput proposal. Highest single win.**

Pre-commit's `pytest-quick` hook should accept a `--files` arg from pre-commit
and run only the tests that collect against the changed module paths (or
import the changed module transitively). Fall back to the full suite when the
diff touches `conftest.py`, hooks, or `pyproject.toml`.

**Observed saving on this session:** 30 hook runs × (100s → ~10s) = **~45 min
saved per pass, ~15-20 min saved per typical phase.**

**Implementation:** project-level pre-commit config change, not a spec-flow
skill change. The spec-flow docs should recommend it and provide a reference
`pytest-quick` hook configuration using `pytest-testmon` or an AST-based
change-scope resolver.

### Q2 — Orchestrator: skip Refactor when Build is clean

On any phase where Build's report includes "Oracle ran clean on first
attempt: YES" and "Deviations from plan: none", skip the Refactor agent
entirely. Verify agent can still run. Progress directly from Verify → QA.

**Rationale:** observed 6 consecutive Refactor passes produced only comment
cleanups + minor dedup. None fixed a correctness defect. The cost of running
a Sonnet Refactor agent + its own hook pass is ~15 min. Skipping on clean
Builds reclaims that on most phases.

**Mechanism:** add `refactor: auto|always|never` to `.spec-flow.yaml`. In
`auto` mode, skip when the Build report's structured fields match the clean
predicate. Operator can flip to `always` to retain current behavior.

**Expected saving:** 10–15 min per clean-Build phase. Applies to ~5/7 phases
observed.

### Q3 — Collapse QA iter 2 when fix-diff is small and self-verified

When the fix-code agent's own oracle passes AND the `## Diff of changes`
section is <50 LOC, skip the QA iter 2 dispatch. Treat the fix-code agent's
self-verification as the gate.

**Observed hit rate for QA iter 2 finding new issues: 1/6 runs (~17%).** The
one hit (Phase 11 stale fixture references) was a cross-file semantic check
that no small-diff heuristic would catch — that specific class of finding
survives into Phase 14's exit-gate tests where it would be re-surfaced.

**Mechanism:** orchestrator inspects fix-code output. If diff line count <
threshold AND fix-code reported all findings resolved AND full-suite oracle
green, skip iter 2. Flag as `qa_iter2_skipped` in session summary.

**Expected saving:** 5–8 min × 5/6 phases.

### Q4 — Pre-compute lint cleanliness before the first consolidation

Phase 7 consumed 6 consolidation rounds where each round was just ruff/mypy
flagging previously-unseen lint debt in Red-phase tests. Root cause: Red-phase
tests commit with `--no-verify` so lint is never checked until consolidation.

**Fix:** the Red-phase agent template runs `ruff check --fix` + `ruff format`
+ `mypy --strict` on its authored test files before committing. Red's commit
still uses `--no-verify` for the pytest failure (failing tests are expected),
but lint-clean when committed.

**Observed:** the 30 hook runs in this session included ~10 rounds that were
purely lint-ping-pong. Saving 10 × 100s = **17 min session-wide**.

**Mechanism:** update `agents/tdd-red.md` template with a required pre-commit
checklist: (1) `ruff check --fix`, (2) `ruff format`, (3) `mypy --strict` on
your authored files. Only then `git commit --no-verify`.

### Q5 — Surface Build self-correction patterns in the prompt

Build's internal iteration count should be zero for routine phases. Observed
top causes of re-attempts:

1. **Descriptor binding in `patch.object`** — `_fake_fetch(symbol, ...)` needs
   `self` first arg when bound to a class. Seen in Phase 9 and 10.
2. **Wrong `parents[N]` in fixture paths** — rarely matches; 3 occurrences
   this session (Phase 6, 10, 11). Should be a project-level fixture-path
   helper.
3. **Level-based vs. return-based reconcile formula** — agent picks whichever
   makes the test green, not necessarily the spec-correct one. Phase 10.
4. **Mock signatures that don't match sub-client contract** after resume_from
   added. Phase 9.

**Fix:** add a "Known pitfalls" section to the implementer agent template
enumerating these. Observed saving: each pitfall avoided = 1 Build iteration
= 5–15 min.

### Q6 — Ship P5 (parallel QA iter 1 across [P] phases)

When the orchestrator has two `[P]`-marked phases whose Refactor commits
within the same minute, their QA iter 1 agents can fire concurrently (both
Opus, both read-only, disjoint diffs). This session never exercised this
because phases went serial after Phase 7/8 concurrency caused a race. Post-P6
(shipped), concurrency is safe.

**Expected saving:** 15 min per concurrent-phase pair. Applies once in this
session (Phases 7+8).

### Q7 — Explicit escape hatch: consolidation fix-code

v1.2.0 Step 6b can dispatch a fix-code agent when hooks fail. This session
showed that most consolidation-round failures are `ruff --fix`-able or
one-line mypy annotation additions. Dispatching a full Sonnet fix-code agent
for each round is overkill.

**Fix:** orchestrator detects `ruff --fix (N errors fixable)` in pre-commit
output and applies it inline (no agent dispatch), same for mypy's
suggested-ignore patterns. Reserve fix-code for actual logic or type
incompatibilities.

**Expected saving:** 3–5 min per consolidation round where only ruff-fix
applies.

### Q9 — Scope the Opus QA prompt to changed-file surface + integration callers

Per-phase Opus QA averaged ~21 min/dispatch (16 dispatches, 339 min total).
The current orchestrator composition (`execute/SKILL.md` Step 6) hands Opus
the full phase diff, the full spec, the plan section, the full PRD-mapped
sections, and non-negotiables — then `agents/qa-phase.md` instructs "walk
every branching path." The agent responds by tool-calling 30–60 file reads
per dispatch to rebuild context it could have been handed pre-digested.

Iter-2 average duration is also ~21 min — meaning the "Focused re-review"
contract isn't actually narrowing inference. Either Opus ignores the
focus instruction or the orchestrator is re-attaching too much.

**Five concrete changes** (no skill restructuring; prompt-composition only):

1. **Structured surface map instead of raw diff.** Orchestrator pre-computes
   and attaches:
   - `## Files changed` — `path | +adds/-dels | role` (test/impl/config)
   - `## Public symbols added or modified` — `git grep`-derived list
   - `## Integration callers` — for each public symbol, paths of files that
     import it (paths only, not bodies — Opus can `Read` if it needs them)
   - `## Diff` — changed-line hunks only, not full file bodies; if total
     diff > 500 LOC, collapse per-file with a "request via Read if needed"
     hint.

2. **Drop PRD sections from per-phase QA.** PRD alignment is the Final
   Review board's job (`agents/review-board/prd-alignment.md`). Per-phase
   QA's mandate is correctness against *this phase's plan*, not PRD
   compliance. Saves 5–15K tokens and removes a distraction axis.

3. **Pre-extract AC subset for the phase** instead of full spec. The
   orchestrator already knows which ACs map to the phase from plan.md —
   attach only those rather than the entire spec.

4. **Hard-cap iter-2 context.** Update `qa-phase.md` Focused re-review
   rules: "You receive ONLY the fix-diff and prior must-fix list. Reading
   any other file is a contract violation. If you need broader context,
   return `BLOCKED — needs full re-review` rather than reading."

5. **"Trust the AC matrix as a starting point" line.** Tell Opus that
   Build's `## AC Coverage Matrix` is attached for it to *adversarially
   verify gaps*, not re-derive. This eliminates the "re-walk every AC"
   tool-call loop on phases with a clean matrix.

**Expected saving:** 8–12 min per QA dispatch × 16 dispatches/session =
**~150 min session-wide.** Combines with Q8 (fold Verify into QA) — if
both ship, single Opus dispatch runs ~10–15 min instead of 21–30.

**Mechanism:** edits to `agents/qa-phase.md` (rules 4 + 5) and to
`execute/SKILL.md` Step 6 prompt composition (rules 1–3).

### Q10 — Mandatory AC Coverage Matrix in Build output

Q9 #5 and Q8 (folding Verify into QA) both depend on the Build agent
emitting a clean, structured `## AC Coverage Matrix`. In this session,
**every phase fell back to Verify Full mode** because Builds either
omitted the matrix or emitted unresolved `NOT COVERED` rows. As a result,
the conditional Audit-mode optimization shipped in v1.2.0 produced zero
observed savings.

Without Q10, both Q8 and Q9 #5 degrade to "QA re-walks every AC via
tool calls" — the cost stays at 21+ min per dispatch.

**Fix:** make the AC matrix a hard contract in `agents/implementer.md`:

1. Add a mandatory output section to the agent template:
   ```markdown
   ## AC Coverage Matrix (required — phase cannot pass without this)
   | AC ID | Test file:line | Status |
   |-------|----------------|--------|
   | AC-1  | tests/path:42  | covered |
   | AC-2  | —              | NOT COVERED (reason: deferred to Phase N+1) |
   ```
   Every in-scope AC for the phase MUST appear. `NOT COVERED` rows
   require an explicit reason and reference to where the AC will be
   covered (later phase, deferred to spec amendment, etc.).

2. Add an orchestrator validation step in `execute/SKILL.md` Step 3
   (after Implement returns):
   - Parse the Build report for `## AC Coverage Matrix`.
   - If the section is missing → reject and re-dispatch with explicit
     "matrix required" feedback.
   - If unresolved `NOT COVERED` rows exist without justification →
     reject and re-dispatch.
   - Only on a clean matrix does the orchestrator advance to Verify
     (or merged QA under Q8).

**Expected saving:**
- Without Q10: Verify always runs Full mode (15–30 min) and Q9 #5
  is dead text → ~0 min/phase saved
- With Q10: Verify can run Audit mode (3 min) on clean phases AND
  Q9 #5's "trust the matrix" line activates → 12–25 min/phase
  saved on top of Q9, applied to ~5–6 of 7 phases.

**Combines with:**
- Q8 — without a clean matrix, the merged QA dispatch still
  re-derives. Q10 is a precondition for Q8's full benefit.
- Q9 #5 — directly enables it.
- The v1.2.0 Audit mode shipped in Step 4 — finally makes it
  reachable.

**Mechanism:** edits to `agents/implementer.md` (output schema) and
`execute/SKILL.md` Step 3 (validation gate before Verify dispatch).

## Rollout order (revised — shipped as v1.3.0-lean)

v1.3.0 shipped with a structural simplification: the project-side pre-commit config moved test runs out of `pre-commit` (to `pre-push` / orchestrator-only gates), making per-commit hooks cheap. That eliminated the v1.2 P7 cadence (`--no-verify` intermediates + consolidation loop) and removed the pathologies Q4/Q7 were patching.

| Q | Status | Notes |
|---|--------|-------|
| Q1 | project-level, not shipped in plugin | prop-firm's `.pre-commit-config.yaml` removed tests from pre-commit |
| Q10 | **shipped in 1.3.0** | AC matrix schema + Step 3 validation gate |
| Q9 | **shipped in 1.3.0** | QA prompt scoping — surface map, no PRD, phase ACs only |
| Q4 | **dropped under v1.3-lean** | Obviated by per-commit hooks catching lint at commit time |
| Q2 | **shipped in 1.3.0** | `refactor: auto\|always\|never` config, auto skips when Build clean |
| Q3 | **shipped in 1.3.0** | `qa_iter2: auto\|always` config, skip re-dispatch on small self-verified fix-diffs |
| Q7 | **dropped under v1.3-lean** | Obviated by per-commit hooks — no consolidation loop to optimize |
| Q5 | **deferred to v1.3.1+** | Pipelining underwired; observed benefit ~15 min/session doesn't justify orchestrator restructure |
| Q6 | **shipped in 1.3.0** | Build pitfalls section in `agents/implementer.md` |
| Q8 | **held** | Fold Verify into QA. Revisit if median phase wall-time remains > 2 hours after v1.3.0 ships |

### v1.3-lean structural changes (not in original Q list)

1. **Revert P7 (`--no-verify` intermediates + Step 6b consolidation loop).** Replaced with per-commit hooks running normally; Step 6b is now a defensive sanity sweep (single run, single fix-code dispatch if needed) rather than a multi-round state machine.
2. **Update `agents/implementer.md` and `agents/tdd-red.md`** — commits use `git commit` (hooks run); `--no-verify` is a scoped escape hatch only when the pre-flight hook inventory flagged a test-running hook for Red.
3. **Update README** — pre-commit should contain lint/format/type-check only; tests live at `pre-push` or orchestrator gates.

### Files changed (v1.3.0)

- `agents/implementer.md` — AC matrix schema + Q6 pitfalls + reverted `--no-verify` rule
- `agents/qa-phase.md` — Q9 surface-map context + iter-2 hard cap + trust-matrix guidance
- `agents/tdd-red.md` — reverted `--no-verify` rule (scoped escape hatch for test-hook projects only)
- `skills/execute/SKILL.md` — Q10 Step 3 gate + Q9 Step 6 composition + Q2 Step 5 skip + Q3 Step 6 skip + rewritten Step 6b
- `README.md` — pre-commit config guidance + `refactor`/`qa_iter2` config key docs
- `templates/pipeline-config.yaml` — `refactor` and `qa_iter2` keys
- `.claude-plugin/plugin.json` — version 1.3.0

## Projected wall time after Q1–Q7 (revised — pessimistic, based on real data)

The Q1–Q7 projections in this doc's first draft estimated 50–70 min per phase.
That was calibrated against my **understated** 2-hour median. Recalibrating
against the real 4-hour median:

Per-phase estimate (refactor-light, no unusual deviations):

- Red (Sonnet): **15–25 min** (was 8–12 — I underestimated agent inference time)
- Build (Sonnet): **40–75 min** on average; can balloon to 2 hours when Build
  self-iterates (Phase 10: 52 min was a good case; Phase 7 Build was nearly
  2 hours). Q6 pitfall-surfacing cuts iterations from 3-6 → 1-2.
- Verify (Sonnet or Opus): **15–30 min** when Full mode (always so far because
  Build never emits a clean AC matrix). Q2 skips Refactor but not Verify.
- (Refactor: skipped on clean Builds — Q2 saves 15–20 min)
- QA iter 1 (Opus): **15–30 min** (was 5–10 — Opus inference is slower than
  I claimed)
- Fix-code: **15–25 min** when must-fix
- (QA iter 2: skipped on small diffs — Q3 saves 10–15 min)
- Consolidation: **5–15 min** after Q4+Q7 (down from 20–30 min × 2–6 rounds)
- Progress commit: 3–5 min (pre-commit hook)
- **Plus** monitor/wait/re-arm slack: 20–30 min per phase that I don't
  allocate anywhere

**Revised median phase wall time target: 2–2.5 hours** (down from 4). Still
2× the user's ~30-min mental budget, but honestly achievable with Q1–Q7.

**If the budget target is genuinely 30 min/phase**, the hard truths are:
- **Opus QA is too slow for the yield.** Switching QA iter 1 to Sonnet would
  cost some must-fix recall but ~halve inference time. Phase 6 Sonnet-QA
  experiment would validate.
- **Build self-iteration is the biggest single cost.** A 6-iteration Build
  is 6 inference cycles. Q6 alone could save 30+ min on complex phases.
- **The Verify agent is a 15–30 min duplicate of what QA iter 1 checks.**
  Collapse them: if Verify Audit mode becomes reliable, it can be a 3-min
  AC-matrix check followed by a 15-min Opus QA. Total 18 min instead of 45.

A more aggressive revision (Q8): **fold Verify into QA iter 1**. Single
Opus dispatch that both (a) checks the AC coverage matrix from Build's
report and (b) does adversarial review. Save 15 min per phase unconditionally.

## Success metric for next large run (revised)

Measure on the next 3-phase run (Phases 12 / 13 / 14 for this project):

- Median phase wall time ≤ **120 min** (50% reduction from 4-hour baseline —
  NOT the 60-min target from v1 of this doc, which was unrealistic)
- Consolidation rounds ≤ 2 per phase
- Build iterations ≤ 2 per phase
- Hooks run ≤ 3 times per phase
- **No Opus QA dispatch longer than 20 min** (indicates prompt or diff size
  is too large)

If median phase wall time doesn't drop below 2 hours, the Q-tier proposals
are insufficient — the remaining cost is inherent to the multi-agent
orchestration model and compounds through the LLM inference cost per agent.
At that point the right conversation is whether the value of Opus-grade
adversarial QA justifies its wall-time cost, versus shipping faster with
Sonnet and accepting a slightly higher post-merge defect rate.

## Appendix: concrete data from this session

### Phase 9 (equities_daily) timing
- Red: 11 min (11:50–12:01)
- Build: 49 min (3 internal iterations observed)
- Verify: 12 min (FAIL: broad except + mock defect + coverage gap)
- Verify-gate fix-code: 25 min
- Refactor: 16 min (−3 LOC comment cleanup)
- QA iter 1: 3 min (Opus, Full)
- QA iter 1 fix-code: 15 min (must-fix: write_batch keyword, base_url, dead filter)
- QA iter 2: 5 min
- Consolidation: 4 rounds × 3 min (ruff-fix ping-pong on untyped helpers)
- Progress: 3 min
- **Total: ~210 min**

### Phase 10 (intraday_bars, in flight)
- Red: 14 min
- Build: 58 min (6 internal iterations — formula/fixture/path)
- Verify: 30 min (Opus, FAIL on 4 must-fix including path bug + NN-1 violation + reconcile formula)
- Verify-gate fix-code: in flight (~25 min estimate)
- (Refactor + QA + consolidation pending)

### Commit narrative artifact

Of 30 non-progress commits, 15 carry `(intermediate)` in the subject line.
This is expected under v1.2.0's design, but it means the squash-merge to
main will be opaque to reviewers without a cleanup pass. Consider automating
a `git rebase --interactive --autosquash` or consolidated squash-merge
message step as part of the "Final Review → merge" orchestrator flow.
