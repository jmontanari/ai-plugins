---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
legacy_deferred_rows: false
tdd: false
fast: false
review_board_variant: doc-as-code  # skill/reference/template markdown IS the deliverable; swaps blind seat for a 2nd seeded edge-case reviewer
---

# Plan: outcome-acs — Outcome & negative-space acceptance criteria

**Spec:** docs/prds/exec-ready/specs/outcome-acs/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Doc-as-code piece in **Non-TDD mode** (`tdd: false`) — every deliverable is markdown / JSON / YAML; there is no runtime code and no test runner (NN-C-002). Four phases, executed in order:

1. **Single-source + data model** — CREATE `reference/behavior-classification.md` (the glossary/definition SSOT) and add the `piece_class`/`behavior_rationale` front-matter keys + AC-line tag scheme + per-facet N/A sentinel to `templates/spec.md`. Everything downstream cites the SSOT, so it lands first.
2. **Enforcement gates** — append criterion #17 to `agents/qa-spec.md` (two-facet, 3-state, liveness heuristic, exact-literal, Focused-mode wiring) and criterion #33 to `agents/qa-plan.md` (anti-mislabel cross-check); bump both `rubric_version` 1→2. The `.agent.md` twins are relative symlinks (5.16.1) and follow automatically.
3. **Elicitation wiring** — add the always-run negative-space block to `reference/brainstorm-procedure.md`; wire the spec skill's authoring + H-5 preview; extend the `user-intent` lens row; fold a negative-space CONTESTED into the convergence VOQ scheme.
4. **Version triad + integration verification** — bump `plugin.json` + `marketplace.json` + `CHANGELOG.md` 5.16.1→5.17.0, update the two `static.sh` version-literal assertions in lockstep, then run the integration sweep (static.sh, the 7-site citation grep, the version-parity diff, the metrics non-interference assertion, and the e2e gate-chain walk).

**Verification posture.** Machine ACs are grep/diff/readlink/`static.sh`. Judgment ACs (AC-9, AC-10, AC-13, AC-14) run the affected agent on a small authored fixture spec/plan and confirm the gate fires or skips — those fixtures are authored in the relevant phase's `[Write-Tests]` step.

## Architectural Decisions

### ADR-1: Edit the `.md` source only; the co-ship symlink propagates to the `.agent.md` twin
**Context:** As of 5.16.1 all 27 `agents/*.agent.md` are relative same-dir symlinks to their `.md` source (`qa-spec.agent.md -> qa-spec.md`, `qa-plan.agent.md -> qa-plan.md`; verified `[ -L ]` + `readlink`). The research-era and `deliberation.md`-line-116 model assumed a byte-identical *lockstep edit* of two real files.
**Decision:** Edit `qa-spec.md` and `qa-plan.md` only. Never write to a `.agent.md` path. The symlink makes the twin reflect the edit instantly; the 2 `.agent.md` AC-11 citation sites and all `static.sh` symlink/`diff`/`cmp -s` assertions pass for free.
**Alternatives considered:** (a) Edit both twins as real files — rejected: the `.agent.md` is no longer a regular file; writing through it would dereference-and-edit the source (harmless) or, if rewritten as a regular file, *break* the symlink and trip the 27-pair drift guard. (b) Add a build step that regenerates twins — rejected: no such step exists; pure over-engineering for a solved problem.
**Consequences:** The 7 AC-11 citation sites collapse to 5 real-file edits. Supersedes the deliberation byte-identity-lockstep concern (no lockstep edit exists anymore).
**Charter alignment:** NN-C-008 (agents self-contained — the symlinked twin is identical, so self-containment holds), CR-001 (front-matter schema unchanged by the `rubric_version` value bump).

### ADR-2: The version surface is FIVE files (two `plugin.json` descriptors), bumped together with the `static.sh` literals
**Context:** `docs/releasing.md` is the authoritative version-bearing-file list and names **two** distinct `plugin.json` descriptors: `plugins/spec-flow/plugin.json` (Copilot CLI co-ship, added v2.1.0) **and** `plugins/spec-flow/.claude-plugin/plugin.json` (Claude Code descriptor). NN-C-009 requires **all** host descriptors match. Critically, `tests/e2e/lib/static.sh` line 207 binds `pluginjson="${PLUGIN_ROOT}/plugin.json"` where `run-e2e.sh` sets `PLUGIN_ROOT=plugins/spec-flow` — so the line-209 version assertion targets the **Copilot** descriptor `plugins/spec-flow/plugin.json`, NOT `.claude-plugin/plugin.json`. The spec's "version triad" prose (spec line 40 / FR-OA-8 / AC-8) is shorthand that under-names the real set; the binding gate AC-12 ("static.sh passes") makes the full set mandatory.
**Decision:** Bump **all five** surfaces in Phase 4: `plugins/spec-flow/plugin.json` (Copilot, T-1b) + `plugins/spec-flow/.claude-plugin/plugin.json` (Claude, T-1) + `.claude-plugin/marketplace.json` (T-2) + `CHANGELOG.md` (T-3) + `static.sh` lines 209/211 literals (T-4). Line 216 (`assert_grep "\[5\.16\.1\]"` on the CHANGELOG) is left unchanged — the changelog is append-only, so the `[5.16.1]` section persists. The spec's "triad" is honored (the three named files reach 5.17.0); the Copilot descriptor bump is additive and required by AC-12 + NN-C-009, so it does not contradict AC-8 — no spec-amend is needed.
**Alternatives considered:** (a) Bump only the spec's named "triad" — rejected: static.sh line 209 asserts 5.17.0 against the un-bumped Copilot `plugins/spec-flow/plugin.json` (still 5.16.1) → static.sh fails → AC-12 fails; also violates NN-C-009 "all descriptors match." (b) Make static.sh read the version dynamically from `plugin.json` — rejected: scope creep (a separate test-hardening piece); risks masking a real desync the literal assertion is designed to catch. (c) Leave static.sh and accept the failure — rejected: directly violates AC-8 + AC-12.
**Consequences:** The version-bump phase touches a 5th file (the Copilot descriptor). Both `plugin.json` descriptors are independent Change Specs (T-1, T-1b) so execute cannot miss the easy-to-overlook Copilot one. AC-8's binding diffs all three JSON version surfaces for equality.
**Charter alignment:** NN-C-009 (version-bump-on-plugin-change — both host descriptors + the literal assertions are all part of the sync surface), NN-C-003 (MINOR bump).

### ADR-3: `reference/behavior-classification.md` is the new piece-granularity SSOT; `spec-flow-doctrine.md` L179 is untouched
**Context:** L179 of `spec-flow-doctrine.md` already splits behavior-bearing vs config/infra/glue — but at **phase granularity** for *plan-time* TDD-track selection. This piece introduces the same split at **piece granularity** for *spec-time* gating. They are distinct concerns at distinct stages.
**Decision:** Create a new reference doc that owns the piece-level definition, the two outcome facets (`result`, `integration`), and the canonical token glossary. The template, both qa twins, brainstorm-procedure, and the spec skill all cite it (CR-008 reference-indirection). FR-OA-1 explicitly forbids modifying L179; `git diff` must show it unchanged (AC-1).
**Alternatives considered:** (a) Extend L179 in place — rejected: conflates phase-level and piece-level splits and is explicitly forbidden by FR-OA-1. (b) Inline the glossary in `templates/spec.md` — rejected: duplicates the token list across 5+ consuming sites, defeating the single-source goal (the very integration-facet failure mode this piece exists to prevent).
**Consequences:** One new reference file; every consumer carries a one-line citation rather than a copy of the glossary.
**Charter alignment:** CR-008 (thin-orchestrator / narrow-executor — logic centralized in the reference doc), CR-005 (repo-root-relative citation paths).

### ADR-4: Outcome/mechanism tag rides the `AC-N:` line; verifiability tag stays on the Independent-Test sub-line (two orthogonal axes)
**Context:** The existing `[machine:]`/`[judgment:]` tag lives on the indented `Independent Test` sub-line and is counted by the Phase-5 `ac_verifiability` metric (SKILL.md line 328). A naive design would overload that same sub-line with the outcome/mechanism distinction and perturb the metric (AC-15 forbids this).
**Decision:** The new `[mechanism]`/`[outcome:result]`/`[outcome:integration]` tag is an inline bracket on the `AC-N:` line itself — a second axis orthogonal to the sub-line verifiability tag. The metric grep stays scoped to the Independent-Test sub-line and cannot match an AC-line tag, so the `machine`/`judgment` counts are provably unchanged (AC-15). No new `###` heading is added under `## Acceptance Criteria` (CR-009 extraction-anchor safety, AC-2).
**Alternatives considered:** (a) Separate `### Outcome Acceptance Criteria` subsection — rejected: doubles the heading surface (CR-009 risk) and splits AC numbering. (b) Overload the Independent-Test sub-line — rejected: breaks AC-15 metric non-interference.
**Consequences:** One AC line can carry two brackets (e.g. `AC-9: … [outcome:result]` on the AC line, `[judgment: …]` on its sub-line). The metric seam stays plumbed untouched.
**Charter alignment:** CR-009 (heading hierarchy preserved), NN-C-003 (additive — existing sub-line tag semantics unchanged).

