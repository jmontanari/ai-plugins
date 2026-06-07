# Plan Concreteness Contract

This document is the single source of truth for the plan-authoring concreteness floor, the `[SPIKE: <unknown>]` marker, and the doc-as-code branch-enumeration-AC rule. It is cited by `plugins/spec-flow/skills/plan/SKILL.md` (Phase-2 authoring rule §2f, §9d, and the Phase-4 finalize spike-scan), `plugins/spec-flow/agents/qa-plan.md` (review criteria #28, #29, #30), and `plugins/spec-flow/templates/plan.md` (Implement-track exemplar slots). Any definition, marker syntax, or rule lives here and nowhere else; the three consuming files cite this document and do not restate its definitions.

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

## 4. Interim plan-finalize spike-block + FR-005 handoff

**Interim behavior:** The plan-skill Phase 4 finalize step currently enforces a hard gate: it refuses to advance while any `[SPIKE: <unknown>]` survives in prose. The same scan scoping as §2 applies — skip lines inside fenced code blocks (between opening ``` and closing ``` fences) and skip lines inside HTML comments (between `<!--` and `-->`); for multi-line HTML comments skip every line between and including the opening and closing lines; HTML-comment exclusion takes precedence over fence-state entry; only raw marker text in prose counts as a surviving marker.

When one or more `[SPIKE:]` markers survive, the finalize step reports:

```
Plan finalize refused — N surviving [SPIKE:] marker(s) must be resolved before the plan is approved:
  1. [SPIKE: <description>] — found in Phase <N>: <surrounding sentence>
  ...
Resolve each marker by either: (a) replacing it with concrete content if the unknown is now
resolved, or (b) awaiting FR-005 spike-agent resolution, which will issue a plan amendment.
```

This block is **interim**: it applies until FR-005 (`spike-agent`) ships and the harness gains automated spike-resolution capability.

**FR-005 / spike-agent forward reference:** FR-005 (`spike-agent`) adds an Opus spike resolver that clears a `[SPIKE]` via a Step 6c **plan amendment** — an in-place targeted amendment to the relevant phase that replaces the spike marker with concrete, verified content. After the plan amendment is applied, the finalize gate is relaxed to a routed-resolution annotation rather than a hard refusal. Until FR-005 ships, the operator must resolve each `[SPIKE:]` marker manually by editing the plan and re-running finalize.

**Silent no-op path:** If no `[SPIKE:]` markers survive in prose after the scan, the finalize spike-scan is a silent no-op and Phase 4 continues without interruption.
