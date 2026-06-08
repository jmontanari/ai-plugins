# Plan Concreteness Contract

This document is the single source of truth for the plan-authoring concreteness floor, the `[SPIKE: <unknown>]` marker, and the doc-as-code branch-enumeration-AC rule. It is cited by `plugins/spec-flow/skills/plan/SKILL.md` (Phase-2 authoring rule §2f, §9d, and the Phase-4 finalize spike-scan), `plugins/spec-flow/agents/qa-plan.md` (review criteria #28, #29, #30, #31), `plugins/spec-flow/templates/plan.md` (Implement-track exemplar slots), `plugins/spec-flow/agents/tdd-red.md` (Test Data transcription), and `plugins/spec-flow/skills/execute/SKILL.md` Step 2.7 (Write-Tests transcription). Any definition, marker syntax, or rule lives here and nowhere else; the consuming files cite this document and do not restate its definitions.

## 1. Per-phase concreteness floor

A phase in a plan is concrete when it provides the **concrete triple**:

1. **Target file** — the exact path of the file being changed or created (e.g., `plugins/spec-flow/agents/qa-plan.md`)
2. **Location / anchor within it** — where inside the file the change lands (e.g., `## Review Criteria after criterion 27`, or a specific line number, function name, or section heading)
3. **Concrete content / signatures** — the actual text, function signature, rule text, or structured block that will be written

The primary test is **presence of all three elements**. If all three are named, the concreteness floor passes for that phase, regardless of prose style.

**Vague action verbs as illustrative signal:** Verbs such as "implement", "handle", "add support for", "wire up", and "support" are an illustrative signal of a potential concreteness defect, but only when they appear in deliverable/TARGET prose — descriptions of what will be changed or created. They are **not a standalone match** that triggers a defect. Context governs.

**Legitimate non-violations** that contain these words but are not deliverable descriptions:

- "the `[Implement]` block" — refers to a plan-track label, not a vague deliverable
- "implementer agent" — refers to the executing subagent, not a deliverable description

<!-- Worked example:

PASS — Change Specification Block (all three elements present):
  Target file: plugins/spec-flow/agents/qa-plan.md
  Anchor: ## Review Criteria after criterion 27
  Content: append criterion 28 with exact text "Per-phase concreteness floor (FR-002a): each phase
    must name target file, location/anchor, and concrete content. Flag: MUST-FIX. Evidence: cite
    the phase that lacks a named anchor or content. Must-fix shape: add a Change Specification
    Block naming the file, anchor, and content."
→ All three elements present. Concreteness floor: PASS.

FAIL — Change Specification Block (no anchor, no content):
  "implement the new validator in qa-plan.md"
→ Names the target file but omits location/anchor and omits concrete content/signatures.
   Concreteness floor: FAIL. Must add anchor and exact content before advancing.

-->

## 2. The [SPIKE: <unknown>] marker

**Syntax:** A spike marker is written as:

```
[SPIKE: <description of the unknown>]
```

The brackets are literal. `SPIKE` is uppercase. The colon is followed by a free-text description of what is unknown or requires investigation before the phase can be fully specified.

**Closest existing analog:** `[PENDING-DECISION: <area>]`, which the plan skill already recognizes. The `[SPIKE: <unknown>]` marker parallels this pattern but signals a technical or empirical unknown rather than a deferred product decision.

**Distinct from `[RESEARCH-*]` markers:** `[RESEARCH-*]` markers (added by the `research-unify` skill) represent completed research artifacts. `[SPIKE: <unknown>]` represents an unresolved unknown that still requires investigation. They are not interchangeable.

**Accept-vs-reject semantics:**

- A correctly-marked `[SPIKE: <description>]` is **acceptable** — the plan author has identified and surfaced the unknown. Do NOT treat a properly-formed spike marker as a defect.
- A hedged or deferred unknown expressed in ordinary prose **without** a `[SPIKE:]` marker (e.g., "we may need to investigate…", "this depends on…", "TBD") **is** a must-fix: the author must either resolve the unknown or promote it to a `[SPIKE:]` marker.

**Scan scoping:** When scanning for `[SPIKE:]` markers, skip lines inside fenced code blocks (between opening ``` and closing ``` fences) and skip lines inside HTML comments (between `<!--` and `-->`). For multi-line HTML comments (where `<!--` and `-->` appear on different lines), skip every line between and including the opening `<!--` line and the closing `-->` line. HTML-comment exclusion takes precedence: a triple-backtick encountered while inside an HTML comment does not open a fenced code block. Only raw marker text in prose counts as a surviving marker.

**Reuse by `test-data-up` (FR-003):** The same `[SPIKE: <unknown>]` syntax can be used for unpredictable TDD test outcomes — cases where the expected test output or fixture value cannot be determined without running the code. The marker syntax and scan-scoping rules are identical.

<!-- Worked example:

Case 1 — Marker in plain prose:
  The phase must not exceed [SPIKE: real throughput ceiling] under sustained load.
→ This is raw prose. The marker survives the scan. It counts as a surviving [SPIKE:] marker.

Case 2 — Same marker inside a fenced code block:
  ```
  The phase must not exceed [SPIKE: real throughput ceiling] under sustained load.
  ```
→ The line is inside ``` fences. The scan skips it. The marker does NOT count.

Case 3 — Same marker inside an HTML comment:
  <!-- The phase must not exceed [SPIKE: real throughput ceiling] under sustained load. -->
→ The line is inside an HTML comment. The scan skips it. The marker does NOT count.

-->

## 3. Doc-as-code branch-enumeration-AC rule

**What counts as a conditional branch:** A conditional branch is any clause or case introduced by:

- "if" / "when" / "unless" / "otherwise" in the deliverable description
- an enumerated alternative (e.g., "either … or …", "case A … case B …")

Each distinct branch represents a distinct behavioral path that must be independently verified.

**The rule:** For **Implement-track / Non-TDD phases** (doc-as-code), every conditional branch in the deliverable description must have a matching numbered AC. A branch with no covering AC is a concreteness defect.

**Codified motivation — pi-011 Edge-A–Edge-F cascade:** This rule was established from the pi-011 finding, where an Implement-track phase described six distinct edge cases (Edge-A through Edge-F) but only one AC covered all of them collectively. The cascade of missed ACs made the oracle of done unverifiable. The branch-enumeration-AC rule directly prevents this pattern.

**Scope:** This rule applies **only to Implement-track / Non-TDD phases** (doc-as-code phases). It does **not** apply to TDD-track phases, which use Red/Build/Verify/Refactor cycles and test coverage as the oracle of done.

<!-- Worked example:

Deliverable description: "If merge strategy is `pr`, create a pull request against the base branch.
Otherwise (squash_local), apply the squash commit directly to the local branch without a PR."

Correct AC enumeration:
  AC-X: When merge_strategy is `pr`, the skill creates a pull request targeting the configured
    base branch and outputs the PR URL.
  AC-Y: When merge_strategy is `squash_local`, the skill applies the squash commit directly to
    the local branch with no PR created and no remote push performed.

→ Two branches, two ACs. Branch-enumeration-AC rule: PASS.
   A single AC reading "the merge strategy is handled correctly" would be a FAIL.

-->

## 4. Plan-finalize spike-gate (FR-005: routed-resolution)

**Shipped (FR-005):** The plan-skill Phase 4 finalize step now enforces a routed-resolution gate rather than a hard block. The same scan scoping as §2 applies — skip lines inside fenced code blocks (between opening ``` and closing ``` fences) and skip lines inside HTML comments (between `<!--` and `-->`); for multi-line HTML comments skip every line between and including the opening and closing lines; HTML-comment exclusion takes precedence over fence-state entry; only raw marker text in prose counts as a surviving marker.

For each surviving marked `[SPIKE:]` marker, finalize annotates it as "routed-resolution: resolved at execute by `spike-agent` (FR-005)" and **advances** — finalize does not refuse. The operative model is **annotate-and-advance at finalize → resolve at execute**: the `[SPIKE:]` phase must reach execute for the spike agent to fire, investigate the unknown, and record the resolution artifact (and, when the unknown is a test oracle, emit the concrete `Test Data` block back into the plan). The spike agent may also emit a Step 6c plan amendment when the resolution requires additional phases.

**Silent no-op path:** If no `[SPIKE:]` markers survive in prose after the scan, the finalize spike-scan is a silent no-op and Phase 4 continues without interruption.

**Unmarked unknowns:** qa-plan #29 (concreteness) catches unmarked unknowns before finalize runs — the finalize scan governs only *marked* `[SPIKE:]` spikes.

## 5. Test Data contract

A phase **requires a `Test Data` block** when it contains a `[TDD-Red]` step (TDD track) or a `[Write-Tests]` step (Non-TDD mode) — i.e. any phase that authors tests. A pure `[Implement]` phase (no test step) requires none.

The block is authored by the plan author (Opus) and transcribed verbatim by the executor; it is never designed or invented at execute time.

### Block schema

The `Test Data` block appears as a `**Test Data:**` block nested under the `[TDD-Red]` or `[Write-Tests]` step, with one entry per behavior-under-test:

```
**Test Data:**
- <case-id>: input <concrete input> → expect <concrete expected output/oracle>
```

Test entries within the `[TDD-Red]` or `[Write-Tests]` step reference cases by ID (e.g., `test_foo → case-id`) so the oracle is authored exactly once and referenced from each test entry.

All test inputs and expected outcomes must use synthetic/placeholder values — never real credentials, tokens, API keys, or production user IDs.

### Completeness rule

A `Test Data` block is **complete** iff:

(a) every behavior the test step names maps to a covering case in the block, and
(b) every case has both a concrete input AND a concrete expected outcome (or a per-case `[SPIKE:]` — see below).

`plugins/spec-flow/agents/qa-plan.md` criterion #31 checks presence and completeness from the plan text alone. It does **not** check whether the expected value is correct — that is the Opus plan author's judgment.

### Unpredictable outcomes — per-case [SPIKE]

A case whose expected outcome cannot be predicted at plan time carries `[SPIKE: <unknown>]` in its expected-outcome position. Predictable cases in the same phase keep concrete data; only the genuinely unpredictable case is spiked.

The syntax and scan-scoping rules are defined in **§2 — not restated here**. No new marker token is introduced; this is the same `[SPIKE: <unknown>]` defined in §2. A surviving per-case `[SPIKE:]` is caught by the existing §4 finalize spike-scan.

### Transcribe-only execution + backward-compat

`plugins/spec-flow/agents/tdd-red.md` (for `[TDD-Red]`) and `plugins/spec-flow/skills/execute/SKILL.md` Step 2.7 (for `[Write-Tests]`) author tests **from** the `Test Data` block and invent no input or outcome not present in the plan.

Two distinct conditions apply:

- **Block present but incomplete** — the agent emits `BLOCKED` naming the missing or incomplete case, writes no partial test set, and routes to plan amendment (Step 6c).
- **Block absent** (a plan predating this contract) — the agent emits `[TEST-DATA-ABSENT: <reason>]` and falls back to today's design-from-assertions behavior without blocking.

The distinguishing rule: **absence → legacy fallback; presence-but-incomplete → BLOCKED. Never conflate them.**

`plugins/spec-flow/agents/qa-plan.md` criterion #31 gates new plans on block presence, so a missing block at execute time means the plan predates this contract (legacy).

<!-- Worked example:

**Test Data:**
- tok-expired: input "expired_token" → expect TokenExpiredError
- tok-valid: input "valid_token_abc123" → expect {"user_id": 42, "role": "admin"}
- tok-malformed: input "not_a_jwt" → expect [SPIKE: exact error type needs integration test to determine]

test_expired_token → tok-expired
test_valid_token → tok-valid
test_malformed_token → tok-malformed

Complete (tok-expired, tok-valid): both have concrete input and expected output.
Pending-resolution (blocks finalize-scan): tok-malformed has a concrete input but [SPIKE:] in the expected-outcome position — survives the §4 finalize spike-scan until resolved.

-->


