---
charter_snapshot:
  architecture: 2026-04-21
  non-negotiables: 2026-04-21
  tools: 2026-04-21
  processes: 2026-04-21
  flows: 2026-04-21
  coding-rules: 2026-04-21
---

# Plan: pi-010-discovery

**Spec:** docs/prds/shared/specs/pi-010-discovery/spec.md
**Charter:** docs/charter/ (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Implementation strategy for the v3.2.0 synchronous-discovery-triage piece. 13 phases comprising 11 flat phases + 2 Phase Groups, with 4 of the flat phases serial because they all edit `plugins/spec-flow/skills/execute/SKILL.md` (the same lesson from pi-009's Phase Group B execute/SKILL.md serialization).

**Track choice — all phases use Implement track.** Per `docs/charter/tools.md`, spec-flow has no test runner; verification is adversarial review + LLM-agent-step assertions against produced artifacts. TDD ceremony for markdown / YAML / agent-prose edits would add no payoff. Each phase's `[Verify]` step is an LLM-agent-step assertion or a smoke-test invocation per FR-13's framing (introduced by pi-009).

**Phase Groups:**
- **Phase Group A** (CAP-A skill edits, parallel) — `skills/spec/SKILL.md` and `skills/plan/SKILL.md` are different files; sub-phases run concurrently.
- **Phase Group B** (CAP-E reflection agents, parallel) — `agents/reflection-future-opportunities.md` and `agents/reflection-process-retro.md` are different files; sub-phases run concurrently.

**Serial chain on execute/SKILL.md** — Phases 7, 8, 9, 10 all edit `plugins/spec-flow/skills/execute/SKILL.md`. They are kept serial (`Why serial:` per phase) because concurrent edits to the same file race — directly inheriting pi-009's must-improve item ("Phase B.1 → B.4 collateral damage from shared structural anchor deletion"). Each phase scopes a distinct prose region (Step 4 / new Step 6c / new Step 8 / Step 4.5 respectively) but the file as a whole cannot be parallel-edited.

**Mid-piece Opus QA pass (FR-9 from pi-009).** This piece has 13 phases. ⌈13/2⌉ = 7, so a mid-piece Opus pass dispatches between Phase 7 and Phase 8 if the first 7 phases all auto-skipped Opus. In practice Phases 7–10 ship real control-flow logic in execute/SKILL.md prose that the sharpened skip predicate routes to Opus regardless. Whether the mid-piece pass actually fires depends on actual predicate outcomes — captured as a process-retro observation in `learnings.md`, not a planned dispatch.

**Plan-amend agent test surface.** The plan-amend / spec-amend agents are themselves new agents being added by this piece. Their own behavior is not exercised end-to-end by any phase of this piece (the piece does not re-enter execute on itself). Smoke testing of plan-amend / spec-amend happens via the dog-food invocation NN-P-003 prescribes — the operator running pi-011-or-later through the new flow. This piece's `[Verify]` steps for Phases 4, 5, 8, 9 confirm the *artifacts ship correctly* (frontmatter valid, prompt structure correct, prose anchors present); behavioral verification of the amendment loop is intentionally deferred to the next piece that runs through the new execute step.

**Coordination files (no Phase 0 Scaffold needed).** Multiple phases touch `plugins/spec-flow/skills/execute/SKILL.md` and `plugins/spec-flow/CHANGELOG.md`, but these are prose files where each phase scopes a distinct region — not a code-import graph or a test-discovery registry. Defensive scaffolding does not apply; serial ordering on execute/SKILL.md (Phases 7→10) and a single release ceremony at Phase 13 prevent contention.

**Phase numbering and amendment IDs.** The plan uses integer phase IDs (Phase 1, 2, 4–10, 12, 13) for flat phases, with Phase Group A occupying the implicit "Phase 3" slot and Phase Group B occupying the implicit "Phase 11" slot. Per FR-13 of pi-010-discovery's spec, amendment phases dispatched at execute time inherit the originating phase's numeric ID via the suffix `phase_<N>_amend_<K>`. For amendments originating from a Phase Group sub-phase (e.g., Sub-Phase A.1), the originating ID becomes the dotted form `phase_a1_amend_<K>` (lowercased letter — hyphen-omitted) per execute/SKILL.md's existing sub-phase state-key naming convention (`group_a_subphase_a1`). For Final Review amendments, the originating ID is the literal token `final` per FR-16a (`phase_final_amend_<K>`).

**Why no TDD track:** Per `docs/charter/tools.md` and `docs/charter/non-negotiables.md` NN-C-002 (no runtime deps), spec-flow has no Python/JS/Go test runner. All artifacts are markdown / YAML / agent prompts / SKILL prose. Test-driving prose has no payoff — there's no code under test that fails. Validation runs as LLM-agent-step assertions in [Verify] blocks (per pi-009 ORC-6 / FR-13 default).

## Phases

Each phase uses exactly ONE of two tracks:

- **TDD track** — phase contains `[TDD-Red]`. Use for behavior-bearing code that benefits from test-driven design.
- **Implement track** — phase contains `[Implement]` (and NO `[TDD-Red]`). Use for config, infrastructure, scaffolding, glue/wiring code, docs-as-code, fixtures, and migrations.

This piece uses **Implement track exclusively** — see Overview "Why no TDD track" rationale.

---

### Phase 1: defer skill (CAP-F)
**Exit Gate:** `plugins/spec-flow/skills/defer/SKILL.md` exists with frontmatter, environment preconditions section, and the structured + manual invocation contracts; `[Verify]` LLM-agent-step assertions all pass; `[QA]` Opus deep review returns must-fix=None (iter-until-clean per `plugins/spec-flow/reference/qa-iteration-loop.md`).
**ACs Covered:** AC-1, AC-2, AC-3, AC-4
**Charter constraints honored in this phase:**
- **NN-C-002 (no runtime deps):** the new SKILL.md is markdown only — no `package.json`, no `requirements.txt`, no compiled binary. The skill operates on local backlog files via the LLM agent's native file-edit capability.
- **NN-C-005 (hooks/skills silent on missing optionals):** the skill returns "no active piece detected — pass --source-piece explicitly or invoke from within a piece worktree" rather than failing when invoked outside a worktree without `--source-piece`.
- **NFR-004 (documentation as source of truth):** the new SKILL.md ships with a `## Environment preconditions` section listing the LLM-runtime + git + POSIX shell expectations, explicitly stating no external-tool runtime dependencies.
- **CR-002 (skill frontmatter schema):** SKILL.md ships with `name: defer` matching its directory and `description:` written in third-person ("Use when...") with concrete trigger phrases.

- [x] **[Implement]** Author the new defer skill at `plugins/spec-flow/skills/defer/SKILL.md`.
  - Order:
    1. Create directory `plugins/spec-flow/skills/defer/`.
    2. Author `SKILL.md` with this frontmatter:
       ```yaml
       ---
       name: defer
       description: Use when an operator (or the orchestrator's discovery-triage flow) needs to record a non-blocking finding to a backlog file with provenance. Sole supported path for writing to <docs_root>/prds/<prd-slug>/backlog.md or <docs_root>/improvement-backlog.md. Invoked structured (from execute/SKILL.md Step 6c after operator chooses defer) or manually (/spec-flow:defer "<finding>" --rationale "<text>"). Refuses if --rationale is missing.
       ---
       ```
    3. Add `## Step 0: Load Config` preamble matching other skills' shape — read `.spec-flow.yaml` for `docs_root`/`worktrees_root`; defaults `docs`/`worktrees`.
    4. Add `## Environment preconditions` section listing: LLM-driven execution context with file-reading + inline parsing, `git` ≥ 2.5 (for the resulting commit), POSIX shell. Explicit prose: "These capabilities live in the LLM agent's runtime, not in the user's installed plugin."
    5. Add `## Argument parsing` section documenting the two invocation forms:
       - **Manual:** `/spec-flow:defer "<finding>" --rationale "<text>" [--global] [--source-piece <slug>] [--source-phase <id>]`. When `--source-piece` is omitted, the skill resolves the active piece via `git worktree list` + reverse-lookup against `docs/prds/*/manifest.yaml` (find the manifest entry whose `<piece-slug>` matches the worktree's `piece-<piece-slug>` directory name).
       - **Structured (orchestrator-driven):** the orchestrator passes a single context block with named fields `source_piece`, `source_phase`, `source_agent`, `finding_text`, `operator_rationale`, optional `target=global`. The skill skips operator-prompt code paths entirely when invoked structured.
    6. Add `## Refusal contract` section with the exact `REFUSED — defer requires --rationale; explain why this finding does not block the current piece's goals.` message for missing rationale, and `Refused — no active piece detected; pass --source-piece explicitly or invoke from within a piece worktree.` for unresolved active piece.
    7. Add `## Backlog target resolution` section documenting:
       - `--global` flag → write to `<docs_root>/improvement-backlog.md`
       - default → write to `<docs_root>/prds/<prd-slug>/backlog.md` of the active piece
       - the entry's `**Source:**` line ALWAYS uses the qualified `<prd-slug>/<piece-slug>` form regardless of target
    8. Add `## Entry format` section with the exact template per FR-2:
       ```markdown
       ### [Deferred via /spec-flow:defer] <finding-summary> — YYYY-MM-DD

       **Source:** `<prd-slug>/<piece-slug>` phase `<phase-id>` (agent: `<agent-name>`)
       **Finding (verbatim):** <finding-text>
       **Why this does not block <piece-slug>'s goals:** <operator-rationale>
       **Captured:** YYYY-MM-DD
       ```
       The skill places the entry under the target file's `## Recent findings` H2 section, creating that section if it doesn't exist.
    9. Add `## Workflow` section with steps:
       - Step 1: parse arguments / context block
       - Step 2: refuse if rationale missing (FR-2 refusal contract)
       - Step 3: resolve target backlog file path
       - Step 4: format entry per template
       - Step 5: append entry under `## Recent findings` (create section if absent — at end of file)
       - Step 6: commit on the active worktree branch with message `chore(<piece-slug>): defer <finding-summary>` (CR-004 chore type)
       - Step 7: report success with the path of the file modified and the commit SHA
    10. Add `## Operator confirmation step (manual invocation only)` section: when invoked manually (not structured), the skill reads the formatted entry back to the operator and asks `Append this entry to <target-path> and commit? (y/n)` before performing the write. Structured invocations skip this step (operator already chose defer in the upstream triage flow).
  - Files: `plugins/spec-flow/skills/defer/SKILL.md`
  - Pattern pointers:
    - `plugins/spec-flow/skills/migrate/SKILL.md` `## Environment preconditions` section as the canonical shape (per pi-009 CAP-4).
    - `plugins/spec-flow/skills/charter/SKILL.md` `## Step 0` config-load preamble as the boilerplate.
    - `plugins/spec-flow/skills/execute/SKILL.md` Step 6a's existing append-to-backlog prose as the "what gets written" reference (which Phase 9 will rewrite to invoke /spec-flow:defer instead of inline-appending).
  - Architecture constraints: NN-C-002 (markdown only), NN-C-005 (graceful refusal), NFR-004 (env preconditions documented), CR-002 (frontmatter), CR-008 (skill orchestrates only — does not dispatch other agents).

- [x] **[Verify]** Confirm AC-1, AC-2, AC-3, AC-4 hold structurally.
  - Run check 1: confirm `plugins/spec-flow/skills/defer/SKILL.md` exists.
  - Run check 2: LLM-agent reads SKILL.md and confirms presence of: frontmatter with `name: defer` (CR-002), `## Environment preconditions` section (NFR-7 / NFR-004), `## Argument parsing` documenting both invocation forms (FR-1), `## Refusal contract` with the exact REFUSED string (AC-2), `## Entry format` with all six required fields (FR-2 / AC-1), `## Backlog target resolution` documenting `--global` flag (AC-3), and structured-invocation skip-prompt language (AC-4).
  - Run check 3: LLM-agent confirms the entry-format template's date placeholders resolve via `date +%F` at write time.
  - Expected: all three checks pass.

- [x] **[QA]** Phase review.
  - Review against: AC-1, AC-2, AC-3, AC-4.
  - Diff baseline: `git diff <phase_1_start_tag>..HEAD`.

---

### Phase 2: depends_on precondition reference doc (CAP-A shared)
Why serial: Phase 1 (defer skill) and this phase touch disjoint files and could parallelize, but the operator's authoring preference is to land defer first so it can be exercised manually before depends-on-precondition lands. Sequential ordering is a deliberate authoring choice, not a file-conflict requirement.

**Exit Gate:** `plugins/spec-flow/reference/depends-on-precondition.md` exists with the complete enumeration + resolution + triage-prompt rules, factored from execute/SKILL.md Phase 1c; `[Verify]` LLM-agent-step assertions all pass; `[QA]` returns must-fix=None.
**ACs Covered:** (none directly — supports AC-5, AC-6, AC-7, AC-8, AC-9 by factoring shared prose for Phase Group A consumption)
**Charter constraints honored in this phase:** (none specific — pure refactor of existing execute/SKILL.md Phase 1c prose into a reusable reference doc; the structural CR entries — CR-005 repo-relative paths, CR-009 heading hierarchy — are honored implicitly by adopting the same conventions used by sibling reference docs but are allocated to phases authoring novel content. CR-005's canonical owner for this piece is Phase 12 — README.md updates — since that phase introduces the most new path citations.)

- [x] **[Implement]** Factor the depends_on precondition logic out of execute/SKILL.md Phase 1c into a shared reference.
  - Order:
    1. Read `plugins/spec-flow/skills/execute/SKILL.md` Phase 1c (lines covering "depends_on: precondition (FR-011, AC-11)" through end of section).
    2. Create `plugins/spec-flow/reference/depends-on-precondition.md` with sections:
       - **Purpose** — briefly state the doc factors the depends_on precondition rules so spec/plan/execute can all cite it.
       - **Reference resolution** — the qualified `<prd-slug>/<piece-slug>` and bare `<piece-slug>` rules already in execute/SKILL.md Phase 1c; verbatim copy.
       - **Status interpretation** — the `merged`/`done` (passes), `open`/`specced`/`planned`/`in-progress` (transient — bypassable via `--ignore-deps`), `superseded`/`blocked` (structural failure — never bypassable) classifications already in Phase 1c.
       - **Refusal contracts** — the exact strings already in Phase 1c (malformed, unknown PRD, unknown piece, self-reference, unmet, structural-failure).
       - **Triage options at spec/plan time** — the three options NEW to this piece (pull-deps-in / fork / proceed --ignore-deps), with the exact operator prompt text:
         ```
         Piece <piece-slug> has unmet depends_on:
           - <ref> (status: <status>)
         Choose:
           (1) pull-deps-in  — add Phase 0 entries to this piece that re-implement / verify the prerequisite
           (2) fork          — block this piece; spec the prerequisite first
           (3) proceed       — operator override (equivalent to --ignore-deps); deps remain unmet
         ```
       - **Recording the choice** — the `## Dependency Triage` section format that spec/plan must write into spec.md / plan.md per FR-6 of pi-010-discovery's spec.
    3. The reference doc cross-links to `plugins/spec-flow/reference/v3-path-conventions.md` (for slug rules) and `plugins/spec-flow/skills/execute/SKILL.md` Phase 1c (for the execute-time enforcement that already exists).
    4. Do NOT modify execute/SKILL.md Phase 1c in this phase — Phase 7 onward edits execute/SKILL.md; Phase 2's reference doc is read-only-from-execute's perspective until Phase 7 cross-links into it.
  - Files: `plugins/spec-flow/reference/depends-on-precondition.md` (new).
  - Pattern pointers:
    - `plugins/spec-flow/reference/charter-drift-check.md` for shape (procedure + refusal contracts in one doc).
    - `plugins/spec-flow/reference/qa-iteration-loop.md` for shape (concise reference factored out of multiple skills).
    - `plugins/spec-flow/skills/execute/SKILL.md` Phase 1c lines for verbatim refusal-contract strings.
  - Architecture constraints: CR-005 (repo-relative paths), CR-009 (markdown semantic hierarchy).

- [x] **[Verify]** Confirm the reference doc is well-formed and consumable.
  - Run check 1: confirm `plugins/spec-flow/reference/depends-on-precondition.md` exists.
  - Run check 2: LLM-agent reads the new reference and confirms it includes the three triage options' prompt text, the existing-Phase-1c refusal contracts, and the `## Dependency Triage` format.
  - Run check 3: LLM-agent confirms the doc is internally consistent (no contradictions vs execute/SKILL.md Phase 1c — both still describe the same status classifications).
  - Expected: all three checks pass.

- [x] **[QA]** Phase review.
  - Review against: factoring fidelity (no semantic drift from existing Phase 1c).
  - Diff baseline: `git diff <phase_2_start_tag>..HEAD`.
  - **Skip note:** auto-skipped per FR-8 sharpened skip predicate (additive markdown only — new reference doc, no shell control flow, no new skill body, no behavioral change). Implementer's [Verify] checks already confirmed factoring fidelity vs Phase 1c.

---

## Phase Group A: spec/plan dependency precondition (CAP-A.2 / CAP-A.3, parallel)
**Exit Gate:** both sub-phases pass `[Verify]` + group-level `[QA]` Opus deep review returns must-fix=None.
**ACs Covered:** AC-5, AC-6, AC-7, AC-8, AC-9

#### Sub-Phase A.1 [P]: spec/SKILL.md depends_on precondition
**Scope:** plugins/spec-flow/skills/spec/SKILL.md
**ACs:** AC-5, AC-6, AC-7, AC-8 (spec-time triage flow)
**Charter constraints honored in this sub-phase:** (none specific — see group-level allocation in Phase 7's NN-C entries; this sub-phase implements the spec-time variant of the same flow.)

- [x] **[Implement]** Insert the depends_on precondition step into spec/SKILL.md Phase 1.
  - Order:
    1. Read `plugins/spec-flow/skills/spec/SKILL.md` Phase 1 (steps 1–7).
    2. Insert a new step between current step 6 (read PRD-local backlog) and step 7 (charter-drift check):
       - Title: **6a. Dependency precondition check (FR-4 of pi-010-discovery, AC-5)**
       - Body: cites `plugins/spec-flow/reference/depends-on-precondition.md`. Reads the target piece's `depends_on:` from `docs/prds/<prd-slug>/manifest.yaml`. Resolves each ref per the reference doc. On any unmet dep (status not `merged`/`done`), surface the three-option triage prompt verbatim from the reference doc. Record the operator's choice in orchestrator state for Phase 3 (write to spec.md).
    3. Update Phase 3's spec.md authoring step (currently step 4) to read the recorded choice and emit a `## Dependency Triage` section per FR-6 of pi-010-discovery's spec when any unmet dep was triaged. Specifically:
       - On `pull-deps-in`: spec.md gains `## Dependency Triage` listing each unmet dep with its status and the resolution "Phase 0 will re-implement / verify."
       - On `fork`: skill halts with the refusal `Refused — fork chosen; spec the prerequisite piece <ref> first.` and writes no spec.md, no commits.
       - On `proceed --ignore-deps`: spec.md `## Dependency Triage` records "Operator override; deps remain unmet at spec time."
       - When all deps were already `merged`/`done` at the time of Phase 1 step 6a, no `## Dependency Triage` section is written.
    4. Add a one-line note at the top of Phase 1 stating the new step exists and references the reference doc.
  - Files: `plugins/spec-flow/skills/spec/SKILL.md`
  - Pattern pointers:
    - `plugins/spec-flow/skills/execute/SKILL.md` Phase 1c for the same precondition shape (which this skill mirrors at spec-time).
    - `plugins/spec-flow/reference/depends-on-precondition.md` (Phase 2 output) for the refusal contracts.
  - Architecture constraints: NN-C-005 (silent no-op when no unmet deps — the new step exits cleanly with no prompts).

- [x] **[Verify]** Confirm AC-5, AC-6, AC-7, AC-8 hold structurally.
  - Run check 1: LLM-agent reads spec/SKILL.md and confirms Phase 1 step 6a exists between step 6 and step 7, citing depends-on-precondition.md.
  - Run check 2: LLM-agent confirms Phase 3's spec.md authoring step describes the three branches (pull-deps-in / fork / proceed) and the corresponding spec.md content.
  - Run check 3: LLM-agent confirms the fork refusal string matches AC-7 verbatim.
  - Expected: all three checks pass.

- [x] **[QA-lite]** Sonnet narrow review.
  - Scope: spec/SKILL.md changes only.
  - Review: AC-5–AC-8 binding, no inadvertent edits to other Phase 1 steps, factoring fidelity vs depends-on-precondition.md.

#### Sub-Phase A.2 [P]: plan/SKILL.md depends_on precondition
**Scope:** plugins/spec-flow/skills/plan/SKILL.md
**ACs:** AC-9 (plan-time triage flow)
**Charter constraints honored in this sub-phase:** (none specific — mirrors A.1's spec-time variant.)

- [x] **[Implement]** Insert the depends_on precondition step into plan/SKILL.md Phase 1.
  - Order:
    1. Read `plugins/spec-flow/skills/plan/SKILL.md` Phase 1 (charter-drift check + read-only exploration).
    2. Insert a new step at the start of Phase 1, BEFORE the charter-drift check:
       - Title: **1a. Dependency precondition check (FR-5 of pi-010-discovery, AC-9)**
       - Body: cites `plugins/spec-flow/reference/depends-on-precondition.md`. Reads the target piece's `depends_on:` from `docs/prds/<prd-slug>/manifest.yaml`. Surfaces the three-option triage prompt on any unmet dep. Records operator's choice for Phase 2 (plan generation).
    3. Update Phase 2's plan.md generation step to emit a `## Dependency Triage` section in plan.md when unmet deps were triaged at plan time, mirroring spec.md's shape from Sub-Phase A.1.
    4. The plan-time triage may produce a different choice than spec-time triage (e.g., spec was authored with `proceed --ignore-deps`, but at plan time the operator now wants to `pull-deps-in`). plan.md's `## Dependency Triage` section records the plan-time choice independently of any spec-time choice.
  - Files: `plugins/spec-flow/skills/plan/SKILL.md`
  - Pattern pointers:
    - `plugins/spec-flow/skills/execute/SKILL.md` Phase 1c for refusal contracts.
    - `plugins/spec-flow/reference/depends-on-precondition.md` for the prompt text.
  - Architecture constraints: NN-C-005 (silent no-op when no unmet deps).

- [x] **[Verify]** Confirm AC-9 holds structurally.
  - Run check 1: LLM-agent reads plan/SKILL.md and confirms Phase 1 step 1a exists at the top of Phase 1, citing depends-on-precondition.md.
  - Run check 2: LLM-agent confirms Phase 2's plan.md generation step describes the `## Dependency Triage` section with all three branches.
  - Expected: both checks pass.

- [x] **[QA-lite]** Sonnet narrow review.
  - Scope: plan/SKILL.md changes only.
  - Review: AC-9 binding, no inadvertent edits to other Phase 1 / Phase 2 steps.

#### Group-level
- [x] **[Refactor]** scope: union of sub-phase files (auto-skip if all Builds clean).
- [x] **[QA]** Opus deep review, diff baseline: group_start_sha. ACs: AC-5, AC-6, AC-7, AC-8, AC-9. Confirm sub-phases' precondition prose stays consistent and both cite the same reference doc.

---

### Phase 4: plan-amend agent (CAP-D prerequisite)
**Exit Gate:** `plugins/spec-flow/agents/plan-amend.md` exists with frontmatter, environment preconditions, input contract, output contract (## Diff of changes); `[Verify]` confirms structure; `[QA]` returns must-fix=None.
**ACs Covered:** (supports AC-15 — but behavioral verification deferred to dog-food per Overview)
**Charter constraints honored in this phase:**
- **NN-C-004 (agent frontmatter `name:` is bare):** plan-amend.md frontmatter has `name: plan-amend` (NOT `spec-flow:plan-amend`).
- **CR-001 (agent frontmatter schema):** plan-amend.md frontmatter has `name:`, `description:` (one-line trigger + dispatch contract), `model: sonnet`. No `tools:` restriction.

- [x] **[Implement]** Author the plan-amend agent.
  - Order:
    1. Create `plugins/spec-flow/agents/plan-amend.md` with frontmatter:
       ```yaml
       ---
       name: plan-amend
       description: "Internal agent — dispatched by spec-flow:execute Step 6c when an operator chooses to amend the plan in response to a discovery. Do NOT call directly. Reads the current plan.md, a structured discovery report, and the diff+neighborhood scope; emits a unified diff that inserts suffix-named amendment phases (phase_<N>_amend_<K>) before the next original phase. Does NOT commit — outputs `## Diff of changes` containing the unified diff that the orchestrator stages and commits."
       model: sonnet
       ---
       ```
    2. Add `# Plan Amendment Agent` H1.
    3. Add an introductory paragraph stating the agent's job: "Read the current plan, a structured discovery report describing what was found and why it blocks the piece's goals, and the diff+neighborhood scope. Emit a unified diff against plan.md that inserts new phases to address the discovery. The orchestrator commits and resumes execute from the first amendment phase."
    4. Add `## Environment preconditions` section: LLM-runtime with file-reading + diff-emission capability. No external runtime dependencies. (Mirror Phase 1's preconditions section.)
    5. Add `## Context Provided` section listing:
       - Current plan.md (full body)
       - Structured discovery report with fields: `Type:` (one of `requires-amendment`, `requires-fork`, `does-not-block-goal`, `qa-finding-out-of-scope`), `Source:` (phase id + agent name), `Why this blocks:` (text), `Proposed amendment scope:` (list of phases to add or modify), `Estimated absorption size:` (LOC count)
       - Diff+neighborhood scope: a list of phases (with their `[Implement]` / `[Build]` blocks) whose file scopes overlap with the proposed amendment. The orchestrator computes neighborhood by exact file path per FR-11.
    6. Add `## Output Contract` section:
       - The agent emits a unified diff in standard `git diff` format (with `--- a/<path>` and `+++ b/<path>` headers, hunk headers `@@ ... @@`, and standard context lines).
       - Amendment phases use suffix-form IDs `phase_<N>_amend_<K>` per FR-13 of pi-010-discovery's spec.
       - The diff must be committable via `git apply --check` then `git apply` against the worktree.
       - On `## Diff of changes (none)`, the agent declares the discovery does not require a plan change; the orchestrator routes the discovery as a Build re-dispatch instead.
       - The diff inserts amendment phases BEFORE the next original phase numerically (e.g., amending phase_3 inserts phase_3_amend_1 before phase_4).
    7. Add `## Rules` section:
       - 1. Fix ONLY what the discovery report identifies. Do not modify unrelated phases.
       - 2. Preserve plan.md heading hierarchy (CR-009): `### Phase N:` at H3, `#### Sub-Phase` at H4, `**Exit Gate:**` line, `**ACs Covered:**` line, `**Charter constraints honored in this phase:**` block.
       - 3. The amendment phase MUST itself follow track-pick rules — exactly one of `[TDD-Red]` or `[Implement]`, with all the standard checkboxes ([Verify], [QA], etc.).
       - 4. The amendment phase's `**Charter constraints honored**` slot MUST cite at least the NN-C/NN-P/CR entries the discovery report's `Why this blocks:` field references (so the amendment isn't NN/CR-orphaned).
       - 5. Do NOT commit. End report with `## Diff of changes` containing the unified diff or `(none)`.
       - 6. Do NOT recursively design follow-up amendments — exactly one amendment cycle per dispatch.
    8. Add `## Output Format` section (the agent's report shape):
       ```markdown
       ## Discovery analysis
       <brief paragraph on what the discovery means for plan structure>

       ## Proposed amendment phases
       <list of amendment phase IDs and their purposes>

       ## Diff of changes
       <unified diff against plan.md>
       ```
  - Files: `plugins/spec-flow/agents/plan-amend.md` (new).
  - Pattern pointers:
    - `plugins/spec-flow/agents/fix-doc.md` for the agent contract pattern (does not commit; ends with `## Diff of changes`).
    - `plugins/spec-flow/agents/qa-spec.md` for the structured input-mode pattern (Context Provided section, Rules section).
  - Architecture constraints: NN-C-004 (bare name), CR-001 (frontmatter schema), CR-008 (narrow agent — only emits diff; does not dispatch other agents).

- [x] **[Verify]** Confirm the agent file is well-formed.
  - Run check 1: confirm `plugins/spec-flow/agents/plan-amend.md` exists.
  - Run check 2: LLM-agent reads the file and confirms frontmatter has `name: plan-amend` (NN-C-004), `description:`, `model: sonnet` (CR-001).
  - Run check 3: LLM-agent confirms presence of `## Environment preconditions`, `## Context Provided`, `## Output Contract`, `## Rules`, and `## Output Format` sections.
  - Run check 4: LLM-agent confirms the Output Contract section explicitly describes (a) `--- a/` `+++ b/` headers, (b) `phase_<N>_amend_<K>` suffix form, (c) `## Diff of changes (none)` empty-diff signal.
  - Expected: all four checks pass.

- [x] **[QA]** Phase review.
  - Review against: AC-15's structural shape (commit subject `chore(plan): amend — <reason>` happens orchestrator-side in Phase 8; this phase only authors the agent's contract).
  - Diff baseline: `git diff <phase_4_start_tag>..HEAD`.

---

### Phase 5: spec-amend agent (CAP-D prerequisite)
Why serial: spec-amend mirrors plan-amend's contract structure. Authoring spec-amend after plan-amend lets the implementer use Phase 4's just-committed agent file as the canonical pattern pointer (mentioned in this phase's Pattern pointers as `plugins/spec-flow/agents/plan-amend.md`). Disjoint file scopes — could parallelize — but parallel authoring would risk schema drift between the two agents that this piece intentionally keeps symmetric.

**Exit Gate:** `plugins/spec-flow/agents/spec-amend.md` exists with the same shape as plan-amend, but its qa-loop reference is qa-spec; `[Verify]` confirms structure.
**ACs Covered:** (supports AC-21b, AC-21c — behavioral verification deferred to dog-food per Overview)
**Charter constraints honored in this phase:**
- **NN-C-008 (agent prompts self-contained):** the spec-amend agent prompt explicitly describes its inputs (the spec, the discovery report, the affected sections) — no reliance on conversation history, no implicit context.
- **CR-008 (thin orchestrator / narrow agent):** the spec-amend agent's only task is "read spec + discovery → emit unified diff." It does not dispatch other agents. The orchestrator handles qa-spec re-dispatch and commit ceremony.

- [x] **[Implement]** Author the spec-amend agent.
  - Order:
    1. Create `plugins/spec-flow/agents/spec-amend.md` with frontmatter:
       ```yaml
       ---
       name: spec-amend
       description: "Internal agent — dispatched by spec-flow:execute Step 6c when a discovery implies the SPEC was wrong (not just the plan). Do NOT call directly. Reads the current spec.md, a structured discovery report, and the affected sections; emits a unified diff against spec.md adding FRs / ACs / NFRs / honored entries within the piece's stated goals. Does NOT commit — outputs `## Diff of changes` that the orchestrator stages and commits."
       model: sonnet
       ---
       ```
    2. Add `# Spec Amendment Agent` H1.
    3. Add introductory paragraph stating the agent's job: amends spec.md when a discovery shows the spec was missing FRs/ACs/NFRs or stated something that contradicts what was actually built. Bounded to additions and clarifications within the piece's existing goals — never introduces or removes a Goal-section entry.
    4. Add `## Environment preconditions` section (mirror Phase 4).
    5. Add `## Context Provided` section listing:
       - Current spec.md (full body)
       - Structured discovery report (same fields as plan-amend's contract)
       - Affected sections of the spec the discovery references (e.g., specific FR numbers, AC numbers, NFR numbers)
    6. Add `## Output Contract` section:
       - Standard unified diff format against spec.md.
       - Diff scope is bounded to: adding new FRs / ACs / NFRs / honored entries / AC matrix rows; clarifying existing FR/AC bodies; updating Out of Scope items.
       - PROHIBITED: changing the Goal section, removing FRs/ACs, changing the In Scope / Out of Scope boundary in ways that change what the piece delivers.
       - On detection that the discovery requires Goal-section changes, the agent emits `## Diff of changes (none)` and a note in `## Discovery analysis` stating "Discovery requires Goal-level scope change — escalating per FR-12a." The orchestrator surfaces the escalation.
    7. Add `## Rules` section (mirror Phase 4 with spec-specific tweaks):
       - 1. Fix ONLY what the discovery identifies.
       - 2. Preserve spec.md heading hierarchy (CR-009).
       - 3. New ACs MUST be testable with an `Independent test:` line.
       - 4. New FRs MUST cross-reference the AC(s) they address.
       - 5. Do NOT commit. End with `## Diff of changes`.
    8. Add `## Output Format` section (mirror Phase 4 with sections renamed for spec context):
       ```markdown
       ## Discovery analysis
       <how the discovery surfaces a spec-level gap>

       ## Proposed spec amendments
       <list of FR/AC/NFR additions or clarifications>

       ## Diff of changes
       <unified diff against spec.md>
       ```
  - Files: `plugins/spec-flow/agents/spec-amend.md` (new).
  - Pattern pointers: `plugins/spec-flow/agents/plan-amend.md` (Phase 4 output) for the agent contract shape.
  - Architecture constraints: NN-C-008 (self-contained), CR-008 (narrow agent).

- [x] **[Verify]** Confirm the agent file is well-formed.
  - Run check 1: confirm `plugins/spec-flow/agents/spec-amend.md` exists.
  - Run check 2: LLM-agent reads the file and confirms frontmatter has `name: spec-amend`, `description:`, `model: sonnet`.
  - Run check 3: LLM-agent confirms the Goal-section-change prohibition is explicit in `## Output Contract` (per FR-12a).
  - Expected: all three checks pass.

- [x] **[QA]** Phase review.
  - Review against: AC-21b structural shape, AC-21c budget refusal (orchestrator-side Phase 9; this phase is the agent's contract only).
  - Diff baseline: `git diff <phase_5_start_tag>..HEAD`.

---

### Phase 6: ac-matrix-contract.md + plan template flag (CAP-B prerequisites)
**Exit Gate:** `plugins/spec-flow/reference/ac-matrix-contract.md` exists with the v3.2.0 schema including the `Reason:` field; `plugins/spec-flow/templates/plan.md` gains the `legacy_deferred_rows: false` front-matter key with deprecation comment; `[Verify]` confirms both edits.
**ACs Covered:** (prerequisite for AC-10, AC-11, AC-12, AC-13, AC-13a — Phase 7 wires the contract into execute/SKILL.md)
**Charter constraints honored in this phase:** (none specific — pure contract authoring; existing CR-009 markdown hierarchy applies inherently.)

- [x] **[Implement]** Author the AC matrix contract reference doc + update the plan template.
  - Order:
    1. Create `plugins/spec-flow/reference/ac-matrix-contract.md` (currently referenced by execute/SKILL.md Step 4 but doesn't exist). Sections:
       - **Purpose** — defines the AC Coverage Matrix shape that Build reports emit and the verify gate validates.
       - **Schema** — markdown table with columns: `AC ID`, `Status` (one of `covered`, `NOT COVERED`, `NOT COVERED — deferred to <pointer>`), `Pointer` (file/line for `covered`; phase/AC for deferral), `Reason` (REQUIRED only when Status starts with `NOT COVERED — deferred`; one of `does-not-block-goal`, `requires-amendment`, `requires-fork`).
       - **Validation rules** — verify rejects: (a) missing matrix; (b) any in-scope AC missing a row; (c) bare `NOT COVERED` (no pointer); (d) vague `covered` pointer (lacking file/line); (e) `NOT COVERED — deferred to ...` row missing `Reason:` field UNLESS plan.md sets `legacy_deferred_rows: true` in front-matter.
       - **Reason interpretation** —
         - `does-not-block-goal`: phase pauses for inline operator confirmation (FR-8 of pi-010-discovery); on `y`, accepted; on `n`, Build re-dispatched.
         - `requires-amendment`: routes to Step 6c discovery triage with `amend` as default.
         - `requires-fork`: routes to Step 6c fork flow.
       - **Legacy mode (`legacy_deferred_rows: true`)** — when the plan's front-matter sets this flag, validate as in v3.1.x (silent acceptance of bare deferral rows). Triage routing for `requires-amendment` / `requires-fork` rows STILL fires (the legacy flag silences the format check only, NOT the routing).
       - **Refusal contracts** — exact strings the verify agent emits: `REFUSED — deferred row missing Reason; specify does-not-block-goal | requires-amendment | requires-fork.` (FR-7 of pi-010-discovery).
    2. Update `plugins/spec-flow/templates/plan.md`'s front-matter to add the new key:
       ```yaml
       ---
       charter_snapshot:
         architecture: {{date}}
         non-negotiables: {{date}}
         tools: {{date}}
         processes: {{date}}
         flows: {{date}}
         coding-rules: {{date}}
       legacy_deferred_rows: false  # OPT-IN: set to true to preserve pre-3.2.0 AC matrix behavior (silent acceptance of bare deferral rows). Deprecated — to be retired in v3.3.0.
       ---
       ```
  - Files:
    - `plugins/spec-flow/reference/ac-matrix-contract.md` (new)
    - `plugins/spec-flow/templates/plan.md` (front-matter modification only)
  - Pattern pointers:
    - `plugins/spec-flow/reference/qa-iteration-loop.md` for shape (concise reference doc).
    - `plugins/spec-flow/skills/execute/SKILL.md` Step 4 (existing prose) for the validation rules already in force.
  - Architecture constraints: CR-009 (heading hierarchy).

- [x] **[Verify]** Confirm the contract doc and template flag are in place.
  - Run check 1: confirm `plugins/spec-flow/reference/ac-matrix-contract.md` exists.
  - Run check 2: LLM-agent reads the contract doc and confirms presence of the Schema section listing all 4 columns + the Validation rules section + the Reason interpretation section + Refusal contracts.
  - Run check 3: confirm `plugins/spec-flow/templates/plan.md`'s front-matter includes the `legacy_deferred_rows: false` key with the deprecation comment.
  - Expected: all three checks pass.

- [x] **[QA]** Phase review.
  - Review against: schema completeness, refusal-contract verbatim match to FR-7 / AC-10.
  - Diff baseline: `git diff <phase_6_start_tag>..HEAD`.

---

### Phase 7: execute/SKILL.md Step 4 — AC matrix Reason enforcement (CAP-B)
Why serial: Phases 7, 8, 9, 10 all edit `plugins/spec-flow/skills/execute/SKILL.md`. Concurrent edits would race per pi-009's must-improve item ("Phase B.1 → B.4 collateral damage from shared structural anchor deletion"). Each phase scopes a distinct prose region (Step 4 / new Step 6c / new Step 8 / Step 4.5 respectively), but the file as a whole cannot be parallel-edited.

**Exit Gate:** execute/SKILL.md Step 4 cites ac-matrix-contract.md and enforces the new Reason-field rules; `[Verify]` confirms the cite + the refusal string match.
**ACs Covered:** AC-10, AC-11, AC-12, AC-13 (CAP-B at the verify gate; AC-13's `legacy_deferred_rows: true` acceptance behavior is implemented in [Implement] step 5 of this phase)
**Charter constraints honored in this phase:** (none specific — extends an existing gate; CR-005 repo-relative paths applies inherently.)

- [x] **[Implement]** Wire the new Reason-field enforcement into execute/SKILL.md Step 4.
  - Order:
    1. Read execute/SKILL.md Step 4 (currently titled "AC Coverage Matrix validation gate").
    2. Replace the Step 4 prose's reference to `references/ac-matrix-contract.md` with the correct repo-relative path `plugins/spec-flow/reference/ac-matrix-contract.md` (the existing prose has a stale path — fix it).
    3. Update the Step 4 validation rules to reference Phase 6's contract directly instead of paraphrasing — the SKILL.md prose says "See `plugins/spec-flow/reference/ac-matrix-contract.md` for the schema and parsing rules. The orchestrator enforces every rule documented there, including the v3.2.0 `Reason:` field for deferred rows."
    4. Add explicit handling for the three Reason values:
       - On `Reason: does-not-block-goal`: the orchestrator pauses Step 4 with the prompt `Phase claims AC <id> can defer without blocking <piece>'s goals — confirm? (y/n)`. On `y`, the row is accepted and the phase proceeds; on `n`, Build is re-dispatched per the existing 2-attempt budget.
       - On `Reason: requires-amendment`: the orchestrator records the row for routing to Step 6c with `amend` as the default option (Step 6c implementation lands in Phase 8).
       - On `Reason: requires-fork`: the orchestrator records the row for routing to Step 6c with `fork` as the default (Phase 8).
    5. Add a paragraph noting that when the plan's front-matter sets `legacy_deferred_rows: true`, the Reason-field requirement is silenced but `requires-amendment` / `requires-fork` rows still route through Step 6c per ac-matrix-contract.md "Legacy mode" section.
    6. Persist the routed rows in orchestrator state under a new key `phase_<id>_routed_discoveries` for Phase 8's Step 6c to consume.
  - Files: `plugins/spec-flow/skills/execute/SKILL.md` (Step 4 region only — no edits to other steps).
  - Pattern pointers:
    - `plugins/spec-flow/reference/ac-matrix-contract.md` (Phase 6 output) for the contract that Step 4 enforces.
    - `plugins/spec-flow/skills/execute/SKILL.md` Step 4's existing `phase_<id>_ac_matrix` state-key pattern (the new `phase_<id>_routed_discoveries` follows the same naming).
  - Architecture constraints: CR-004 (orchestrator stays orchestrator-side per CR-008 — the validation logic lives in the SKILL.md prose, not in a sub-agent dispatch).
  - **Phase-sizing note:** under 150 lines of behavioral prose; no override needed.

- [x] **[Verify]** Confirm Step 4 enforces the new contract.
  - Run check 1: LLM-agent reads execute/SKILL.md Step 4 and confirms it cites the corrected path `plugins/spec-flow/reference/ac-matrix-contract.md`.
  - Run check 2: LLM-agent confirms Step 4 prose explicitly handles all three Reason values with the prescribed orchestrator behavior.
  - Run check 3: LLM-agent confirms the `legacy_deferred_rows: true` opt-out behavior is described and matches the contract doc.
  - Run check 4: LLM-agent confirms the routed-rows persistence key `phase_<id>_routed_discoveries` is named consistently for Phase 8 to consume.
  - Expected: all four checks pass.

- [x] **[QA]** Phase review (Opus likely fires here per FR-9 mid-piece pass — this is phase 7 of 13, and Steps 4 + this region of execute/SKILL.md are real control-flow logic per FR-8's sharpened skip predicate).
  - Review against: AC-10, AC-11, AC-12.
  - Diff baseline: `git diff <phase_7_start_tag>..HEAD`.

---

### Phase 8: execute/SKILL.md Step 6c — Discovery Triage core (CAP-D part 1)
Why serial: same execute/SKILL.md serialization as Phase 7. This phase scopes the new Step 6c region.

**Exit Gate:** execute/SKILL.md gains a new Step 6c between Step 6 and Step 7 implementing the discovery aggregation + triage prompt + amend/fork/defer dispatch + amendment-commit flow + .discovery-log.md authoring; `[Verify]` confirms the new step's structural anchors.
**ACs Covered:** AC-13a, AC-14, AC-15, AC-16, AC-18, AC-20, AC-21a, AC-21b (AC-19 is owned by Phase 9 since Step 8 lives there)
**Charter constraints honored in this phase:**
- **NN-P-001 (artifacts human-readable):** the new `.discovery-log.md` per-piece artifact is plain markdown table format readable in `less`.
- **CR-004 (conventional-commits format):** amendment commits use `chore(plan): amend — <reason>` (chore type per CR-004 enumeration). Spec amendments use `chore(spec): amend — <reason>`.

- [x] **[Implement]** Author Step 6c in execute/SKILL.md.
  - Order:
    1. Read execute/SKILL.md to identify the current Step 6 (per-phase QA gate) → Step 7 (phase commit) boundary. Insert the new Step 6c between them.
    2. Author **Step 6c: Discovery Triage** with these subsections:
       - **Aggregation** — read the orchestrator state keys persisted by upstream steps:
         - `phase_<id>_routed_discoveries` (set by Phase 7 — Reason-field routed rows)
         - QA findings flagged `Deferred to reflection:` from Step 6 (the existing pi-009 ORC-3 mechanism — surface them here instead of auto-writing to backlog)
         - Build oracle escalations citing missing prerequisite (from Steps 2–4 oracle iteration exhaustion)
         Combine into a single discovery list keyed by source agent.
       - **Triage prompt** — present to operator:
         ```
         <N> discoveries surfaced in <phase-id>:
           [1] <type> from <source-agent>: <finding-summary>
               Options: (a) amend  (f) fork  (d) defer
           [2] <type> from <source-agent>: <finding-summary>
               Options: (a) amend  (f) fork  (d) defer
           ...
         Choose for each (or 'A' to amend all that fit < 50% threshold, 'D' to defer all):
         ```
         Aggregate same-phase discoveries into one prompt per NFR-6.
       - **Auto-mode default (FR-17)** — when execute is invoked with `--auto`, each discovery is auto-resolved as `amend` if `<estimated-absorption-size> / <cumulative-diff-size> < 0.5`. Otherwise auto-mode escalates with the threshold message. Auto-mode never auto-forks or auto-defers. The 50% threshold is computed per-discovery against the cumulative diff size at the moment the discovery surfaces; threshold breaches do not lock the piece into operator-required mode for subsequent discoveries.
       - **Amend dispatch** — for each discovery routed `amend`:
         - Dispatch `plan-amend` agent (Phase 4 output) with the current plan.md, the structured discovery report, and the diff+neighborhood scope (computed by enumerating phases whose `[Implement]`/`[Build]` blocks touch any file the discovery references — exact file path, not shared directory).
         - Extract the unified diff from the agent's `## Diff of changes` section (parse everything between that heading and the next `##`-or-EOF boundary).
         - On `(none)`: route the discovery as a Build re-dispatch instead.
         - On non-empty diff: write to a temporary file, run `git apply --check <tmpfile>` for validation. On failure, halt with `Refused — plan-amend diff did not apply cleanly: <git apply stderr>` and prompt operator to re-dispatch (counts as a fresh dispatch within the same triage event but does NOT consume an additional budget slot for the same discovery).
         - On success: `git apply <tmpfile>`, dispatch qa-plan with `Input Mode: Focused re-review` and the diff (iter-until-clean per qa-iteration-loop.md), and on clean commit `chore(plan): amend — <reason — discovery summary>` on the worktree branch. Resume execute starting at the first amendment phase (`phase_<N>_amend_1`).
         - Amendment phases use suffix-form IDs `phase_<N>_amend_<K>` per FR-13.
         - For spec amendments (operator chose `amend-spec` — only available when discovery names a missing FR/AC or a contradiction), dispatch `spec-amend` agent (Phase 5 output) instead. Apply same extract → git apply → qa-spec re-dispatch → commit `chore(spec): amend — <reason>` flow.
       - **Fork dispatch** — for each discovery routed `fork`:
         - Author a new piece entry in `docs/prds/<prd-slug>/manifest.yaml` with `depends_on: [<current-piece-slug>]` (qualified ref pointing back at the current piece).
         - Set the current piece's status to `blocked` in the manifest with a notes-line citing the fork reason.
         - Halt execute with `Forked: new piece <new-piece-slug> created with depends_on chain. Spec the prerequisite first, then resume <current-piece>.`
       - **Defer dispatch** — for each discovery routed `defer`:
         - Invoke `/spec-flow:defer` (Phase 1 output) structured-invocation form, passing source piece, source phase, source agent, finding text, operator-supplied rationale.
         - The defer skill writes the entry and commits `chore(<piece-slug>): defer <finding-summary>` (its own commit).
         - Execute continues to Step 7 (phase commit) without state changes.
       - **`.discovery-log.md` authoring** — for each triaged discovery, append a row to `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md`:
         ```markdown
         | <phase-id> | <type> | <source-agent> | <finding-1-line> | <choice> | <resolution-commit-sha> |
         ```
         If the file does not exist, create it with the H1 + table header per FR-15 of pi-010-discovery's spec. Each row is committed alongside its corresponding resolution commit (the amend commit, the fork manifest-update commit, or the /spec-flow:defer commit) — the row append and the resolution commit land as a single coherent commit. This produces a per-discovery audit trail in `git log`.
       - **Recursion semantics (FR-12)** — amendments cannot recursively amend within the same triage event. When an amendment phase's own per-phase QA gate (Step 6) surfaces a new discovery, that discovery flows through Step 6c per the standard rules and counts as a separate amendment event against the budget (FR-14, Phase 9).
       - **NN-P-002 preservation** — amendment phases run through their own per-phase QA gate (Step 6) before advancing. No auto-bypass of QA. The `--auto` mode's amend-without-prompt path applies to triage choice ONLY, not to QA gates.
    3. Cross-link from existing Step 4 (Phase 7 already updated this) to Step 6c (so the Reason routing chain is discoverable from either entry point).
  - Files: `plugins/spec-flow/skills/execute/SKILL.md` (new Step 6c region only).
  - Pattern pointers:
    - `plugins/spec-flow/skills/execute/SKILL.md` Step 6 (existing per-phase QA gate) for the dispatch + iter-until-clean idiom.
    - `plugins/spec-flow/agents/fix-doc.md` extraction pattern in execute (the existing fix-doc → fix-code orchestrator logic) for the `## Diff of changes` parse + git apply mechanism.
    - `plugins/spec-flow/skills/execute/SKILL.md:410` for the `phase_<id>_<key>` orchestrator state-key naming convention.
  - Architecture constraints: CR-004 (chore commit type), CR-008 (orchestrator stays in SKILL.md prose; agent dispatches stay narrow).
  - **Phase-sizing note:** this phase's `[Implement]` block is under 150 lines of behavioral prose by design — Step 6c's full content (aggregation, triage, amend/fork/defer dispatch, .discovery-log.md authoring, recursion semantics, NN-P-002 preservation) is authored here; budget tracking + Step 8 + auto-mode threshold prose was deliberately split into Phase 9 to keep both phases under the 150-line threshold.

- [x] **[Verify]** Confirm Step 6c structural anchors.
  - Run check 1: LLM-agent reads execute/SKILL.md and confirms a new Step 6c exists between Step 6 and Step 7.
  - Run check 2: LLM-agent confirms Step 6c contains all six subsections (Aggregation, Triage prompt, Auto-mode default, Amend dispatch, Fork dispatch, Defer dispatch, .discovery-log.md authoring, Recursion semantics, NN-P-002 preservation).
  - Run check 3: LLM-agent confirms the amend-dispatch subsection cites `git apply --check` then `git apply` per FR-11 of pi-010-discovery's spec.
  - Run check 4: LLM-agent confirms the suffix-form `phase_<N>_amend_<K>` ID convention is present.
  - Run check 5: LLM-agent confirms the chore commit-type convention is used (no `amend(plan)` strings remain in the new prose).
  - Expected: all five checks pass.

- [x] **[QA]** Phase review (Opus expected).
  - Review against: AC-13a, AC-14, AC-15, AC-16, AC-18, AC-20, AC-21a, AC-21b. (AC-19, AC-21c, AC-17 land in Phase 9.)
  - Diff baseline: `git diff <phase_8_start_tag>..HEAD`.

---

### Phase 9: execute/SKILL.md amendment budget + Step 8 Final Review Triage + auto-mode threshold (CAP-D part 2)
Why serial: same execute/SKILL.md serialization as Phase 7. This phase scopes the budget tracking + new Step 8 + auto-mode threshold prose.

**Exit Gate:** execute/SKILL.md gains amendment-budget enforcement (FR-14), a new Step 8: Final Review Triage that re-invokes Step 6c for end-of-piece findings (FR-16a), and auto-mode threshold prose; `[Verify]` confirms the structural anchors.
**ACs Covered:** AC-17 (budget exhaustion), AC-19 (Step 8 routing), AC-21 (auto-mode threshold), AC-21c (spec-amend budget refusal)
**Charter constraints honored in this phase:**
- **NN-C-006 (no destructive ops without confirmation):** the budget-exhaustion escalation prompt requires explicit `(y/n)` operator confirmation before continuing or halting. The piece-status-flips-to-blocked path on `n` is a manifest-update commit, not a destructive operation.
- **NN-P-002 (no auto-merge two human gates):** Step 8's amendment-on-Final-Review path runs amendment phases through their own per-phase QA gates (Step 6) before merge. Final Review iteration loop remains intact; amendments add work before merge but do not bypass either gate.

- [x] **[Implement]** Author the budget tracking + Step 8 + auto-mode threshold prose.
  - Order:
    1. Add a paragraph at the top of Step 6c (already authored in Phase 8) referencing the budget tracking subsection that follows in this phase. Specifically: "**Budget enforcement (FR-14)** — see budget tracking subsection below; every amend dispatch increments the per-piece counter."
    2. Add a new subsection in Step 6c: **Amendment budget tracking**:
       - Per-piece amendment budget: 2 amendments total per piece, of which at most 1 may be a spec amendment.
       - The orchestrator tracks `piece_amendment_count` (init: 0) and `piece_spec_amendment_count` (init: 0) in piece-scoped state.
       - Before dispatching plan-amend or spec-amend, the orchestrator checks: if `piece_amendment_count` ≥ 2, refuse with the budget-exhaustion escalation. If the choice is `amend-spec` and `piece_spec_amendment_count` ≥ 1, refuse with `Refused — spec-amend budget exhausted (1/1); choose plan-amend, fork, or defer.`.
       - On successful amend dispatch (commit lands), increment the appropriate counter.
       - **Budget-exhaustion escalation prompt:**
         ```
         Amendment budget exhausted — piece scope was inadequate. Escalating: abandon and re-spec from scratch is recommended. Continue anyway? (y/n)
         ```
         On `y`: orchestrator continues with no further amendments allowed (subsequent discoveries may only fork or defer).
         On `n`: orchestrator halts execute, sets the current piece's status to `blocked` in the manifest with a notes-line citing budget exhaustion, commits the manifest update, and exits.
    3. Add a new top-level **Step 8: Final Review Triage** in execute/SKILL.md, positioned between today's Final Review iter-loop and the merge gate. Body:
       - **Trigger:** when Final Review (the 4-reviewer end-of-piece board: blind, spec-compliance, architecture, edge-case) returns must-fix findings, the orchestrator invokes Step 8 once before any merge action.
       - **Per-finding routing:** for each must-fix finding, dispatch the Step 6c triage flow per FR-16a. The triage prompt's source-phase column for `.discovery-log.md` rows is set to the literal token `final-review`; the source-agent column names which reviewer flagged it (blind / spec-compliance / architecture / edge-case).
       - **Amendment phase IDs:** amendment phases inserted via Step 8 use suffix-form IDs `phase_final_amend_<K>` (where the originating phase is the literal token `final` since there is no specific upstream phase).
       - **On `amend`:** the piece re-opens — amendment phases run through their full TDD/Implement track including per-phase QA gates before the merge gate fires.
       - **On `fork`:** a follow-up piece is written to manifest with `depends_on:` chain pointing at the current piece; the current piece merges as-is with the discovery deferred to the new piece.
       - **On `defer`:** /spec-flow:defer writes a backlog entry with operator-recorded rationale; the piece advances to merge.
    4. Update Step 6a's "Append a stub to backlog" prose: replace the inline-append code path with a call to /spec-flow:defer. Specifically: the orchestrator now invokes `/spec-flow:defer` structured-invocation only after the operator chose defer in Step 6c (or Step 8) — auto-write of "Deferred to reflection:" findings is removed; those findings now flow into Step 6c's aggregation.
    5. Add an **Auto-mode threshold (FR-17)** subsection inside Step 6c (next to "Amend dispatch" subsection authored in Phase 8) explicitly stating: each discovery is evaluated independently against the current cumulative diff size at the moment the discovery surfaces; threshold breaches do not lock subsequent discoveries.
  - Files: `plugins/spec-flow/skills/execute/SKILL.md` (Step 6c budget subsection + new Step 8 region + Step 6a rewrite).
  - Pattern pointers:
    - `plugins/spec-flow/skills/execute/SKILL.md`'s existing Final Review iter-loop section for the position-anchor of Step 8.
    - `plugins/spec-flow/skills/execute/SKILL.md`'s existing piece-state-update commits for the manifest-blocked-status flow on budget-exhaustion `n`.
    - `plugins/spec-flow/skills/execute/SKILL.md`'s existing Step 6a backlog-append prose (which this phase rewrites).
  - Architecture constraints: NN-C-006 (operator confirmation), NN-P-002 (per-phase QA preserved).
  - **Phase-sizing note:** under 150 lines; no override.

- [x] **[Verify]** Confirm budget + Step 8 + auto-mode prose anchors.
  - Run check 1: LLM-agent reads Step 6c and confirms the **Amendment budget tracking** subsection with the 2-total-with-1-spec-cap rule and budget-exhaustion prompt.
  - Run check 2: LLM-agent reads execute/SKILL.md and confirms a new top-level **Step 8: Final Review Triage** exists positioned between Final Review iter-loop and merge gate.
  - Run check 3: LLM-agent confirms Step 8 prescribes `phase_final_amend_<K>` IDs and dispatches Step 6c per finding.
  - Run check 4: LLM-agent confirms Step 6a's "Append a stub" prose has been rewritten to invoke /spec-flow:defer instead of inline-appending.
  - Run check 5: LLM-agent confirms the auto-mode subsection's per-discovery threshold reset language matches FR-17.
  - Expected: all five checks pass.

- [x] **[QA]** Phase review (Opus expected).
  - Review against: AC-17, AC-19, AC-21, AC-21c, NN-P-002 preservation.
  - Diff baseline: `git diff <phase_9_start_tag>..HEAD`.

---

### Phase 10: execute/SKILL.md Step 4.5 — reflection rerouting (CAP-E orchestrator side)
Why serial: same execute/SKILL.md serialization as Phase 7. This phase scopes the Step 4.5 region.

**Exit Gate:** execute/SKILL.md Step 4.5 prose is rewritten so reflection agents emit findings to the orchestrator rather than directly writing to backlog files; the orchestrator dispatches Step 6c triage on receipt; `[Verify]` confirms the rewrite.
**ACs Covered:** AC-22, AC-23, AC-24, AC-25
**Charter constraints honored in this phase:** (none specific — extends an existing step; CR-004 chore commits inherit from Phase 8's allocation.)

- [x] **[Implement]** Rewrite execute/SKILL.md Step 4.5 to dispatch triage instead of auto-writing.
  - Order:
    1. Read execute/SKILL.md Step 4.5 (currently titled "End-of-piece reflection — Step 4.5").
    2. Replace the existing `git add backlog.md && git commit -m "reflection: ..."` step with new prose:
       - The orchestrator dispatches both reflection agents per existing rules.
       - On agent reports, the orchestrator does NOT commit any backlog file directly.
       - `reflection-future-opportunities` findings: dispatch Step 6c triage flow once per finding (each finding gets its own triage prompt — amend / fork / defer). Source-phase column for `.discovery-log.md` rows is the literal token `step-4.5-reflection`; source-agent column is `reflection-future-opportunities`.
       - `reflection-process-retro` findings: dispatch Step 6c triage flow as a single batched prompt enumerating all N findings with one defer-batch action. Source-phase column is `step-4.5-reflection`; source-agent column is `reflection-process-retro`.
       - On `defer` for any reflection finding, /spec-flow:defer writes the entry and commits `chore(<piece-slug>): defer <finding-summary>` (its own commit). On `amend` / `fork`, route through Step 6c's normal amend / fork dispatch (Phase 8 / Phase 9 prose).
       - The Step 5 learnings.md commit remains unchanged (learnings.md is the synthesized doc, separate from raw findings).
       - Explicit removal: the previous-version commit-message pattern `reflection: <piece> — append findings to backlogs` no longer occurs. Document this as a release-note in CHANGELOG (Phase 13).
    3. Remove any prose in execute/SKILL.md Step 4.5 that prescribes inline file-append to backlog.md. The reflection step itself produces no commits (the agent reports, orchestrator routes, defer skill or amend agent commits).
  - Files: `plugins/spec-flow/skills/execute/SKILL.md` (Step 4.5 region only).
  - Pattern pointers:
    - `plugins/spec-flow/skills/execute/SKILL.md` Step 4.5's existing dispatch prose for the agent-dispatch idiom (kept; only the post-receipt prose changes).
    - Step 6c (Phase 8) for the triage flow this step dispatches into.
  - Architecture constraints: CR-008 (skill orchestrates; reflection agents stay narrow — Phase Group B updates the agent prompts).

- [x] **[Verify]** Confirm Step 4.5 rewrite.
  - Run check 1: LLM-agent reads Step 4.5 and confirms the auto-write `git add backlog.md && git commit -m "reflection: ..."` step is removed.
  - Run check 2: LLM-agent confirms Step 4.5 prescribes per-finding triage for future-opportunities and batched triage for process-retro.
  - Run check 3: LLM-agent confirms `step-4.5-reflection` is named as the source-phase value for `.discovery-log.md` rows.
  - Run check 4: LLM-agent confirms the explicit-removal note for the old reflection commit pattern is present (or punted to CHANGELOG with a clear pointer).
  - Expected: all four checks pass.

- [x] **[QA]** Phase review.
  - Review against: AC-22, AC-23, AC-24, AC-25.
  - Diff baseline: `git diff <phase_10_start_tag>..HEAD`.

---

## Phase Group B: reflection agents — emit triage reports (CAP-E agent side, parallel)
**Exit Gate:** both sub-phases pass `[Verify]` + group-level `[QA]` returns must-fix=None.
**ACs Covered:** (none directly — AC-22, AC-23, AC-24, AC-25 are owned by Phase 10's orchestrator-side dispatch logic; this group ships the agent-side report-shape contract that Phase 10 consumes. The group's correctness is verified at the agent-output structural level — see per-sub-phase Verify steps.)

#### Sub-Phase B.1 [P]: reflection-future-opportunities agent rerouting
**Scope:** plugins/spec-flow/agents/reflection-future-opportunities.md
**ACs:** (none directly — supports AC-22 / AC-24 from Phase 10's perspective; this sub-phase ships the agent-side emit contract.)
**Charter constraints honored in this sub-phase:** (none specific — agent-prompt edit; pattern set by Phase 10's orchestrator-side rewrite.)

- [x] **[Implement]** Update reflection-future-opportunities.md to emit findings to orchestrator instead of writing files.
  - Order:
    1. Read `plugins/spec-flow/agents/reflection-future-opportunities.md`.
    2. Replace the agent's "Findings append under..." prose (currently telling the agent to write findings to backlog files) with: emit findings as a structured report to the orchestrator. Format:
       ```markdown
       ## Findings

       ### Finding 1
       **Type:** future-opportunity
       **Rationale:** <why this is worth pursuing>
       **Dependencies:** <other backlog items / pieces it should follow, or "none">
       **Candidate piece sketch:** <2-3 line description>

       ### Finding 2
       ...
       ```
    3. Remove any prose describing direct file-append code paths or backlog-write commits.
    4. Add explicit prose: "The orchestrator (execute/SKILL.md Step 4.5) receives this report and dispatches per-finding triage. The agent does NOT write to any backlog file directly."
  - Files: `plugins/spec-flow/agents/reflection-future-opportunities.md`.
  - Pattern pointers: `plugins/spec-flow/agents/reflection-process-retro.md` for the structural skeleton the two agents share — Sub-Phase B.2 keeps that skeleton parallel.

- [x] **[Verify]** Confirm the agent emits structured findings.
  - Run check 1: LLM-agent reads the file and confirms the `## Findings` / `### Finding N` shape is described.
  - Run check 2: LLM-agent confirms direct-file-append prose is absent.
  - Expected: both checks pass.

- [x] **[QA-lite]** Sonnet narrow review.
  - Scope: this sub-phase only.
  - Review: AC-22 binding, removal of file-append prose, structural shape vs B.2.

#### Sub-Phase B.2 [P]: reflection-process-retro agent rerouting
**Scope:** plugins/spec-flow/agents/reflection-process-retro.md
**ACs:** (none directly — supports AC-23 / AC-24 from Phase 10's perspective; this sub-phase ships the agent-side emit contract.)
**Charter constraints honored in this sub-phase:** (none specific.)

- [x] **[Implement]** Update reflection-process-retro.md to emit findings to orchestrator instead of writing files.
  - Order:
    1. Read `plugins/spec-flow/agents/reflection-process-retro.md`.
    2. Replace direct-file-append prose with an emit-to-orchestrator report format mirroring B.1's structure:
       ```markdown
       ## Findings

       ### Finding 1
       **Type:** process-retro (one of: must-improve | worked-well | metrics)
       **Category:** <process-improvement | piece-candidate | observation>
       **Body:** <verbatim retro item text>

       ### Finding 2
       ...
       ```
    3. Note that `process-improvement` category items batch-defer at end of piece (single batched prompt, one defer action covers all). Other categories (piece-candidate, observation) get per-finding triage like future-opportunities.
    4. Remove any prose describing direct file-append code paths.
    5. Add explicit prose mirroring B.1: "The orchestrator (execute/SKILL.md Step 4.5) receives this report and dispatches batched triage on the entire report. The agent does NOT write to any backlog file directly."
  - Files: `plugins/spec-flow/agents/reflection-process-retro.md`.
  - Pattern pointers: B.1's output for parallelism (the two agents emit symmetric structures so the orchestrator can route them through the same Step 6c without per-agent special cases).

- [x] **[Verify]** Confirm the agent emits structured findings.
  - Run check 1: LLM-agent reads the file and confirms the `## Findings` / `### Finding N` shape with the Type/Category/Body fields.
  - Run check 2: LLM-agent confirms direct-file-append prose is absent.
  - Run check 3: LLM-agent confirms the prose distinguishes process-improvement (batched) from piece-candidate/observation (per-finding) categories.
  - Expected: all three checks pass.

- [x] **[QA-lite]** Sonnet narrow review.
  - Scope: this sub-phase only.
  - Review: AC-23 binding, removal of file-append prose, parallel structure with B.1.

#### Group-level
- [x] **[Refactor]** scope: union of sub-phase files (auto-skip if both Builds clean).
- [x] **[QA]** Opus deep review, diff baseline: group_start_sha. Scope: agent-side emit contracts only (the orchestrator-side ACs AC-22/23/24/25 are reviewed at Phase 10's QA gate). Confirm both agents' output schemas stay structurally parallel and orchestrator integration in Phase 10 reads consistently from both.

---

### Phase 12: README.md update (FR-22)
**Exit Gate:** `plugins/spec-flow/README.md` documents Step 6c, plan-amend, spec-amend, and /spec-flow:defer in the pipeline overview, agent inventory, and skills sections; `[Verify]` confirms grep contracts.
**ACs Covered:** AC-27b
**Charter constraints honored in this phase:**
- **CR-005 (repo-relative paths):** all path references in the README updates use repo-root-relative paths.
- **CR-009 (markdown semantic hierarchy):** the README's existing H1/H2/H3 structure is preserved; new entries land at appropriate H3 / H4 under existing H2 sections (Pipeline / Agent inventory / Skills) without skipping levels.

- [x] **[Implement]** Update README.md to reflect the v3.2.0 pipeline.
  - Order:
    1. Read `plugins/spec-flow/README.md`.
    2. In the Pipeline overview section (the `charter → prd → spec → plan → execute` diagram + per-stage description), update the execute description to note: "execute now includes synchronous discovery triage at end-of-phase (Step 6c) and at end-of-piece (Step 8: Final Review Triage). Discoveries route to plan-amend / spec-amend / fork / defer per the per-piece amendment budget (2 total, max 1 spec)."
    3. In the Agent inventory section, add entries for `plan-amend` and `spec-amend`:
       - **plan-amend** (Sonnet) — Internal agent dispatched by execute Step 6c when an operator chooses to amend the plan in response to a discovery. Reads plan + discovery report + diff+neighborhood scope; emits a unified diff inserting suffix-named amendment phases. Does NOT commit.
       - **spec-amend** (Sonnet) — Internal agent dispatched by execute Step 6c when a discovery implies the spec was wrong. Reads spec + discovery report + affected sections; emits a unified diff adding FRs/ACs/NFRs within the piece's stated goals. Does NOT commit.
    4. In the Skills section (or wherever skills are inventoried — check the README's actual structure), add an entry for `/spec-flow:defer`:
       - **defer** — Operator-driven skill (also dispatched structured by execute Step 6c) that records a non-blocking finding to a backlog file with provenance. Sole supported path for writing to `<docs_root>/prds/<prd-slug>/backlog.md` or `<docs_root>/improvement-backlog.md`.
    5. Add a sub-section under the Pipeline overview titled "Synchronous discovery triage (v3.2.0+)" briefly explaining the principle: the execution that found the work also fixes it; discoveries get triaged at end-of-phase, not silently deferred. Link to ac-matrix-contract.md and depends-on-precondition.md for the load-bearing references.
  - Files: `plugins/spec-flow/README.md`.
  - Pattern pointers:
    - The existing README structure (H2 sections for Pipeline, Agent inventory, Skills) — match the existing density and tone; do not bloat.
    - `plugins/spec-flow/CHANGELOG.md` for semver tone (this is documentation-as-source-of-truth per NFR-004).
  - Architecture constraints: CR-005 (repo-relative paths), CR-009 (heading hierarchy).

- [x] **[Verify]** Confirm README updates per AC-27b.
  - Run check 1: LLM-agent reads README.md and grep-confirms the literal strings `Step 6c`, `plan-amend`, `spec-amend`, `defer` all appear with concrete prose around each (not just bare mentions).
  - Run check 2: LLM-agent confirms the Synchronous discovery triage sub-section exists under Pipeline overview.
  - Run check 3: LLM-agent confirms the Agent inventory has both new agents listed at the same H-level as existing agents.
  - Run check 4: LLM-agent confirms heading hierarchy is preserved (no skipped levels).
  - Expected: all four checks pass.

- [x] **[QA]** Phase review.
  - Review against: AC-27b, FR-22.
  - Diff baseline: `git diff <phase_12_start_tag>..HEAD`.

---

### Phase 13: Release ceremony (FR-20, FR-21)
Why serial: release ceremony commits the v3.2.0 version bump that all preceding phases describe in their CHANGELOG-bound deliverables. By definition runs last; preceding phases must all have landed before the release commit can be authored coherently. Disjoint file scope from Phase 12 (README) but ordered last by intent, not by file conflict.

**Exit Gate:** plugin.json + marketplace.json bumped 3.1.3 → 3.2.0; CHANGELOG.md gains the v3.2.0 section per Keep a Changelog with all five CAP items grouped + Migration notes for upgraders; `[Verify]` confirms NN-C-001 sync + AC-27 CHANGELOG content.
**ACs Covered:** AC-26, AC-27, AC-27a (env preconditions presence — verified at release-commit boundary against Phase 1, Phase 4, Phase 5 outputs)
**Charter constraints honored in this phase:**
- **NN-C-001 (plugin/marketplace version sync):** the release commit updates `plugins/spec-flow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` in the same commit. AC-26 verifies the two files agree on `version: 3.2.0`.
- **NN-C-003 (backwards-compat within major):** v3.2.0 is a minor bump per NN-C-009's tier guidance — additions (defer skill, plan-amend agent, spec-amend agent, AC matrix Reason field, .discovery-log.md artifact) and opt-in stricter behavior (`legacy_deferred_rows: false` default with `true` opt-out for one release). The CHANGELOG's Migration notes explicitly state existing pre-v3.2.0 plans continue to work without modification.
- **NN-C-007 (CHANGELOG in Keep a Changelog format):** the new `## [3.2.0] — YYYY-MM-DD` section follows the standard with Added / Changed / Removed / Migration notes for upgraders subsections.
- **NN-C-009 (always bump plugin version):** three-place bump per the rule's "Three places to update for every bump" — plugin.json, marketplace.json, CHANGELOG.md, all in a single coherent release commit per the rule's exception.
- **NN-P-003 (dog-food before recommend):** the release commit ships only after this piece itself runs through the new flow on this repo (the user's pi-010-discovery execute run dog-foods plan-amend / spec-amend / Step 6c / defer / Step 8 before user-facing release).

- [x] **[Implement]** Cut the v3.2.0 release artifacts.
  - Order:
    1. Update `plugins/spec-flow/.claude-plugin/plugin.json`: change `"version": "3.1.3"` to `"version": "3.2.0"`.
    2. Update `.claude-plugin/marketplace.json`: locate the `spec-flow` entry in the `plugins` array and change its `"version": "3.1.3"` to `"version": "3.2.0"`.
    3. Prepend a new section to `plugins/spec-flow/CHANGELOG.md` (above the v3.1.3 section, below the `# Changelog` title):
       ```markdown
       ## [3.2.0] — YYYY-MM-DD

       ### Added
       - **`/spec-flow:defer` skill** — sole supported path for writing to backlog files. Records source piece, source phase, finding text, operator's rationale for non-blocking, and capture date. Invoked structured (from execute Step 6c after operator chooses defer) or manually (`/spec-flow:defer "<finding>" --rationale "<text>"`).
       - **`plan-amend` agent** — Sonnet agent dispatched by execute Step 6c when operator chooses to amend the plan. Emits a unified diff inserting suffix-named amendment phases (`phase_<N>_amend_<K>`).
       - **`spec-amend` agent** — Sonnet agent dispatched when a discovery implies the spec was wrong. Emits unified diffs adding FRs / ACs / NFRs within the piece's stated goals.
       - **`Step 6c: Discovery Triage`** in execute/SKILL.md — synchronous discovery triage at end-of-phase. Aggregates discoveries from per-phase QA gate, AC matrix `requires-amendment` rows, Build oracle escalations. Each discovery gets operator triage: amend / fork / defer.
       - **`Step 8: Final Review Triage`** in execute/SKILL.md — re-invokes Step 6c for end-of-piece Final Review must-fix findings. Amendment phases use `phase_final_amend_<K>` IDs.
       - **AC matrix `Reason:` field** for `NOT COVERED — deferred to ...` rows — required values: `does-not-block-goal`, `requires-amendment`, `requires-fork`. See `plugins/spec-flow/reference/ac-matrix-contract.md`.
       - **`.discovery-log.md`** per-piece artifact — committed to `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md`. Records every discovery and its triage outcome.
       - **`legacy_deferred_rows: true` opt-in flag** in plan front-matter — preserves pre-3.2.0 AC matrix behavior for one release. Deprecated; will be retired in v3.3.0.
       - **`depends_on:` precondition checks** in `/spec-flow:spec` and `/spec-flow:plan` — surface unmet dependencies at spec/plan time. Three options: pull-deps-in / fork / proceed (operator override).
       - **`plugins/spec-flow/reference/ac-matrix-contract.md`** — new reference doc factoring the AC matrix schema + parsing rules. Previously referenced by execute/SKILL.md but did not exist.
       - **`plugins/spec-flow/reference/depends-on-precondition.md`** — new reference doc factoring the depends_on resolution + triage rules. Cited by spec, plan, and execute skills.

       ### Changed
       - **execute Step 4.5 (reflection)** — reflection agents (`reflection-future-opportunities`, `reflection-process-retro`) now emit findings to the orchestrator instead of writing directly to backlog files. The orchestrator dispatches Step 6c triage on receipt.
       - **execute Step 6a** — "Append a stub to backlog" prose now invokes `/spec-flow:defer` only after operator chose defer in Step 6c. Auto-write of `Deferred to reflection:` findings is removed; those findings flow into Step 6c aggregation.
       - **per-piece amendment budget** — 2 amendments per piece, with at most 1 being a spec amendment. Hitting the budget triggers the orchestrator escalation.

       ### Removed
       - The previous reflection-step commit message pattern `reflection: <piece> — append findings to backlogs` no longer occurs (the reflection step itself produces no commits in v3.2.0+).

       ### Migration notes for upgraders
       - **Existing backlog entries are grandfathered.** No automatic triage; they remain in `<docs_root>/prds/<prd-slug>/backlog.md` and `<docs_root>/improvement-backlog.md` as-is.
       - **Plans authored under v3.1.x continue to work.** Bare `NOT COVERED — deferred` rows are still accepted for one release if the plan sets `legacy_deferred_rows: true` in its front-matter. v3.3.0 will retire the flag — update plans before then.
       - **Behavioral change in QA + reflection.** Discoveries that previously flowed silently to backlog files now surface as triage prompts at end-of-phase. Operators see more interruptions but with explicit choice points; auto-mode (`--auto`) absorbs small discoveries (<50% cumulative diff) automatically and escalates large ones.
       - **`qa_iter2: auto` config key** (already deprecated in v3.1.0) is unchanged in v3.2.0.
       ```
    4. Use today's date (`date +%F`) for the YYYY-MM-DD placeholder.
  - Files: `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md`.
  - Pattern pointers:
    - `plugins/spec-flow/CHANGELOG.md` v3.1.0 entry (the most recent comparable minor bump) for tone, density, grouping convention.
    - `.claude-plugin/marketplace.json` existing structure — find the spec-flow entry in the plugins array and update only the `version` field.
  - Architecture constraints: NN-C-001, NN-C-003, NN-C-007, NN-C-009, NN-P-003.

- [x] **[Verify]** Confirm the release ceremony per AC-26, AC-27, AC-27a.
  - Run check 1 (AC-26 / NN-C-001): LLM-agent reads both `plugins/spec-flow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`; parses each as JSON inline; confirms `plugin.json.version === marketplace.json.plugins[name=spec-flow].version === "3.2.0"`. Per pi-009 ORC-6 / FR-13 (LLM-native [Verify] convention), do NOT shell out to `jq`.
  - Run check 2 (AC-27): LLM-agent reads `plugins/spec-flow/CHANGELOG.md`; confirms a new `## [3.2.0] — YYYY-MM-DD` section exists at the top with at least Added (defer skill, .discovery-log.md, plan-amend agent, AC matrix Reason field) and Migration notes for upgraders subsections populated.
  - Run check 3 (AC-27a / NFR-7): LLM-agent reads `plugins/spec-flow/skills/defer/SKILL.md`, `plugins/spec-flow/agents/plan-amend.md`, and `plugins/spec-flow/agents/spec-amend.md`; confirms each contains a `## Environment preconditions` section. Confirms each section enumerates LLM-runtime + git + POSIX shell expectations and explicitly states no external-tool runtime dependencies (the prose mentions "LLM agent's runtime" and "no external" or equivalent pattern).
  - Run check 4: LLM-agent confirms today's date appears as the YYYY-MM-DD value.
  - Expected: all four checks pass.

- [x] **[QA]** Phase review (Opus expected).
  - Review against: AC-26, AC-27, AC-27a, NN-C-001, NN-C-003, NN-C-007, NN-C-009, NN-P-003.
  - Diff baseline: `git diff <phase_13_start_tag>..HEAD`.

---

## Final Review

End-of-piece, after all phase commits land, the orchestrator dispatches the standard 4-reviewer board (blind, spec-compliance, architecture, edge-case) per existing execute/SKILL.md Final Review rules. This piece's introduction of Step 8 (Phase 9 output) means any Final Review must-fix finding now routes through Step 8 → Step 6c, NOT through silent backlog deferral. The 4-reviewer board itself is unchanged.

## Agent context summary

| Phase | Track | Lead deliverable | Charter slot allocations |
|---|---|---|---|
| 1 | Implement | defer skill (`skills/defer/SKILL.md`) | NN-C-002, NN-C-005, NFR-004, CR-002 |
| 2 | Implement | depends-on-precondition.md reference | (none specific — refactor of existing prose) |
| Group A.1 | Implement | spec/SKILL.md depends_on precondition | (group-level) |
| Group A.2 | Implement | plan/SKILL.md depends_on precondition | (group-level) |
| 4 | Implement | plan-amend agent | NN-C-004, CR-001 |
| 5 | Implement | spec-amend agent | NN-C-008, CR-008 |
| 6 | Implement | ac-matrix-contract.md + plan template flag | (none specific) |
| 7 | Implement | execute/SKILL.md Step 4 enforcement (CAP-B) | (none specific) |
| 8 | Implement | execute/SKILL.md Step 6c core (CAP-D part 1) | NN-P-001, CR-004 |
| 9 | Implement | execute/SKILL.md budget + Step 8 + auto-mode (CAP-D part 2) | NN-C-006, NN-P-002 |
| 10 | Implement | execute/SKILL.md Step 4.5 rerouting (CAP-E orch) | (none specific) |
| Group B.1 | Implement | reflection-future-opportunities agent rerouting | (group-level) |
| Group B.2 | Implement | reflection-process-retro agent rerouting | (group-level) |
| 12 | Implement | README.md update | CR-005, CR-009 |
| 13 | Implement | Release ceremony (3-place bump + CHANGELOG) | NN-C-001, NN-C-003, NN-C-007, NN-C-009, NN-P-003 |

**Charter constraint accounting (after iter-1 fixes):**

| Entry | Allocated to phase |
|---|---|
| NN-C-001 (plugin/marketplace version sync) | Phase 13 |
| NN-C-002 (no runtime deps) | Phase 1 |
| NN-C-003 (backwards-compat) | Phase 13 |
| NN-C-004 (agent frontmatter bare name) | Phase 4 |
| NN-C-005 (hooks/skills silent on optionals) | Phase 1 |
| NN-C-006 (no destructive ops without confirm) | Phase 9 |
| NN-C-007 (CHANGELOG Keep a Changelog) | Phase 13 |
| NN-C-008 (agent prompts self-contained) | Phase 5 |
| NN-C-009 (always bump plugin version) | Phase 13 |
| NFR-004 (documentation as source of truth) | Phase 1 |
| NN-P-001 (artifacts human-readable) | Phase 8 (.discovery-log.md is the canonical new artifact) |
| NN-P-002 (no auto-merge two human gates) | Phase 9 |
| NN-P-003 (dog-food before recommend) | Phase 13 |
| CR-001 (agent frontmatter schema) | Phase 4 |
| CR-002 (skill frontmatter schema) | Phase 1 |
| CR-004 (conventional-commits format) | Phase 8 |
| CR-005 (repo-relative paths) | Phase 12 |
| CR-008 (thin orch / narrow agent) | Phase 5 |
| CR-009 (markdown semantic hierarchy) | Phase 12 |

**Total: 19 entries, all in exactly one phase, no duplicates after iter-1 reconciliation. ✓**