### ADR-5: Phases 2 and 3 run serial despite disjoint file scope
**Context:** Phase 2 (qa twins) and Phase 3 (brainstorm/skill/lens/convergence) touch disjoint files and are nominally `[P]`-eligible. Phase 4 depends on both.
**Decision:** Run them serially (2 then 3), not as parallel sub-phases. See `## Parallel Execution Notes` for the `Why serial` rationale that satisfies qa-plan #11.
**Alternatives considered:** (a) `[P]` sub-phases under a phase group — rejected: the edits are small doc-as-code changes; parallel worktree-isolation overhead and group-QA coordination outweigh the marginal wall-clock gain. (b) Merge 2+3 into one phase — rejected: they cover distinct AC clusters (enforcement vs elicitation); separate phases give qa-phase cleaner review granularity.
**Consequences:** Slightly longer wall-clock; cleaner per-phase QA. No correctness impact (Phase 4 gates the union).
**Charter alignment:** CR-008 (narrow, reviewable units).

## Phases

## Integration-Test Registry (M1)

**No `[integration]` test harness rows.** The spec's `## Integration Coverage` declares three integrations, but **all three have zero doubled true externals** (every boundary is an in-repo doc citation) and NN-C-002 forbids a runtime test runner for markdown. There is therefore no outer `[integration]` test and no contract test. Each declared integration is instead verified by a machine assertion at Phase 4:

| Declared integration (spec) | Verified by | AC |
|---|---|---|
| `skills/spec/SKILL.md` → `behavior-classification.md` + `brainstorm-procedure.md` (elicitation wiring) | 7-site citation grep | AC-11 |
| template / `qa-spec.*` / `qa-plan.*` → `behavior-classification.md` (shared glossary) | 7-site citation grep + `static.sh` symlink/byte-identity | AC-11, AC-12 |
| brainstorm → spec → qa-spec → plan → qa-plan (e2e gate chain) | fixture walk: missing-facet + mislabel both blocked | AC-13 |

This satisfies NFR-INT-02 (absence of an `[integration]` test row = "no runtime integrations declared"); the integration *facet* is still enforced — by grep/static.sh/fixture-walk, the only verification NN-C-002 permits.

### Phase 1 (Non-TDD mode): Single-source reference + spec-template data model
**Exit Gate:** `reference/behavior-classification.md` exists and defines the piece-level criteria, both facets, and the glossary; `templates/spec.md` carries the new front-matter keys, the AC-line tag scheme, the per-facet N/A sentinel, and the SSOT citation, with no new `###` under `## Acceptance Criteria`; `git diff` shows `spec-flow-doctrine.md` L179 unchanged.
**ACs Covered:** AC-1, AC-2
**In scope:** `plugins/spec-flow/reference/behavior-classification.md` (CREATE), `plugins/spec-flow/templates/spec.md` (MODIFY)
**NOT in scope:** the qa-spec/qa-plan enforcement (Phase 2); the brainstorm/skill/lens elicitation (Phase 3); the version bump (Phase 4). No edit to `spec-flow-doctrine.md` (ADR-3) or `gate-scaling.md` (out of scope per spec).
**Charter constraints honored in this phase:**
- NN-C-002 (markdown/config only): both deliverables are markdown; no runtime code or deps.
- NN-C-003 (backward compat): additive new file + additive front-matter keys + additive AC-line tag; no existing key/heading changes meaning.
- CR-005 (repo-root-relative paths): the template's citation to `reference/behavior-classification.md` is repo-root-relative.
- CR-009 (heading hierarchy): the AC-line tag rides the existing `AC-N:` line; NO new `###` is added under `## Acceptance Criteria`.

- [x] **[Implement]** Write the reference doc and template edits
    - Architecture constraints this phase must honor: single source of truth (ADR-3) — the glossary tokens defined here are the exact literals every downstream gate matches; spell them once, here.

    **Change Specifications:**

    **T-1: CREATE `plugins/spec-flow/reference/behavior-classification.md`**
    - Anchor: new file (no current content).
    - Target: an H1 + four H2 sections, ≤ ~70 lines:
      1. `## Piece classification` — defines **behavior-bearing** vs **non-behavioral** at **piece granularity** with concrete criteria (behavior-bearing = the piece's deliverable produces or transforms output a consumer depends on; non-behavioral = config/glue/scaffolding/docs whose correctness is structural, not output-bearing). State the **ambiguity rule**: "When piece classification is genuinely ambiguous, default to `behavior-bearing`." Define the `piece_class:` enum values `behavior-bearing | non-behavioral` and the `behavior_rationale:` companion (required only when `non-behavioral`).
      2. `## Outcome facets` — define the two facets: **`result`** (the running system's output values/content — what an unacceptable *value* looks like, e.g. "$0 masquerading as an earned result") and **`integration`** (the seams are plumbed/wired, the e2e path produces a *real* result not a fixture, nothing is stubbed, no glue is missing). The integration-facet definition MUST literally name: seams, wired/plumbed, e2e, stub, glue.
      3. `## Canonical token glossary` — the closed enum of AC-line tags: `[mechanism]`, `[outcome:result]`, `[outcome:integration]`; the per-facet N/A sentinel **form** (e.g. `Outcome N/A [outcome:result]: <reason>` — pick one literal form and define it as canonical); note exact-literal, case-sensitive matching.
      4. `## Relationship to `spec-flow-doctrine.md`` — one paragraph: this doc is the **piece-level spec-time** classifier; `spec-flow-doctrine.md` L179 remains the **phase-level plan-time** TDD-track default and is unchanged by this doc.
    - Pattern (reference-doc H2 + closed-enum idiom, mirrors `deliberation-artifact.md`):
      ```
      ## Canonical token glossary

      Exactly one of the following tags appears on every `AC-N:` line (case-sensitive, exact literal):
      - `[mechanism]` — the AC asserts construction ("returns X", "writes row Y").
      - `[outcome:result]` — the AC states an unacceptable output value/content.
      - `[outcome:integration]` — the AC states a seam that must be wired/plumbed end-to-end.
      ```
    - Done: all four H2 sections present; both facet definitions present; the integration facet literally names seams/wired/e2e/stub/glue; the three glossary tokens + the N/A sentinel form + the `piece_class:` enum are all present; the file does not edit or restate L179 (it only references it).
    - Verify: `grep -E 'piece_class|behavior-bearing|non-behavioral' …`; `grep -F '[outcome:result]' …`; `grep -F '[outcome:integration]' …`; `grep -F '[mechanism]' …`; `grep -Ei 'seam|plumb|e2e|stub|glue' …`; `git diff -- plugins/spec-flow/reference/spec-flow-doctrine.md` empty.

    **T-2: MODIFY `plugins/spec-flow/templates/spec.md`**
    - Anchor: front-matter block (lines 1–10) and `## Acceptance Criteria` (lines 53–56).
    - Current (front-matter, lines 8–10):
      ```
        coding-rules: {{date}}
        integrations: {{date}}
      ---
      ```
    - Current (AC section, lines 53–56):
      ```
      ## Acceptance Criteria
      AC-1: Given {{precondition}}, When {{action}}, Then {{outcome}}
        Independent Test [machine: <named check — a grep/script/test that decides>]: <how to verify>
        <!-- Alternative form: Independent Test [judgment: <named arbiter — who decides>]: <what they inspect> -->
      ```
    - Target:
      1. Add to the front-matter (after `integrations: {{date}}`, before the closing `---`): `piece_class: {{behavior-bearing|non-behavioral}}` and `behavior_rationale: {{required only when non-behavioral}}`.
      2. In the AC section, add the AC-line tag to the example AC and add a one-line citation + the N/A sentinel form **without** introducing any `###` heading. Keep the example as `AC-1: … [mechanism]` and add an HTML-comment legend listing the three tokens + the per-facet N/A sentinel form, plus a `<!-- Tag tokens and the per-facet N/A sentinel are defined in plugins/spec-flow/reference/behavior-classification.md -->` citation.
    - Pattern (AC line carries TWO orthogonal brackets — AC-line tag + sub-line verifiability tag, per ADR-4):
      ```
      AC-1: Given {{precondition}}, When {{action}}, Then {{outcome}} [mechanism]
        Independent Test [machine: <named check>]: <how to verify>
      <!-- AC-line tag (exactly one): [mechanism] | [outcome:result] | [outcome:integration].
           Per-facet N/A sentinel form: `Outcome N/A [outcome:<facet>]: <reason>`.
           Tokens defined in plugins/spec-flow/reference/behavior-classification.md (CR-005). -->
      ```
    - Done: front-matter has both new keys; the AC example carries an AC-line tag; the three tokens, the N/A sentinel form, and the SSOT citation all appear in the AC section; NO new `### ` line exists between `## Acceptance Criteria` and `## Technical Approach`.
    - Verify: `grep -E '^piece_class:|^behavior_rationale:' templates/spec.md`; `grep -F '[outcome:result]' templates/spec.md`; `grep -F 'behavior-classification.md' templates/spec.md`; `awk '/^## Acceptance Criteria/{f=1;next}/^## Technical Approach/{f=0}f&&/^### /{print}' templates/spec.md` returns nothing.

- [x] **[Write-Tests]** Author the machine-check assertions for Phase 1
    - No "fail first" requirement — doc-as-code; these are grep/diff assertions over the two deliverables.
    - Stage (do NOT commit) a small shell check script (or inline the asserts into the Verify step) covering AC-1 and AC-2 exactly as in the spec's Independent Tests.

    **Test Data:**
    - AC-1: `reference/behavior-classification.md` contains the piece-class criteria, both facet definitions (integration names seams/e2e/stub/glue), and the three glossary tokens → all greps match; `git diff spec-flow-doctrine.md` empty.
    - AC-2: `templates/spec.md` contains the two front-matter keys, the three tag tokens, the N/A sentinel form, and the citation → all greps match; zero `### ` under `## Acceptance Criteria`.

- [x] **[Verify]** Confirm Phase 1 is sound
    **Per-change checks:**
    - T-1: `grep -Eq 'piece_class' plugins/spec-flow/reference/behavior-classification.md && grep -Fq '[outcome:integration]' plugins/spec-flow/reference/behavior-classification.md && grep -Eiq 'seam|plumb|e2e|stub|glue' plugins/spec-flow/reference/behavior-classification.md && git diff --quiet -- plugins/spec-flow/reference/spec-flow-doctrine.md` — Expected: exit 0.
    - T-2: `grep -Eq '^piece_class:' plugins/spec-flow/templates/spec.md && grep -Fq '[outcome:result]' plugins/spec-flow/templates/spec.md && grep -Fq 'behavior-classification.md' plugins/spec-flow/templates/spec.md` and the awk no-new-heading check returns empty — Expected: exit 0 + empty awk output.
    **Phase-level check:**
    - Run: the staged Phase-1 check script (agent-step: read both files, confirm every AC-1/AC-2 clause is present).
    - Expected: all AC-1 and AC-2 assertions pass; `spec-flow-doctrine.md` L179 unchanged.
    - Failure: any missing token/key/citation, a new `###` under `## Acceptance Criteria`, or a non-empty `spec-flow-doctrine.md` diff.

- [x] **[QA]** Phase review
    - Review against: AC-1, AC-2
    - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 2 (Non-TDD mode): Enforcement gates — qa-spec #17 + qa-plan #33
**Exit Gate:** `qa-spec.md` carries criterion #17 (legacy-skip, non-behavioral exemption, per-facet behavior-bearing enforcement, liveness-blocklist heuristic, exact-literal matching, Focused-re-review wiring, Focused-charter exclusion) and `rubric_version: 2`; `qa-plan.md` carries criterion #33 (non-behavioral-spec-vs-TDD-track must-fix; legacy skip) and `rubric_version: 2`; both `.agent.md` twins remain symlinks resolving to their `.md` (unedited directly); the AC-9 / AC-10 / AC-14 fixtures fire/skip correctly.
**ACs Covered:** AC-6, AC-7, AC-9, AC-10, AC-14
**In scope:** `plugins/spec-flow/agents/qa-spec.md` (MODIFY — append #17, bump rubric, wire Input Modes), `plugins/spec-flow/agents/qa-plan.md` (MODIFY — append #33, bump rubric), fixture specs under `plugins/spec-flow/tests/fixtures/outcome-acs/`
**NOT in scope:** ANY write to `qa-spec.agent.md` / `qa-plan.agent.md` (symlinks — ADR-1, they update automatically); the elicitation wiring (Phase 3); the e2e chain walk and the version bump (Phase 4).
<!-- P2/P3 fields omitted: qa-spec.md and qa-plan.md are agent prompt files, NOT multi-step orchestration skills (no `### Step|Phase|Sub-Phase` headings). qa-plan #27 does not trigger. -->
**Authored-tests:** `plugins/spec-flow/tests/fixtures/outcome-acs/behaving-missing-result.md`, `plugins/spec-flow/tests/fixtures/outcome-acs/legacy-no-piececlass.md`, `plugins/spec-flow/tests/fixtures/outcome-acs/behaving-liveness-only.md`
**Charter constraints honored in this phase:**
- NN-C-008 (agents self-contained): #17 reads `piece_class` + the AC-line tags from the spec it is handed; #33 reads `piece_class` + the plan body — neither depends on brainstorm history. #17's matching tokens are quoted inline (self-describing), citing the SSOT for provenance only.
- NN-C-003 (backward compat): criteria are appended (16→17, 32→33) with no renumbering; the `rubric_version` value bump stays within the existing front-matter schema.
- CR-001 (agent front-matter schema): only the `rubric_version` value changes; key set unchanged.
- CR-008 (narrow-executor agents): each agent gains exactly one read-only criterion; no logic moves into the agents beyond the criterion text.

- [x] **[Implement]** Append the two criteria and bump both rubric versions
    - Order: qa-spec.md (#17 + rubric + Input Modes) → qa-plan.md (#33 + rubric). Commit at each file checkpoint.
    - Architecture constraints this phase must honor: edit the `.md` only (ADR-1); the criterion tokens MUST be the exact literals from `reference/behavior-classification.md` (exact-literal, case-sensitive matching is the whole point — a misspelled tag must fail safe).

    **Change Specifications:**

    **T-1: MODIFY `plugins/spec-flow/agents/qa-spec.md`** (rubric front-matter)
    - Anchor: line 4.
    - Current:
      ```
      rubric_version: 1
      ```
    - Target: `rubric_version: 2`.
    - Done: line 4 reads `rubric_version: 2`.
    - Verify: `grep -q '^rubric_version: 2' plugins/spec-flow/agents/qa-spec.md`.

    **T-2: MODIFY `plugins/spec-flow/agents/qa-spec.md`** (append criterion #17)
    - Anchor: end of `## Review Criteria`, immediately after criterion 16's trailing block (the Matching-rules/Waiver continuation at lines 49–54), before `## Output Format` (line 56).
    - Current (lines 53–56):
      ```
          **Waiver mechanism:** A term may be waived by the spec author by adding an inline HTML comment immediately after the flagged term in spec.md: `<!-- weasel-waived: "<term>" — <justification> -->`. When a `<!-- weasel-waived:` comment appears immediately adjacent to a previously flagged term (within the same sentence), skip that occurrence and do NOT flag it. Evidence of the waiver: quote the comment text in the acceptable section. Terms in non-AC/FR prose (e.g., goal statements, testing strategy, open questions) are not scanned — only AC and FR text.

      ## Output Format
      ```
    - Target: insert criterion 17 between line 54 and the blank line preceding `## Output Format`. The criterion text (self-contained, evidence-bearing, modeled on criterion 7 + the criterion-15 sentinel exemption):
      ```
      17. **Outcome / negative-space coverage (behavior-bearing pieces).** Tag matching is
          exact-literal, case-sensitive on the canonical tokens defined in
          `plugins/spec-flow/reference/behavior-classification.md` (`[mechanism]`,
          `[outcome:result]`, `[outcome:integration]`); a mis-cased/mis-spelled tag (e.g.
          `[Outcome]`) does NOT count as an outcome AC.
          Three-state predicate, decided by the spec's `piece_class` front-matter:
          - **Legacy skip:** the spec carries NO `piece_class` field → skip this criterion
            entirely (legacy spec; never retro-failed). This is not a finding and not an error.
          - **Non-behavioral exemption:** `piece_class: non-behavioral` → exempt. Must-fix
            ONLY if `behavior_rationale` is absent (rationale *presence* is the clean state,
            per the criterion-15 sentinel precedent). Quote the missing key on must-fix.
          - **Behavior-bearing enforcement:** `piece_class: behavior-bearing` (or an
            ambiguous-defaulted spec that carries the key) → for EACH facet in {`result`,
            `integration`}, require at least one AC whose AC-line carries `[outcome:<facet>]`
            OR a matching per-facet N/A sentinel. A facet with neither is must-fix: quote the
            missing facet and list the mechanism-only AC IDs.
          **Bounded liveness heuristic:** an `[outcome:result]` AC whose prohibition is purely
          a liveness/crash property — enumerated blocklist {crash, throw, hang, timeout,
          "error out"} — with no value/content property is must-fix (quote the AC). This is a
          fixed enumerated list, NOT open-ended semantic judgment of oracle quality.
      ```
    - Done: criterion 17 present with all five sub-clauses (legacy-skip, non-behavioral exemption, per-facet behavior-bearing enforcement, liveness blocklist, exact-literal matching) and the SSOT citation; numbered exactly `17.`; criterion 16 untouched.
    - Verify: `grep -nE '^17\. ' plugins/spec-flow/agents/qa-spec.md`; `grep -Fq 'Legacy skip' …`; `grep -Fq 'behavior_rationale' …`; `grep -Fq '[outcome:integration]' …`; `grep -Fiq 'liveness' …`.

    **T-3: MODIFY `plugins/spec-flow/agents/qa-spec.md`** (Input Modes — Focused-re-review wiring + Focused-charter exclusion)
    - Anchor: `**Focused re-review mode (iteration 2+):**` list (lines 74–78) and `**Focused charter re-review mode**` (lines 80–88).
    - Current (line 76):
      ```
      2. Scan the delta for regressions on the touched sections — new ambiguity, new PRD contradiction, surviving `[NEEDS CLARIFICATION` or `[PENDING-DECISION` markers (open-bracket prefix, no closing bracket), new weasel words in AC/FR text, new untestable ACs.
      ```
    - Target: append to the Focused-re-review delta-scan a #17 regression clause: if the delta adds ACs to a behavior-bearing piece and a facet becomes uncovered, re-raise #17; if `piece_class` is not visible in the delta, do not evaluate #17. Add a one-line note to the Focused-charter mode that it applies only criteria 8–11, so #17 is **out of scope** there.
    - Pattern (extend the existing numbered delta-scan item, mirroring its `[NEEDS CLARIFICATION` clause):
      ```
      … new untestable ACs, and — when `piece_class` is visible in the delta and resolves to
      behavior-bearing — a facet that the delta's new ACs leave uncovered (#17 regression).
      If `piece_class` is not in the delta, do not evaluate #17.
      ```
    - Done: Focused-re-review names the #17 delta-regression rule with the "piece_class not in delta → do not evaluate" guard; Focused-charter mode's "criteria 8, 9, 10, and 11" scope line is preserved (it already excludes #17 by enumeration — confirm no edit makes #17 in-scope there).
    - Verify: `grep -Fq '#17' plugins/spec-flow/agents/qa-spec.md` within the Input Modes section; confirm the Focused-charter line still reads "criteria 8, 9, 10, and 11" (unchanged).

    **T-4: MODIFY `plugins/spec-flow/agents/qa-plan.md`** (rubric front-matter)
    - Anchor: line 4.
    - Current:
      ```
      rubric_version: 1
      ```
    - Target: `rubric_version: 2`.
    - Done: line 4 reads `rubric_version: 2`.
    - Verify: `grep -q '^rubric_version: 2' plugins/spec-flow/agents/qa-plan.md`.

    **T-5: MODIFY `plugins/spec-flow/agents/qa-plan.md`** (append criterion #33)
    - Anchor: end of `## Review Criteria`, after criterion 32's `**Must-fix** for either (a) or (b).` (line 198), before `## Output Format` (line 200).
    - Current (lines 198–200):
      ```
          **Must-fix** for either (a) or (b).

      ## Output Format
      ```
    - Target: insert criterion 33 between line 198 and `## Output Format`:
      ```
      33. **Anti-mislabel cross-check (spec piece_class vs plan track).** Read the spec's
          `piece_class` front-matter. When it is `non-behavioral`, the plan must contain NO
          TDD-track phase — i.e. no `[TDD-Red]` block anywhere. A `non-behavioral` spec whose
          plan uses the TDD track (the plan treats the piece as behavior-bearing) is a
          divergence → must-fix: quote the `piece_class: non-behavioral` line and the
          contradicting `[TDD-Red]` phase heading. When the spec has no `piece_class` field
          (legacy) → skip (not an error). When `piece_class: behavior-bearing` → not applicable
          (a behavior-bearing piece may legitimately use either track).
      ```
    - Done: criterion 33 present; numbered `33.`; states the non-behavioral+TDD must-fix, the legacy skip, and the behavior-bearing N/A; criterion 32 untouched.
    - Verify: `grep -nE '^33\. ' plugins/spec-flow/agents/qa-plan.md`; `grep -Fq 'non-behavioral' …`; `grep -Fq '[TDD-Red]' …`.

- [x] **[Write-Tests]** Author the gate-behavior fixtures
    - No "fail first" — these are input fixtures fed to the agents during judgment-AC verification.
    - Stage (do NOT commit) three fixture spec files; the Verify step / QA reviewer dispatches `qa-spec` (Full mode) against each.

    **Test Data:**
    - AC-9 fixture `behaving-missing-result.md`: `piece_class: behavior-bearing`; all ACs `[mechanism]`; NO `[outcome:result]` AC and NO result-facet N/A sentinel → expect a #17 must-fix; spec NOT returned clean.
    - AC-10 fixture `legacy-no-piececlass.md`: NO `piece_class` front-matter key; mechanism-only ACs → expect ZERO #17 findings (legacy skip).
    - AC-14 fixture `behaving-liveness-only.md`: `piece_class: behavior-bearing`; its sole `[outcome:result]` AC states only "must never crash" → expect a #17 liveness-heuristic must-fix (the gate fires, not merely contains the rule text).

- [x] **[Verify]** Confirm Phase 2 is sound
    **Per-change checks:**
    - T-1/T-4: `grep -q '^rubric_version: 2' plugins/spec-flow/agents/qa-spec.md && grep -q '^rubric_version: 2' plugins/spec-flow/agents/qa-plan.md` — Expected: exit 0.
    - T-2/T-3: `grep -Eq '^17\. ' plugins/spec-flow/agents/qa-spec.md` and the #17 sub-clause greps — Expected: all match.
    - T-5: `grep -Eq '^33\. ' plugins/spec-flow/agents/qa-plan.md` and the #33 greps — Expected: all match.
    - Symlink intact: `[ -L plugins/spec-flow/agents/qa-spec.agent.md ] && [ -L plugins/spec-flow/agents/qa-plan.agent.md ]` and `diff plugins/spec-flow/agents/qa-spec.md plugins/spec-flow/agents/qa-spec.agent.md` empty — Expected: exit 0, empty diff (twin reflects the edit via symlink).
    **Phase-level check (judgment ACs — agent dispatch):**
    - Run: dispatch `qa-spec` (Full mode) against each of the three fixtures.
    - Expected: AC-9 fixture → ≥1 #17 must-fix, not clean; AC-10 fixture → zero #17 findings; AC-14 fixture → #17 liveness must-fix.
    - Failure: AC-9/AC-14 fixture returned clean (false-pass = gate not firing); AC-10 fixture flagged (false-fail = legacy retro-failed).

- [x] **[QA]** Phase review
    - Review against: AC-6, AC-7, AC-9, AC-10, AC-14
    - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 3 (Non-TDD mode): Elicitation wiring — brainstorm + spec skill + lens + convergence
**Exit Gate:** `brainstorm-procedure.md` has the always-run negative-space block (both dimensions, depth-independent, non-behavioral auto-skip); `skills/spec/SKILL.md` instructs always-write-`piece_class`-on-new + no-back-fill-on-drift + Phase-2 elicitation citation + step-7 per-facet outcome-AC check, with the Phase-5 `ac_verifiability` computation left sub-line-scoped (AC-15); the `user-intent` lens row carries the negative-space dimensions with the table still at exactly 5 rows; `deliberation-convergence.md` folds a negative-space CONTESTED into the VOQ-N scheme.
**ACs Covered:** AC-3, AC-4, AC-5, AC-15
**In scope:** `plugins/spec-flow/reference/brainstorm-procedure.md` (MODIFY), `plugins/spec-flow/skills/spec/SKILL.md` (MODIFY), `plugins/spec-flow/agents/deliberation-lens.md` (MODIFY), `plugins/spec-flow/agents/deliberation-convergence.md` (MODIFY)
**NOT in scope:** the enforcement criteria (Phase 2); the version bump and integration verification (Phase 4). The lens table row COUNT must not change (stays 5). The Phase-5 `ac_verifiability` grep pattern must NOT be made to match `[outcome:*]` (AC-15 — the edit there is a clarifying note only).
**Steps traversed (P2):** `skills/spec/SKILL.md` — Phase 2 step 3 (cite the FR-OA-4 elicitation block in the sub-area list), Phase 2 step 7.1/7.2 (H-5 per-facet outcome-AC coverage self-check), Phase 1 step 7 + Phase 3 step 1/2 (always-write `piece_class` on greenfield, never back-fill on drift/amend), Phase 4 step 3a / line 328 (defensive note that `ac_verifiability` counts only the Independent-Test sub-line, excluding AC-line outcome/mechanism tags).
**Dispatch sites (P3):** none — no agent dispatch call is added, removed, or re-targeted. All edits are to brainstorm-block prose, authoring instructions, the H-5 self-check, and the metrics-computation note; the existing qa-spec / deliberation / research / fix-doc dispatch sites are untouched.
**Why serial:** runs after Phase 2 (not in parallel) — see `## Parallel Execution Notes`.
**Charter constraints honored in this phase:**
- NN-C-008 (self-contained): the brainstorm block is authored so it fires on its own (depth-independent) and never assumes the `user-intent` lens ran — the lens hop is an *enhancer*, not a precondition.
- NN-P-001 (human approval gate never removed): the negative-space block adds elicitation but never auto-advances; the sign-off keystroke is always required.
- CR-008 (thin-orchestrator): elicitation logic lives in the reference doc + the spec skill; the lens gains only question text, no logic.
- CR-005 (repo-root-relative paths): the skill's citation to the brainstorm block + `behavior-classification.md` is repo-root-relative.
- CR-009 (heading hierarchy): the new brainstorm block is an `###` under `## Core Brainstorm Building Blocks` (sibling to C-2/C-3); no heading nesting is broken.

- [x] **[Implement]** Wire the four elicitation surfaces
    - Order: brainstorm-procedure.md (define the block) → SKILL.md (cite it + authoring + H-5 + metrics note) → deliberation-lens.md (extend row) → deliberation-convergence.md (VOQ fold note). Commit at each file checkpoint.
    - Architecture constraints this phase must honor: the lens table stays exactly 5 rows (depth-subset refs + the spec skill's "exactly five lenses" assertion depend on it); the brainstorm block is the depth-independent PRIMARY path (covers lite/off depth where `user-intent` is not in the lens subset).

    **Change Specifications:**

    **T-1: MODIFY `plugins/spec-flow/reference/brainstorm-procedure.md`** (always-run negative-space block + invocation-order mention)
    - Anchor: `## Core Brainstorm Building Blocks` — insert a new `###` block after `### C-2: Security Sub-Block (always-run)` (ends line 76), before `### C-3: Floor Check Pattern` (line 78); also add a one-line mention to the "Remaining Core Brainstorm Building Blocks" list at line 9.
    - Current (line 9):
      ```
      6. Remaining Core Brainstorm Building Blocks (C-2 always-run, C-3, Approach+Tradeoffs) — run during brainstorm session
      ```
    - Current (lines 76–78):
      ```
      5. Secrets handling — are API keys, tokens, or credentials involved, and how are they managed?

      ### C-3: Floor Check Pattern
      ```
    - Target:
      1. Line 9 → add the negative-space block to the parenthetical: `(C-2 always-run, C-NS negative-space always-run, C-3, Approach+Tradeoffs)`.
      2. Insert after line 76 a new always-run block modeled on C-2:
      ```
      ### C-NS: Negative-Space Sub-Block (always-run)
      [shared] Always-run, depth-independent — it fires whenever the brainstorm runs and does
      NOT depend on any deliberation lens firing (so lite/off-depth pieces are still covered).
      Pose the two-dimensional negative-space question: *"When this runs end-to-end and integrated
      with its surroundings: (a) what unacceptable output values/content could it produce
      (result facet), and (b) what could be left unwired, stubbed, or not actually plumbed in so
      e2e doesn't really work (integration facet)?"* Record, **per facet**, at least one answer
      or an explicit facet N/A before sign-off; the captured answers become `[outcome:result]` /
      `[outcome:integration]` ACs (tokens per `plugins/spec-flow/reference/behavior-classification.md`).
      **Auto-skip** ONLY when the piece is `piece_class: non-behavioral` with a recorded
      `behavior_rationale` (surfaced to the user as a one-line note, not a silent skip). The
      sign-off keystroke is always required (NN-P-001).
      ```
    - Pattern (the C-2 always-run header + `[shared]` framing it mirrors): see lines 65–70.
    - Done: line 9 lists the new block; a `### C-NS` always-run block exists with both question dimensions, the depth-independence statement, and the non-behavioral auto-skip clause; it cites `behavior-classification.md`.
    - Verify: `grep -Fq 'C-NS' plugins/spec-flow/reference/brainstorm-procedure.md`; `grep -Fiq 'result facet' …`; `grep -Fiq 'integration facet' …`; `grep -Fiq 'depth-independent' …`; `grep -Fiq 'non-behavioral' …`.

    **T-2: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** (Phase 2 step 3 citation + step 7 self-check)
    - Anchor: Phase 2 step 3 mandatory-blocks sentence (line 222) and step 7.1 (line 240).
    - Current (line 222, tail):
      ```
      Mandatory blocks (C-1, C-2, H-4, M-7) follow the auto-skip / confirmation-not-discovery logic in `reference/brainstorm-procedure.md` (cite, do not restate).
      ```
    - Current (line 240):
      ```
         1. **FR→AC coverage check:** Explicitly list: "I see N FRs. Let me verify each has at least one AC." Flag any FR with zero ACs. Flag any AC with no stated test approach.
      ```
    - Target:
      1. Line 222 → add `C-NS` to the mandatory-blocks citation: `Mandatory blocks (C-1, C-2, C-NS negative-space, H-4, M-7) follow the auto-skip / confirmation-not-discovery logic in `reference/brainstorm-procedure.md` (cite, do not restate).`
      2. After step 7.1 (line 240) add a per-facet outcome-AC coverage self-check mirroring the FR→AC check:
      ```
         1a. **Outcome-AC per-facet coverage check (behavior-bearing only):** When
             `piece_class` is behavior-bearing, list: "For each facet {result, integration},
             do I have ≥1 `[outcome:<facet>]` AC or a facet N/A sentinel?" Flag any uncovered
             facet before writing the spec. Skip when `piece_class: non-behavioral` (rationale
             recorded). Tokens per `reference/behavior-classification.md`.
      ```
    - Done: step 3 cites `C-NS`; step 7 carries the per-facet outcome-AC self-check naming both facets + the non-behavioral skip.
    - Verify: `grep -Fq 'C-NS' plugins/spec-flow/skills/spec/SKILL.md`; `grep -Fiq 'per-facet' …` near step 7.

    **T-3: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** (Phase 3 always-write + no-back-fill + Phase 5 metrics note)
    - Anchor: Phase 3 Write (lines 246–256) and Phase 4 step 3a metrics computation (line 328; numbered "Phase 4" in this file but it is the metrics/commit phase).
    - Current (line 255):
      ```
      2. Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/spec.md` as the structural guide. Populate the `charter_snapshot:` front-matter with the charter dates captured in Phase 1 step 3: `git log` last-commit date per domain (charter skills carry no `last_updated:` front-matter). If a charter domain is absent, omit its key from the snapshot block (do not write a blank/null value).
      ```
    - Target:
      1. Append to the Phase 3 Write instructions (after line 255) a step 3 authoring rule: `3. **Always write `piece_class` on a new (greenfield) spec.** Resolve behavioral status from the brainstorm; an ambiguous status resolves to `behavior-bearing` and is written into the key (never left absent). Write `behavior_rationale` only when `non-behavioral`. **Do NOT back-fill `piece_class` on a drift/amend re-run** (Phase 1 step 7): a legacy spec that reached this skill without the key stays without it — the absent key is the legacy/exempt discriminator that `qa-spec` #17 and `qa-plan` #33 rely on. Tokens/enum per `reference/behavior-classification.md`.`
      2. Add a defensive clause to the `ac_verifiability` computation at line 328 (AC-15): after "carries a `[machine: …]` tag … → `machine`", insert a parenthetical: `(count only the indented `Independent Test` sub-line; the orthogonal `[mechanism]`/`[outcome:result]`/`[outcome:integration]` AC-line tags are NOT counted and MUST NOT alter machine/judgment counts)`.
    - Pattern (the existing no-blank-value authoring rule at line 255 is the model for a precise authoring instruction).
    - Done: Phase 3 has the always-write rule (ambiguity→behavior-bearing, rationale only when non-behavioral) and the explicit no-back-fill instruction tying the absent key to legacy/exempt; line 328 carries the AC-line-tags-excluded clause.
    - Verify: `grep -Fq 'Always write' plugins/spec-flow/skills/spec/SKILL.md`; `grep -Fiq 'do not back-fill' …` (case-insensitive); `grep -Fq 'MUST NOT alter machine/judgment' …`.

    **T-4: MODIFY `plugins/spec-flow/agents/deliberation-lens.md`** (extend `user-intent` row — keep 5 rows)
    - Anchor: the `user-intent` table row (line 37).
    - Current (line 37):
      ```
      | `user-intent` | Does the recommendation genuinely serve the PRD user story and acceptance criteria? Will the user's actual goal be met? |
      ```
    - Target: extend the question with the negative-space dimensions WITHOUT adding a row:
      ```
      | `user-intent` | Does the recommendation genuinely serve the PRD user story and acceptance criteria? Will the user's actual goal be met? And does it state its negative space — what unacceptable output value/content (result facet) must it never produce, and what seam must never be left unwired/stubbed/not-plumbed end-to-end (integration facet)? A recommendation silent on its negative space is CONTESTED. |
      ```
    - Done: the `user-intent` row names both negative-space facets; the table is still exactly 5 rows (the four other rows untouched).
    - Verify: `grep -Fiq 'negative space' plugins/spec-flow/agents/deliberation-lens.md`; row count: `awk '/^\| `?architecture-integrity/{c++}/^\| `?scope/{c++}/^\| `?user-intent/{c++}/^\| `?backward-compat/{c++}/^\| `?risk/{c++}END{print c}'` style check — simplest: assert exactly 5 data rows between the table header and `## Procedure` (the [Verify] step uses the spec's "count lens table rows == 5").

    **T-5: MODIFY `plugins/spec-flow/agents/deliberation-convergence.md`** (negative-space CONTESTED → VOQ fold)
    - Anchor: Procedure step 2 "Generate `§Validated Open Questions`" (lines 34–37).
    - Current (lines 34–36):
      ```
      2. **Generate `§Validated Open Questions`.**
         - Only questions that survived adversarial review **unresolved** belong here. A CONTESTED verdict that was resolved by a recommendation revision is NOT a validated open question — it goes in `§Answered by Investigation`.
         - Assign each surviving question a stable `VOQ-N` ID sequentially starting from `VOQ-1`. ID assignment follows the contract in [`plugins/spec-flow/reference/deliberation-artifact.md`](../reference/deliberation-artifact.md) — `## VOQ-N ID contract`.
      ```
    - Target: add a sub-bullet making explicit that a `user-intent` negative-space CONTESTED folds into this same sequential scheme:
      ```
         - A `user-intent` negative-space CONTESTED (the recommendation is silent on an
           unacceptable result value or an unwired/stubbed integration seam) folds into this
           same scheme: if unresolved after Phase E revision, it becomes a surviving `VOQ-N`
           (which the spec brainstorm then surfaces as a negative-space question); if resolved
           by a recommendation revision, it goes to `§Answered by Investigation`.
      ```
    - Done: step 2 explicitly names the negative-space CONTESTED → VOQ-N fold; sequential `VOQ-N` contract unchanged.
    - Verify: `grep -Fiq 'negative-space' plugins/spec-flow/agents/deliberation-convergence.md`; `grep -Fq 'VOQ-N' …`.

- [x] **[Write-Tests]** Author the Phase 3 machine checks
    - No "fail first" — grep assertions over the four edited files + the lens-row-count check + the AC-15 metric non-interference assertion.

    **Test Data:**
    - AC-3: SKILL.md contains all four authoring instructions (elicitation citation, always-write, no-back-fill, step-7 per-facet check) → greps match.
    - AC-4: brainstorm-procedure.md C-NS block has both dimensions + depth-independence + non-behavioral auto-skip → greps match.
    - AC-5: lens `user-intent` row carries negative-space text; lens table == exactly 5 rows; convergence has the negative-space→VOQ fold → greps + row count.
    - AC-15: run the Phase-5 `ac_verifiability` count on a fully-tagged fixture spec (carries `[mechanism]`/`[outcome:*]` AC-line tags AND `[machine:]`/`[judgment:]` sub-line tags); assert `machine + judgment` equals the count of `[machine:]`/`[judgment:]` sub-lines and is identical with vs without the AC-line tags present.

- [x] **[Verify]** Confirm Phase 3 is sound
    **Per-change checks:**
    - T-1: C-NS greps (block, both facets, depth-independent, non-behavioral) — Expected: all match.
    - T-2/T-3: SKILL.md greps (C-NS citation, per-facet check, always-write, no-back-fill, AC-15 note) — Expected: all match.
    - T-4: `grep -Fiq 'negative space' deliberation-lens.md` + lens table has exactly 5 data rows — Expected: match + count 5.
    - T-5: `grep -Fiq 'negative-space' deliberation-convergence.md` — Expected: match.
    **Phase-level check:**
    - Run (AC-15, machine): execute the `ac_verifiability` computation (per SKILL.md line 328 procedure) against the fully-tagged fixture, once as-is and once with the AC-line tags stripped; assert identical `machine`/`judgment` counts and that both equal the `[machine:]`/`[judgment:]` sub-line count.
    - Run (AC-3, agent-step): read SKILL.md; confirm the four authoring instructions are present and unambiguous.
    - Expected: AC-15 counts identical and equal to sub-line tag count; AC-3 four instructions present; lens table exactly 5 rows.
    - Failure: any missing instruction/clause; lens table ≠ 5 rows; AC-15 counts differ between tagged/untagged (metric seam perturbed).

- [x] **[QA]** Phase review
    - Review against: AC-3, AC-4, AC-5, AC-15
    - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 4 (Non-TDD mode): Version triad + static.sh + integration verification
**Exit Gate:** BOTH `plugin.json` descriptors (`plugins/spec-flow/plugin.json` Copilot + `plugins/spec-flow/.claude-plugin/plugin.json` Claude), the `marketplace.json` spec-flow entry, and `CHANGELOG.md` all read 5.17.0 with a `## [5.17.0]` section; `static.sh` lines 209/211 assert `5.17.0`; `static.sh` passes (its line-209 assertion targets `plugins/spec-flow/plugin.json` — now bumped); the seven `behavior-classification.md` citation sites all match; the version-parity diff across all three JSON surfaces is empty; the AC-15 metric non-interference assertion holds; the e2e gate-chain fixture walk blocks on both the missing-facet and the mislabel injection.
**ACs Covered:** AC-8, AC-11, AC-12, AC-13
**In scope:** `plugins/spec-flow/plugin.json` (MODIFY — Copilot descriptor), `plugins/spec-flow/.claude-plugin/plugin.json` (MODIFY — Claude descriptor), `.claude-plugin/marketplace.json` (MODIFY — spec-flow entry), `plugins/spec-flow/CHANGELOG.md` (MODIFY — new section), `plugins/spec-flow/tests/e2e/lib/static.sh` (MODIFY — lines 209/211), e2e fixtures under `plugins/spec-flow/tests/fixtures/outcome-acs/`
**NOT in scope:** any further edit to the Phase 1–3 deliverables (they must be complete before this phase verifies them); `static.sh` line 216 (CHANGELOG `[5.16.1]` section check — stays valid, append-only).
<!-- P2/P3 fields omitted: no skills/*/SKILL.md edited in this phase. -->
**Authored-tests:** `plugins/spec-flow/tests/fixtures/outcome-acs/nonbehavioral-spec.md`, `plugins/spec-flow/tests/fixtures/outcome-acs/nonbehavioral-tdd-plan.md`
**Charter constraints honored in this phase:**
- NN-C-009 (version bump on plugin change): BOTH host `plugin.json` descriptors (Copilot + Claude) + `marketplace.json` + `CHANGELOG.md` + the two static.sh literal assertions are bumped together in this phase per `docs/releasing.md` (ADR-2).
- NN-C-003 (backward compat): MINOR bump 5.16.1 → 5.17.0; CHANGELOG entry under additive Keep-a-Changelog groupings.

- [x] **[Implement]** Bump the version quad and author the e2e fixtures
    - Order: plugin.json (Copilot) → .claude-plugin/plugin.json (Claude) → marketplace.json → CHANGELOG.md → static.sh → fixtures. Commit at each checkpoint.
    - Architecture constraints this phase must honor: ALL THREE JSON version surfaces (both `plugin.json` descriptors + the `marketplace.json` spec-flow entry) must agree at 5.17.0 (ADR-2); static.sh line 209 targets `plugins/spec-flow/plugin.json` (Copilot), so that descriptor MUST be bumped or static.sh fails; lines 209/211 are part of the sync surface.

    **Change Specifications:**

    **T-1: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`** (Claude Code descriptor)
    - Anchor: line 4 (`"version"` field; `"description"` is on line 3).
    - Current:
      ```
        "version": "5.16.1",
      ```
    - Target: `  "version": "5.17.0",`.
    - Done: line 4 reads 5.17.0.
    - Verify: `jq -r .version plugins/spec-flow/.claude-plugin/plugin.json` == `5.17.0`.

    **T-1b: MODIFY `plugins/spec-flow/plugin.json`** (Copilot CLI co-ship descriptor — the static.sh line-209 target)
    - Anchor: line 4 (`"version"` field; `"description"` is on line 3 — identical layout to the Claude descriptor above).
    - Current:
      ```
        "version": "5.16.1",
      ```
    - Target: `  "version": "5.17.0",`.
    - Done: line 4 reads 5.17.0.
    - Rationale: `static.sh` line 207 binds `pluginjson="${PLUGIN_ROOT}/plugin.json"` = `plugins/spec-flow/plugin.json`; T-4 makes line 209 assert 5.17.0 against it. Without this bump static.sh fails and AC-12 cannot pass. Also required by NN-C-009 (both host descriptors must match) per `docs/releasing.md` row 1.
    - Verify: `jq -r .version plugins/spec-flow/plugin.json` == `5.17.0`.

    **T-2: MODIFY `.claude-plugin/marketplace.json`**
    - Anchor: spec-flow plugin entry `version` (line 15).
    - Current:
      ```
            "version": "5.16.1",
      ```
    - Target: `      "version": "5.17.0",` (the spec-flow entry only; the `qa` entry at line 24 stays `1.1.1`).
    - Done: the spec-flow entry reads 5.17.0; qa entry unchanged.
    - Verify: `jq -r '.plugins[]|select(.name=="spec-flow").version' .claude-plugin/marketplace.json` == `5.17.0`.

    **T-3: MODIFY `plugins/spec-flow/CHANGELOG.md`** (new 5.17.0 section)
    - Anchor: between `## [Unreleased]` (line 5) and `## [5.16.1] — 2026-06-12` (line 7).
    - Current (lines 5–7):
      ```
      ## [Unreleased]

      ## [5.16.1] — 2026-06-12
      ```
    - Target: insert a `## [5.17.0] — 2026-06-12` section after line 5 (Keep-a-Changelog: newest dated section first, under `## [Unreleased]`):
      ```
      ## [5.17.0] — 2026-06-12

      ### Added
      - **FR-018: Outcome & negative-space acceptance criteria.** Behavior-bearing specs must
        now state negative space across two facets — `result` (unacceptable output values) and
        `integration` (seams plumbed/e2e/no-stub). New `reference/behavior-classification.md`
        single source of truth (piece-granularity definition + two facets + canonical token
        glossary). New `piece_class:`/`behavior_rationale:` spec front-matter and the
        `[mechanism]`/`[outcome:result]`/`[outcome:integration]` AC-line tag scheme.
      - Always-run negative-space brainstorm block (depth-independent) + `user-intent` lens
        negative-space dimension folding into the `VOQ-N` scheme.
      - `qa-spec` criterion #17 (two-facet presence, bounded liveness heuristic, exact-literal
        matching, legacy-skip, non-behavioral exemption) and `qa-plan` criterion #33
        (anti-mislabel: non-behavioral spec must not carry a TDD-track plan). Both
        `rubric_version` 1→2.

      ### Changed
      - `tests/e2e/lib/static.sh` version assertions bumped to 5.17.0.
      ```
    - Done: a `## [5.17.0]` section exists above `## [5.16.1]`, documenting the additions + the static.sh change.
    - Verify: `grep -Fq '## [5.17.0]' plugins/spec-flow/CHANGELOG.md`.

    **T-4: MODIFY `plugins/spec-flow/tests/e2e/lib/static.sh`** (version-literal assertions — ADR-2)
    - Anchor: lines 209 and 211.
    - Current:
      ```
        assert_grep '"version": "5\.16\.1"' "$pluginjson" \
          "AC-11: plugin.json version is 5.16.1"
        assert_grep '"version": "5\.16\.1"' "$marketplace" \
          "AC-11: marketplace.json spec-flow entry is 5.16.1"
      ```
    - Target: replace both `5\.16\.1` literals with `5\.17\.0` and update the two message strings to "5.17.0". **Leave line 216** (`assert_grep "\[5\.16\.1\]" "$changelog"`) unchanged — the 5.16.1 CHANGELOG section persists (append-only).
    - Done: lines 209/211 assert `5\.17\.0`; line 216 still asserts `\[5\.16\.1\]`.
    - Verify: `grep -Fq '5\.17\.0' plugins/spec-flow/tests/e2e/lib/static.sh` (two hits at 209/211); `grep -Fq '\[5\.16\.1\]' plugins/spec-flow/tests/e2e/lib/static.sh` (line 216 intact).

    **T-5: CREATE e2e gate-chain fixtures** `plugins/spec-flow/tests/fixtures/outcome-acs/nonbehavioral-spec.md` + `nonbehavioral-tdd-plan.md`
    - Anchor: new files.
    - Target: a `piece_class: non-behavioral` spec (with `behavior_rationale`) and a matching plan that (wrongly) contains a `[TDD-Red]` phase — the mislabel injection for AC-13's #33 half. Reuse the Phase-2 `behaving-missing-result.md` fixture as the missing-facet injection for AC-13's #17 half.
    - Done: both fixtures exist and are well-formed.
    - Verify: `test -f` both paths.

- [x] **[Write-Tests]** Author the integration sweep assertions
    - No "fail first" — these are the AC-8/AC-11/AC-12/AC-13 machine + agent checks run against the now-complete piece.

    **Test Data:**
    - AC-8: `jq` versions of BOTH `plugin.json` descriptors (`plugins/spec-flow/plugin.json` + `plugins/spec-flow/.claude-plugin/plugin.json`) and the `marketplace.json` spec-flow entry are all equal and all `5.17.0`; CHANGELOG has `## [5.17.0]`.
    - AC-11: each of the seven sites — `templates/spec.md`, `agents/qa-spec.md`, `agents/qa-spec.agent.md`, `agents/qa-plan.md`, `agents/qa-plan.agent.md`, `reference/brainstorm-procedure.md`, `skills/spec/SKILL.md` — contains `behavior-classification.md`; zero unwired sites.
    - AC-12: `static.sh` passes (per-pair `[ -L ]` + 27-pair drift guard + version assertions).
    - AC-13: walk a fixture piece through brainstorm→spec→qa-spec→plan→qa-plan for both injections — (i) behavior-bearing spec missing a facet → blocked at qa-spec #17; (ii) non-behavioral spec + TDD-track plan → blocked at qa-plan #33. Neither silently passes.

- [x] **[Verify]** Confirm Phase 4 + the whole piece is sound
    **Per-change checks:**
    - T-1/T-1b/T-2 (AC-8): all three JSON version surfaces equal and `5.17.0` —
      `a=$(jq -r .version plugins/spec-flow/plugin.json); b=$(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json); c=$(jq -r '.plugins[]|select(.name=="spec-flow").version' .claude-plugin/marketplace.json); [ "$a" = 5.17.0 ] && [ "$b" = 5.17.0 ] && [ "$c" = 5.17.0 ]` — Expected: exit 0 (all three match).
    - T-3 (AC-8): `grep -Fq '## [5.17.0]' plugins/spec-flow/CHANGELOG.md` — Expected: match.
    - T-4 (AC-12 precondition): static.sh asserts 5.17.0 at 209/211, `\[5.16.1\]` at 216 — Expected: matches.
    **Phase-level check (integration sweep):**
    - Run (AC-11, machine): `for f in templates/spec.md agents/qa-spec.md agents/qa-spec.agent.md agents/qa-plan.md agents/qa-plan.agent.md reference/brainstorm-procedure.md skills/spec/SKILL.md; do grep -Fq 'behavior-classification.md' plugins/spec-flow/$f || echo "UNWIRED: $f"; done` — Expected: no UNWIRED output (all seven match; the two `.agent.md` match via symlink).
    - Run (AC-12, machine): execute `plugins/spec-flow/tests/e2e/lib/static.sh` (via the e2e harness) — Expected: pass, including the qa-spec/qa-plan per-pair symlink + byte-identity assertions, the 27-pair drift guard, and the bumped version assertions.
    - Run (AC-13, agent-step): walk both fixture injections through the chain — Expected: missing-facet blocked at qa-spec #17; non-behavioral+TDD-plan blocked at qa-plan #33; neither silently passes.
    - Expected (summary): version parity holds; zero unwired citation sites; static.sh green; both e2e injections blocked.
    - Failure: any version mismatch; any UNWIRED site; static.sh failure; either e2e injection silently passing.

- [x] **[QA]** Phase review
    - Review against: AC-8, AC-11, AC-12, AC-13
    - Diff baseline: git diff {{phase_start_tag}}..HEAD

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | `behavior-classification.md` defines piece criteria + both facets + glossary; L179 unchanged | COVERED | Phase 1 (T-1) |
| AC-2 | spec template: front-matter keys + AC-line tags + N/A sentinel + citation; no new `###` | COVERED | Phase 1 (T-2) |
| AC-3 | SKILL.md: always-write + no-back-fill + elicitation citation + step-7 per-facet check | COVERED | Phase 3 (T-2, T-3) |
| AC-4 | brainstorm-procedure C-NS always-run block: both dimensions, depth-independent, auto-skip | COVERED | Phase 3 (T-1) |
| AC-5 | lens `user-intent` negative-space + 5 rows + convergence VOQ fold | COVERED | Phase 3 (T-4, T-5) |
| AC-6 | qa-spec #17 (all sub-clauses) + `rubric_version: 2`; `.agent.md` symlink | COVERED | Phase 2 (T-1, T-2, T-3) |
| AC-7 | qa-plan #33 + `rubric_version: 2`; `.agent.md` symlink | COVERED | Phase 2 (T-4, T-5) |
| AC-8 | both `plugin.json` descriptors + `marketplace.json` + `CHANGELOG.md` == 5.17.0 | COVERED | Phase 4 (T-1, T-1b, T-2, T-3) |
| AC-9 | behavior-bearing spec missing result facet → #17 must-fix, not clean | COVERED | Phase 2 (fixture `behaving-missing-result.md`) |
| AC-10 | legacy spec (no `piece_class`) → #17 skipped, zero findings | COVERED | Phase 2 (fixture `legacy-no-piececlass.md`) |
| AC-11 | all seven `behavior-classification.md` citation sites present (no unwired) | COVERED | Phase 4 verify (citations inserted Phases 1–3) |
| AC-12 | `qa-spec.agent.md`/`qa-plan.agent.md` symlinks; static.sh passes | COVERED | Phase 4 (static.sh run; symlink seam from 5.16.1 + Phase 2 edits) |
| AC-13 | e2e chain blocks on missing facet (qa-spec) OR mislabel (qa-plan) | COVERED | Phase 4 (fixture walk; gates built Phase 2, elicitation Phase 3) |
| AC-14 | behavior-bearing liveness-only `[outcome:result]` → #17 liveness must-fix | COVERED | Phase 2 (fixture `behaving-liveness-only.md`) |
| AC-15 | new AC-line tags do not perturb `ac_verifiability` machine/judgment counts | COVERED | Phase 3 (T-3 defensive note + metric non-interference assertion) |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `grep -Eq 'piece_class' plugins/spec-flow/reference/behavior-classification.md && grep -Fq '[outcome:integration]' plugins/spec-flow/reference/behavior-classification.md && grep -Eiq 'seam\|plumb\|e2e\|stub\|glue' plugins/spec-flow/reference/behavior-classification.md && git diff --quiet -- plugins/spec-flow/reference/spec-flow-doctrine.md` | exit 0 (definitions present; L179 unchanged) |
| AC-2 | shell | `grep -Eq '^piece_class:' plugins/spec-flow/templates/spec.md && grep -Fq '[outcome:result]' plugins/spec-flow/templates/spec.md && grep -Fq 'behavior-classification.md' plugins/spec-flow/templates/spec.md && [ -z "$(awk '/^## Acceptance Criteria/{f=1;next}/^## Technical Approach/{f=0}f&&/^### /' plugins/spec-flow/templates/spec.md)" ]` | exit 0 (keys/tokens/citation present; no new `###`) |
| AC-3 | agent-step | Read `plugins/spec-flow/skills/spec/SKILL.md`; confirm always-write `piece_class`, no-back-fill on drift/amend, Phase-2 C-NS citation, step-7 per-facet check are all present and unambiguous | all four instructions present |
| AC-4 | shell | `grep -Fq 'C-NS' plugins/spec-flow/reference/brainstorm-procedure.md && grep -Fiq 'result facet' plugins/spec-flow/reference/brainstorm-procedure.md && grep -Fiq 'integration facet' plugins/spec-flow/reference/brainstorm-procedure.md && grep -Fiq 'depth-independent' plugins/spec-flow/reference/brainstorm-procedure.md && grep -Fiq 'non-behavioral' plugins/spec-flow/reference/brainstorm-procedure.md` | exit 0 |
| AC-5 | shell | `grep -Fiq 'negative space' plugins/spec-flow/agents/deliberation-lens.md && grep -Fiq 'negative-space' plugins/spec-flow/agents/deliberation-convergence.md` + lens table data-row count == 5 | exit 0 + count 5 |
| AC-6 | shell | `[ -L plugins/spec-flow/agents/qa-spec.agent.md ] && readlink plugins/spec-flow/agents/qa-spec.agent.md | grep -q 'qa-spec.md' && grep -Eq '^17\. ' plugins/spec-flow/agents/qa-spec.md && grep -q '^rubric_version: 2' plugins/spec-flow/agents/qa-spec.md` | exit 0 |
| AC-7 | shell | `[ -L plugins/spec-flow/agents/qa-plan.agent.md ] && readlink plugins/spec-flow/agents/qa-plan.agent.md | grep -q 'qa-plan.md' && grep -Eq '^33\. ' plugins/spec-flow/agents/qa-plan.md && grep -q '^rubric_version: 2' plugins/spec-flow/agents/qa-plan.md` | exit 0 |
| AC-8 | shell | `a=$(jq -r .version plugins/spec-flow/plugin.json); b=$(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json); c=$(jq -r '.plugins[]\|select(.name=="spec-flow").version' .claude-plugin/marketplace.json); [ "$a" = 5.17.0 ] && [ "$b" = 5.17.0 ] && [ "$c" = 5.17.0 ] && grep -Fq '## [5.17.0]' plugins/spec-flow/CHANGELOG.md` | exit 0 — all three JSON surfaces 5.17.0, CHANGELOG section present |
| AC-9 | agent-step | Dispatch `qa-spec` (Full mode) on `tests/fixtures/outcome-acs/behaving-missing-result.md` | ≥1 #17 must-fix returned; spec NOT clean |
| AC-10 | agent-step | Dispatch `qa-spec` (Full mode) on `tests/fixtures/outcome-acs/legacy-no-piececlass.md` | zero #17 findings (legacy skip) |
| AC-11 | shell | `for f in templates/spec.md agents/qa-spec.md agents/qa-spec.agent.md agents/qa-plan.md agents/qa-plan.agent.md reference/brainstorm-procedure.md skills/spec/SKILL.md; do grep -Fq 'behavior-classification.md' plugins/spec-flow/$f || echo UNWIRED:$f; done` | no UNWIRED output |
| AC-12 | shell | Run `plugins/spec-flow/tests/e2e/lib/static.sh` via the e2e harness | static suite passes (symlink + drift + version assertions) |
| AC-13 | agent-step | Walk `behaving-missing-result.md` (→qa-spec) and `nonbehavioral-spec.md` + `nonbehavioral-tdd-plan.md` (→qa-plan) through the chain | missing-facet blocked at #17; mislabel blocked at #33; neither silently passes |
| AC-14 | agent-step | Dispatch `qa-spec` (Full mode) on `tests/fixtures/outcome-acs/behaving-liveness-only.md` | #17 liveness-heuristic must-fix returned (gate fires) |
| AC-15 | shell | Run the `ac_verifiability` count (SKILL.md line 328 procedure) on a fully-tagged fixture spec, with and without the AC-line tags | `machine`/`judgment` counts identical both runs and equal the `[machine:]`/`[judgment:]` sub-line count |

## Contracts

**No TDD-track phases.** This plan is Non-TDD mode (`tdd: false`); every phase uses `[Implement]` + `[Write-Tests]`. No boundary-crossing function / API endpoint / event schema / data schema interface is introduced — every deliverable is doc-as-code markdown, JSON, or YAML. This section intentionally carries no `C-N` interface entries.

## Parallel Execution Notes

All four phases run **serially** in order (1 → 2 → 3 → 4).

- **Phase 1 first (hard dependency):** it defines the canonical glossary tokens that Phases 2 and 3 must cite verbatim. Running anything before it risks tokens drifting from the SSOT.
- **Phases 2 and 3 — `Why serial` (qa-plan #11):** their file scopes are disjoint (Phase 2 = `agents/qa-spec.md` + `agents/qa-plan.md`; Phase 3 = `reference/brainstorm-procedure.md` + `skills/spec/SKILL.md` + `agents/deliberation-lens.md` + `agents/deliberation-convergence.md`), so they are nominally `[P]`-eligible. They are deliberately kept serial (ADR-5): the edits are small doc-as-code changes whose parallel-worktree-isolation + group-QA coordination overhead outweighs the marginal wall-clock gain, and Phase 4 gates the union of both regardless. No correctness dependency exists between them.
- **Phase 4 last (hard dependency):** the integration sweep (AC-11 seven-site grep, AC-12 static.sh, AC-13 e2e walk) can only pass once Phases 1–3 have landed every citation, both gates, and the elicitation wiring; the version bump is conventionally last so the CHANGELOG reflects the completed work.

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, this plan's `[Implement]` Change Specs (verbatim Current/Target/Pattern blocks), spec ACs, the plan's `[Verify]` commands, charter constraints per phase, `introspection.md` Dependency Map + Pattern Catalog for the phase scope | Spec rationale, brainstorming history |
| Verify | Verification output (grep/diff/readlink/`static.sh` results, agent-dispatch verdicts for judgment ACs), spec ACs | Implementation reasoning |
| Refactor | Current doc-as-code files (phase files only), the phase's Verify commands, quality principles | Prior agent conversations |
| QA (qa-phase) | Phase diff, spec, plan, mapped PRD sections (FR-018/SC-010/G-7) | Any agent conversation history |
