---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
legacy_deferred_rows: false
tdd: false
fast: false
---

# Plan: research-unify

**Spec:** docs/prds/exec-ready/specs/research-unify/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Run codebase gathering **exactly once per piece** — in an isolated Opus sub-agent, before the first
spec brainstorm question — and have both the spec and plan stages consume the single durable artifact
(`research.md`) it produces. The contract is centralized in one reference doc, implemented by one new
agent, and consumed by two reordered/branched skills, then closed out with a path-convention edit and
a version bump.

**Track / mode.** This piece is **pure doc-as-code** — markdown agent/reference/skill files plus a
JSON+CHANGELOG version sync. Per **NN-C-002** the plugin ships no runtime code and there is **no test
runner**. Front-matter records `tdd: false` (the piece is not test-driven). All phases use the
**Implement track** (`[Implement]` → `[Verify]`); the `tdd: false` mode's `[Write-Tests]` step is
**deliberately omitted** because there is no runtime test layer to author — its role is served by the
structural `grep`/`jq`/`git` assertions inside each `[Verify]` block, exactly as the spec's *Testing
Strategy* prescribes ("there is no test runner; verification is structural"). The execute orchestrator
branches mechanically on the per-phase `[Implement]` checkbox, so this is consistent. The **AC Coverage
Matrix and Executable AC Binding are retained** (not dropped, as `tdd: false` permits) because the
seven ACs are the verification spine of this piece. `fast: false` — per-phase QA runs inline; the
operator chose Standard mode so the load-bearing spec-skill reorder (Phase 4) gets per-phase Opus
review rather than deferring all review to end-of-piece.

**Phase map (6 phases, all Implement track, serial):**
1. CREATE the artifact contract (`reference/research-artifact.md`) — the single source of truth.
2. CREATE the research agent (`agents/research.md`) — cites the contract, writes `research.md`, returns a ≤2K digest.
3. MODIFY `reference/brainstorm-procedure.md` — make L-10 the UNAVAILABLE-path fallback; dual-source the Conventions Block.
4. MODIFY `skills/spec/SKILL.md` — the load-bearing reorder: worktree + research dispatch + commit before brainstorm; UNAVAILABLE fallback.
5. MODIFY `skills/plan/SKILL.md` — Phase-1 CONSUMED/ABSENT branch; seed `introspection.md` from `research.md`.
6. MODIFY `reference/v3-path-conventions.md` + bump all four version-bearing files to **5.3.0** + CHANGELOG.

Dependency order: Phase 1 defines the schema everything else implements/consumes (→ 2, 4, 5). Phase 3
precedes Phase 4 because `spec/SKILL.md` cites the updated `brainstorm-procedure.md`. Phase 6 is last so
the version bump and CHANGELOG capture every preceding change.

## Architectural Decisions

### ADR-1: Move worktree creation + research dispatch ahead of brainstorm
**Context:** The research agent must write `research.md` onto the piece branch before brainstorm so the
spec stage can lead with its digest. Today `spec/SKILL.md` creates the worktree in Phase 3, *after*
brainstorm. The branch must therefore exist earlier.
**Decision:** Move the gitignore check, slug validation, and worktree/branch creation out of Phase 3
into a new pre-brainstorm block in Phase 2, immediately after the decomposition scope-check; dispatch
the research agent into the new worktree and commit `research.md` there, all before the first brainstorm
question. Phase 3 is retitled "Write Spec" and keeps only spec authoring.
**Alternatives considered:** (a) Keep worktree creation in Phase 3 and write `research.md` to a temp
path, moving it after worktree creation — rejected: introduces a second copy/move seam and breaks the
"committed before spec.md" ancestor guarantee (AC-1). (b) Run research with no worktree and have plan
re-derive — rejected: that is the status quo this piece removes.
**Consequences:** Easier — one branch holds research+spec+plan; AC-1's ancestor check is natural. Harder
— a brainstorm abandoned *after* the research commit leaves a recoverable orphan worktree+branch (an
accepted low-frequency cost; running the decomposition scope-check first keeps the orphan window small).
**Charter alignment:** Honors **NN-P-001** (the spec sign-off gate is untouched — only setup moves
earlier). Constrained by **NN-C-003** (additive; UNAVAILABLE fallback preserves current behavior).

### ADR-2: Seed `introspection.md` by structural copy, never replace Phase 2's reader
**Context:** Plan Phase 2 reads `introspection.md` section-by-section. Reusing `research.md` must not
destabilize that reader.
**Decision:** On the CONSUMED path, plan Phase 1 **seeds** `introspection.md` by a structural copy of
`research.md`'s cluster-grouped four-block sections, then top-ups non-covered files and re-reads stale
covered files. Phase 2's reader is byte-for-byte unchanged on both paths. The four-block + per-cluster-H2
schema is shared verbatim between `research-artifact.md` and the existing `introspection.md` schema, so
the seed is a copy, not a translation.
**Alternatives considered:** (a) Point Phase 2 directly at `research.md` — rejected: forks the reader
into two code paths and couples plan to research's top-level sections. (b) Translate research's schema
into a new introspection schema — rejected: a translation step is where drift enters.
**Consequences:** Easier — Phase 2 untouched; ABSENT path is the existing sweep. Harder — the two schemas
must stay identical; a cross-phase consistency `[Verify]` (Phase 5) guards this.
**Charter alignment:** **NN-C-003** (backward-compatible; ABSENT path identical to today), **CR-009**
(heading hierarchy preserved so section extraction stays stable).

### ADR-3: Bump all four version-bearing files to 5.3.0 (resolve the skew now)
**Context:** `releasing.md` is the authoritative version-bearing-file list and names **four** files
(root `plugins/spec-flow/plugin.json`, `.claude-plugin/plugin.json`, `marketplace.json`, `CHANGELOG.md`).
The root `plugin.json` is stuck at **5.2.0** while the others are **5.2.1** — the 5.2.1 release missed it.
The spec's *Out of Scope* assigns "correcting the root vs `.claude-plugin` skew" to the later `sonnet-coord`
piece and says this piece does "the normal minor bump on the files it touches." AC-7's Independent Test
only checks `.claude-plugin/plugin.json` == `marketplace.json` (lenient). **NN-C-009** — which the spec's
*Non-Negotiables Honored* explicitly claims — requires bumping **all** version-bearing files.
**Decision (operator-confirmed):** Bump **all four** files to **5.3.0**. This honors NN-C-009 fully and
resolves the skew as a side effect; `sonnet-coord`'s NFR-004 skew task becomes a verified no-op.
**Alternatives considered:** Bump only three and leave root `plugin.json` at 5.2.0 per the spec's literal
Out-of-Scope wording — rejected by the operator: it violates NN-C-009 (a non-negotiable the spec claims
to honor) and widens the skew from a patch to a full minor (5.2.0 vs 5.3.0).
**Consequences:** Easier — single coherent NN-C-009-compliant bump; no lingering skew. Mild tension with
the spec's narrower Out-of-Scope phrasing, recorded here; no spec amendment is needed because bumping all
four is *more* consistent with the spec's own NN-C-009 claim than bumping three.
**Charter alignment:** **NN-C-009** (bump all version-bearing files), **NN-C-001** (plugin/marketplace sync),
**NN-C-007** (CHANGELOG entry).

### ADR-4: `research.md` is committed; `introspection.md` stays an untracked working artifact
**Context:** `research.md` must be readable by a fresh plan-stage context on the piece branch;
`introspection.md` is plan-local scratch.
**Decision:** Commit `research.md` to the piece branch (before `spec.md`). Leave `introspection.md`
untracked exactly as today.
**Alternatives considered:** Commit both — rejected: `introspection.md` is regenerated per plan run and
adds churn. Commit neither — rejected: plan in a fresh context could not find `research.md`.
**Consequences:** `research.md` survives across stages and contexts; `introspection.md` keeps its current
lifecycle. The `git log -1 --format=%H -- research.md` staleness anchor (FR-5) depends on `research.md`
being committed — this decision enables it.
**Charter alignment:** **NN-C-003** (additive; no existing on-disk layout broken).

## Phases

Each phase uses the **Implement track** (`[Implement]` → `[Verify]`, optional `[Refactor]`, `[QA]`).
No `[TDD-Red]`/`[Build]`/`[Write-Tests]` blocks — see Overview for the doc-as-code rationale.

## Integration-Test Registry (M1)

No integrations declared (spec *Integration Coverage*: "None in scope"). The only cross-component seam is
the `research.md` artifact; its correctness is held by the centralized schema in `research-artifact.md`
(Phase 1) and the cross-phase schema `[Verify]` in Phase 5. Absent registry ⇒ no `[Integration-Test]`
blocks in any phase (NFR-INT-02).

---

### Phase 1: Define the research-artifact contract
**Exit Gate:** `reference/research-artifact.md` exists and contains the `research.md` schema (two fixed
top-level headings + per-cluster H2 + four bold blocks), all three `[RESEARCH-*]` markers with triggers,
the ≤2K return contract, and the covered-file definition — all greppable.
**ACs Covered:** AC-3 (schema half)
**In scope:** CREATE `plugins/spec-flow/reference/research-artifact.md`
**NOT in scope:** the agent that implements this schema (Phase 2); the spec/plan citations of this file
(added in Phases 2/4/5; cross-checked in Phase 6); markers' *emission* in skills (Phases 4/5).
**Charter constraints honored in this phase:**
- CR-005 (repo-root-relative paths): every path the reference names (`agents/research.md`,
  `skills/spec/SKILL.md`, `skills/plan/SKILL.md`, `research.md`) is written repo-root-relative.
- CR-009 (heading hierarchy): the documented `research.md` schema has exactly one H1 and a clean H2/H3
  hierarchy; the four introspection blocks under per-cluster H2 are specified to match `introspection.md`
  verbatim so plan's section extraction stays stable.

- [x] **[Implement]** Author the artifact contract
  - Order: schema definition → marker contract → return contract → covered-file definition (each section
    is self-contained; natural commit checkpoints).
  - Architecture constraints: markdown only (NN-C-002); this file is the SINGLE source of truth — the
    agent and both skills cite it by path, so any schema detail lives here and nowhere else.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/reference/research-artifact.md`**
  - Structure outline (sections, in order):
    1. `# Research Artifact (research.md) — Contract` + a one-paragraph intro stating this is the single
       source of truth, cited by `plugins/spec-flow/agents/research.md`,
       `plugins/spec-flow/skills/spec/SKILL.md`, and `plugins/spec-flow/skills/plan/SKILL.md`.
    2. `## research.md structure` — define, with an annotated skeleton:
       - Two FIXED top-level headings, in this order: `## Brainstorm Inference Digest` then
         `## Codebase Conventions`.
       - Then one `## ` heading **per cluster** (clustered by functional cohesion of the files explored),
         each containing the four **bold-labelled** blocks in this exact order: `**File Inventory:**`,
         `**Dependency Map:**`, `**Test Landscape:**`, `**Pattern Catalog:**` — the identical
         cluster-grouped layout `introspection.md` uses today, with verbatim code blocks preserved.
       - State explicitly: "the research agent clusters by functional cohesion of the files it explores,
         since it has no finalized spec target list yet."
    3. `## Marker contract` — define all three markers with EXACT trigger conditions:
       - `[RESEARCH-UNAVAILABLE: <reason>]` — emitted by the **spec** skill when ANY of: the research
         agent returns `STATUS: BLOCKED`; the dispatch errors; or `research.md` is missing or zero-length
         after dispatch. Non-blocking; no `research.md` is committed on this path.
       - `[RESEARCH-CONSUMED: <N> files, <M> re-read]` — emitted by the **plan** skill Phase 1 when
         `research.md` exists on the piece branch. `N` = covered files; `M` = files re-read (targeted
         top-ups for non-covered spec targets + staleness re-reads).
       - `[RESEARCH-ABSENT: running full exploration]` — emitted by the **plan** skill Phase 1 when
         `research.md` does not exist on the piece branch.
    4. `## Return contract` — the agent returns a **≤2K-token** structured digest to the main thread
       (the on-disk `research.md` may be richer); the digest's FINAL line is exactly `STATUS: OK` or
       `STATUS: BLOCKED`.
    5. `## Covered file` — define: "a **covered file** is a file appearing in any cluster's
       `**File Inventory:**` block of `research.md`." (This is the input to FR-5's N/M counting.)
  - Pattern (heading/marker idiom already used across spec-flow references; mirror this house style):
    ```
    ### Conventions Block
    1. [shared] Surface the L-10 convention scan results ... record confirmed conventions in `### Codebase Conventions`; this protocol assumes L-10 has already run.
    ```
  - Done: the file exists with all five sections; the two fixed top-level heading strings, the four bold
    block labels, the three marker strings, the ≤2K + STATUS contract, and the covered-file definition
    are all present as literal greppable text.
  - Verify: see `[Verify]` below.

- [x] **[Verify]** Confirm the contract is complete and greppable
  **Per-change checks (T-1):**
  - Run: `grep -c -e '## Brainstorm Inference Digest' -e '## Codebase Conventions' plugins/spec-flow/reference/research-artifact.md` — Expected: `2` (both fixed top-level headings present).
  - Run: `grep -c -e 'File Inventory' -e 'Dependency Map' -e 'Test Landscape' -e 'Pattern Catalog' plugins/spec-flow/reference/research-artifact.md` — Expected: ≥ `4` (all four block labels present).
  - Run: `grep -c -e 'RESEARCH-UNAVAILABLE' -e 'RESEARCH-CONSUMED' -e 'RESEARCH-ABSENT' plugins/spec-flow/reference/research-artifact.md` — Expected: ≥ `3` (all three markers present).
  - Run: `grep -niE 'STATUS: OK|STATUS: BLOCKED' plugins/spec-flow/reference/research-artifact.md` — Expected: ≥1 match (return contract present).
  - LLM-agent-step: read `plugins/spec-flow/reference/research-artifact.md` and confirm the `## Covered file` section defines a covered file as "a file appearing in any cluster's File Inventory block of research.md." — Expected: the definition is present and unambiguous.
  **Phase-level check:**
  - LLM-agent-step: read `plugins/spec-flow/reference/research-artifact.md` and confirm it parses as valid markdown with exactly one H1 and a clean H2/H3 hierarchy (CR-009). — Expected: one `# ` heading; all other headings `##`/`###`.
  - Failure: any of the grep counts below target, or a missing/duplicated H1.

- [x] **[QA]** Phase review
  - Review against: AC-3 (schema half)
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 2: Create the research agent
**Exit Gate:** `agents/research.md` exists with `name: research` + `model: opus`, mandates a ≤2K return
ending `STATUS: OK|BLOCKED`, contains no conversation-history assumptions, instructs against transcribing
secrets, dispatches no sub-agents, and cites `reference/research-artifact.md`.
**ACs Covered:** AC-2 (full), AC-3 (citation #1 of 3)
**In scope:** CREATE `plugins/spec-flow/agents/research.md`
**NOT in scope:** the contract definition itself (Phase 1 — this agent IMPLEMENTS it); the dispatch site
that calls this agent (Phase 4); plan-side consumption (Phase 5).
**Charter constraints honored in this phase:**
- NN-C-002 (markdown + config only): the agent is a markdown prompt; it introduces no runtime dependency.
- NN-C-004 (bare agent name): frontmatter `name:` is `research` (no plugin prefix).
- NN-C-008 (self-contained prompts): the prompt receives every input by injection and assumes no
  conversation history (it runs before brainstorm).
- CR-001 (agent frontmatter schema): frontmatter carries `name:` + `description:` (+ `model:`).
- CR-008 (narrow agent): the agent performs the single gathering task and dispatches no sub-agents.

- [x] **[Implement]** Author the research agent
  - Order: frontmatter → role/single-task statement → injected-inputs contract → gathering procedure →
    output contract (write `research.md`) → return digest + STATUS → no-secrets + no-sub-dispatch guards.
  - Architecture constraints: self-contained (NN-C-008); writes `research.md` to the worktree it is
    dispatched into; returns only the ≤2K digest; cites `reference/research-artifact.md` as the schema
    authority rather than restating the schema (single-source discipline).

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/agents/research.md`**
  - Frontmatter (exact):
    ```
    ---
    name: research
    description: "Internal agent — dispatched by spec-flow:spec before brainstorm. Do NOT call directly. Isolated Opus codebase-gathering pass: reads the codebase against the piece's PRD sections, writes research.md, and returns a ≤2K-token structured digest. Dispatches no sub-agents."
    model: opus
    ---
    ```
  - Body sections (prose; the executor writes the actual instructions):
    1. **Role / single task.** One isolated gathering pass. State: "You perform codebase gathering only.
       You dispatch NO sub-agents." (CR-008)
    2. **Injected inputs (no history).** State that every input — the piece's PRD sections, the piece
       description from the manifest, and the resolved charter — is provided in THIS prompt by the
       dispatching skill; the agent assumes no prior conversation. Use NO phrases like "as discussed",
       "from the brainstorm above", "you already know", "per my previous" (NN-C-008, AC-2 negative grep).
    3. **Gathering procedure.** Explore the codebase relevant to the PRD sections; **cluster files by
       functional cohesion** (no finalized spec target list exists yet).
    4. **Output contract — write `research.md`.** Write the file in the EXACT layout defined in
       `plugins/spec-flow/reference/research-artifact.md` — link that path explicitly. Two fixed
       top-level sections (`## Brainstorm Inference Digest`, `## Codebase Conventions`) followed by
       per-cluster H2 headings each with the four bold blocks; preserve verbatim code blocks.
    5. **No secrets (NFR-3).** Explicit instruction: summarize source; NEVER transcribe credentials,
       tokens, API keys, or other secrets verbatim into `research.md`.
    6. **Return contract.** Return a ≤2K-token structured digest to the main thread (the on-disk file may
       be richer); the FINAL line of the return is exactly `STATUS: OK` (wrote `research.md`) or
       `STATUS: BLOCKED` (could not complete — include the reason). Cite `research-artifact.md` for the
       return contract.
  - Pattern (agent frontmatter house style, from `plugins/spec-flow/agents/qa-plan.md:1-4`):
    ```
    ---
    name: qa-plan
    description: "Internal agent — dispatched by spec-flow:plan. Do NOT call directly. Adversarial Opus review of an implementation plan before execute begins. ... Read-only — never modifies files."
    ---
    ```
  - Done: `agents/research.md` exists; frontmatter has bare `name: research` + `model: opus`; body covers
    all six sections; cites `reference/research-artifact.md`; contains an explicit no-secrets instruction;
    contains no `Agent(` sub-dispatch and no conversation-history phrases.
  - Verify: see `[Verify]` below.

- [x] **[Verify]** Confirm the agent meets the AC-2 contract
  **Per-change checks (T-1):**
  - Run: `grep -E '^name:[[:space:]]*research$' plugins/spec-flow/agents/research.md` — Expected: 1 match.
  - Run: `grep -E '^model:[[:space:]]*opus$' plugins/spec-flow/agents/research.md` — Expected: 1 match.
  - Run: `grep -niE 'STATUS: OK|STATUS: BLOCKED' plugins/spec-flow/agents/research.md` — Expected: ≥1 match (return contract).
  - Run: `grep -niE '≤ ?2k|2,?000 token|2k token|2k-token' plugins/spec-flow/agents/research.md` — Expected: ≥1 match (bounded-return statement).
  - Run: `grep -niE 'as discussed|from the brainstorm above|you already know|per my previous' plugins/spec-flow/agents/research.md` — Expected: **no output** (NN-C-008).
  - Run: `grep -nE 'Agent\(' plugins/spec-flow/agents/research.md` — Expected: **no output** (CR-008, no sub-dispatch).
  - Run: `grep -niE 'secret|credential|token|api key' plugins/spec-flow/agents/research.md` — Expected: ≥1 match (no-secrets instruction present); confirm by reading that the match is a "do NOT transcribe secrets" instruction, not an incidental mention.
  - Run: `grep -l 'reference/research-artifact.md' plugins/spec-flow/agents/research.md` — Expected: the file path (citation #1 present).
  **Phase-level check:**
  - LLM-agent-step: read `plugins/spec-flow/agents/research.md` end-to-end and confirm all six body
    sections are present and the prompt is self-contained (no reliance on prior turns). — Expected: all
    six present; self-contained.
  - Failure: any grep above off-target (especially a non-empty result for the two "no output" greps).

- [x] **[QA]** Phase review
  - Review against: AC-2, AC-3 (citation #1)
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 3: Make L-10 the fallback path in brainstorm-procedure.md
**Exit Gate:** `brainstorm-procedure.md` describes L-10 as the UNAVAILABLE-path fallback, dual-sources the
Conventions Block (research.md on OK path / L-10 on UNAVAILABLE path), and its invocation order accounts
for the pre-brainstorm research dispatch.
**ACs Covered:** AC-4 (the brainstorm-procedure half; the spec/SKILL.md half is Phase 4)
**In scope:** MODIFY `plugins/spec-flow/reference/brainstorm-procedure.md` (invocation order; Conventions
Block input source; L-10 conditionality)
**NOT in scope:** `skills/spec/SKILL.md` edits (Phase 4); creating the research agent (Phase 2).
<!-- P2/P3 omitted: brainstorm-procedure.md is a reference doc, not a multi-step orchestration SKILL.md (no `### Step|Phase|Sub-Phase` headings). -->
**Charter constraints honored in this phase:**
- (none uniquely allocated — this phase supports FR-3/FR-4 wiring; all NN-C/CR/NN-P entries are
  allocated to Phases 1/2/4/5/6.)

- [x] **[Implement]** Reframe L-10 as conditional and dual-source the Conventions Block
  - Order: invocation order (T-1) → Conventions Block source (T-2) → L-10 conditionality (T-3).
  - Architecture constraints: keep this file and `skills/spec/SKILL.md` (Phase 4) in agreement on the
    OK/UNAVAILABLE branch and the Conventions-Block input source — they are a cross-phase pair.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/reference/brainstorm-procedure.md`**
  - Anchor: `Invocation order:` (lines 3-7)
  - Current:
    ```
    3  Invocation order:
    4  1. Charter Context Loading Protocol — run first; outputs `charter_root`, `charter_snapshot`, `integration_cfg`
    5  2. L-10 Convention Context Scan (from Core Brainstorm Building Blocks) — runs before any questions; outputs conventions list
    6  3. Charter Constraint Identification Protocol — runs after L-10; uses L-10 results for conventions block
    7  4. Remaining Core Brainstorm Building Blocks (C-2 always-run, C-3, Approach+Tradeoffs) — run during brainstorm session
    ```
  - Target: Insert the research pass into the order and make L-10 conditional. The reordered list (the
    spec skill owns worktree creation + research dispatch — this list documents the convention source):
    `1.` Charter Context Loading Protocol (unchanged); `2.` **Research pass** — the spec skill creates
    the worktree and dispatches the research agent before any questions; on `STATUS: OK` its
    `## Codebase Conventions` section supplies conventions; `3.` **L-10 Convention Context Scan — runs
    only on the `[RESEARCH-UNAVAILABLE]` path** (the fallback when research did not produce conventions);
    `4.` Charter Constraint Identification Protocol — its Conventions Block consumes `research.md`'s
    `## Codebase Conventions` on the OK path, or L-10's output on the UNAVAILABLE path; `5.` Remaining
    Core Brainstorm Building Blocks (unchanged).
  - Pattern (numbered-list idiom already in the file — preserve format):
    ```
    Invocation order:
    1. Charter Context Loading Protocol — run first; outputs ...
    2. ...
    ```
  - Done: the invocation order lists the research pass before L-10 and marks L-10 as the
    `[RESEARCH-UNAVAILABLE]`-only fallback.
  - Verify: `grep -niE 'RESEARCH-UNAVAILABLE|research pass|research agent' brainstorm-procedure.md` — match present in the invocation order region.

  **T-2: MODIFY `plugins/spec-flow/reference/brainstorm-procedure.md`**
  - Anchor: `### Conventions Block` (lines 50-51)
  - Current:
    ```
    50  ### Conventions Block
    51  1. [shared] Surface the L-10 convention scan results before confirmation closes, ask the user whether those empirical conventions should be required, and record confirmed conventions in `### Codebase Conventions`; this protocol assumes L-10 has already run.
    ```
  - Target: Rewrite step 1 to dual-source the conventions input: "Surface the convention scan results
    before confirmation closes — on the `[RESEARCH-...]` OK path these come from `research.md`'s
    `## Codebase Conventions` section; on the `[RESEARCH-UNAVAILABLE]` path they come from the standalone
    L-10 scan. Ask the user whether those empirical conventions should be required, and record confirmed
    conventions in `### Codebase Conventions`." Keep the surrounding numbering.
  - Pattern: (same Conventions Block block shown above)
  - Done: the Conventions Block names BOTH input sources (research.md OK path; L-10 UNAVAILABLE path).
  - Verify: `grep -A2 '### Conventions Block' brainstorm-procedure.md` shows both `research.md` and an L-10/UNAVAILABLE reference.

  **T-3: MODIFY `plugins/spec-flow/reference/brainstorm-procedure.md`**
  - Anchor: `### L-10: Convention Context Scan` (lines 60-61)
  - Current:
    ```
    60  ### L-10: Convention Context Scan
    61  [shared] Before the first brainstorm question, dispatch an explore agent to scan 2–3 peer components of the same type and extract empirical conventions such as file structure, wrappers, naming patterns, and shared config idioms. Surface the resulting conventions list during charter-constraint confirmation. If no peer component exists, skip L-10 silently.
    ```
  - Target: Prepend a conditionality clause: "**Runs only on the `[RESEARCH-UNAVAILABLE]` path** — when
    the research agent produced no `research.md` (its `## Codebase Conventions` section is the OK-path
    source). On the UNAVAILABLE path: before the first brainstorm question, dispatch an explore agent
    to scan 2–3 peer components ..." (keep the rest of the existing sentence). Retain "If no peer
    component exists, skip L-10 silently."
  - Pattern: (same L-10 block shown above)
  - Done: the L-10 section opens by stating it runs only on the UNAVAILABLE path.
  - Verify: `grep -A1 '### L-10: Convention Context Scan' brainstorm-procedure.md` shows the `[RESEARCH-UNAVAILABLE]`-only conditionality.

- [x] **[Verify]** Confirm L-10 is conditional and the Conventions Block is dual-sourced
  **Per-change checks:**
  - T-1: `grep -niE 'RESEARCH-UNAVAILABLE' plugins/spec-flow/reference/brainstorm-procedure.md` — Expected: ≥2 matches (invocation order + L-10 section).
  - T-2: LLM-agent-step: read the `### Conventions Block` section and confirm it names `research.md`'s `## Codebase Conventions` as the OK-path source and the L-10 scan as the UNAVAILABLE-path source. — Expected: both sources named.
  - T-3: LLM-agent-step: read the `### L-10: Convention Context Scan` section and confirm it states L-10 runs only on the `[RESEARCH-UNAVAILABLE]` path. — Expected: conditional clause present.
  **Phase-level check:**
  - LLM-agent-step: read `plugins/spec-flow/reference/brainstorm-procedure.md` and confirm it parses as
    valid markdown and that the OK/UNAVAILABLE branch described here is consistent with itself (no
    contradiction between the invocation order, the Conventions Block, and the L-10 section). — Expected: consistent.
  - Failure: L-10 still described as unconditional, or the Conventions Block names only one source.

- [x] **[QA]** Phase review
  - Review against: AC-4 (brainstorm-procedure half)
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 4: Reorder the spec skill (worktree + research before brainstorm)
**Exit Gate:** `spec/SKILL.md` performs the decomposition scope-check + slug validation, creates the
worktree/branch, dispatches the research agent, and commits `research.md` — all before the first
brainstorm question; emits `[RESEARCH-UNAVAILABLE: <reason>]` with all three triggers on failure
(non-blocking, no `research.md` commit) and runs the standalone L-10 scan ONLY on that path; wires the
Conventions Block to `research.md` on the OK path; the `research.md` commit precedes the `spec.md` commit.
**ACs Covered:** AC-1 (commit ordering), AC-4 (spec/SKILL.md half), AC-3 (citation #2 of 3)
**In scope:** MODIFY `plugins/spec-flow/skills/spec/SKILL.md` — move gitignore/slug/worktree out of Phase
3 into a new pre-brainstorm block in Phase 2; add research dispatch + `research.md` commit + UNAVAILABLE
fallback; make the Phase-2 L-10 step conditional; retitle Phase 3 to "Write Spec"; cite
`reference/research-artifact.md`.
**NOT in scope:** `brainstorm-procedure.md` edits (Phase 3); plan-skill consumption (Phase 5); the agent
file itself (Phase 2); version bump (Phase 6).
**Why serial:** kept as a serial flat phase (not parallelized with the disjoint Phase 5 plan-skill edit)
to preserve per-phase Opus QA on this load-bearing reorder — the operator chose Standard mode
specifically so the spec-skill restructure gets phase-by-phase adversarial review.
**Steps traversed (P2):** the new pre-brainstorm path inserts between the Phase-2 decomposition
scope-check (line 84) and the first brainstorm question (step 1, line 104), and traverses / invalidates:
the Phase-2 `[Convention context]` L-10 step (88-91, now conditional); brainstorm step 1a Charter
Constraint Identification Protocol (105-111, whose Conventions Block now sources `research.md`);
brainstorm step 3 "lead with your understanding" (114, now seeded by the digest); Phase 3 (138, worktree
creation removed → "Write Spec" only); Phase 5 spec commit (204-208, which the new `research.md` commit
must precede).
**Dispatch sites (P3):** one — the new pre-brainstorm research-agent dispatch added in Phase 2 of
`spec/SKILL.md`. The `research` agent is introduced by this piece and has no other dispatch site.
**Charter constraints honored in this phase:**
- NN-P-001 (human approval gate never removed): the reorder moves only setup (worktree, research) earlier;
  the spec sign-off gate in Phase 4/5 is untouched — the human still approves the spec.

- [x] **[Implement]** Move setup earlier and insert the research pass
  - Order: insert pre-brainstorm setup block (T-1) → make L-10 conditional (T-2) → strip moved steps from
    Phase 3 + retitle (T-3). Each is a clean checkpoint.
  - Architecture constraints: the `research.md` commit MUST be a distinct commit created BEFORE the
    `spec.md` commit (AC-1 ancestor guarantee). The UNAVAILABLE path commits NO `research.md`. Cite
    `reference/research-artifact.md` for the marker/return/schema contract rather than restating it
    (single-source discipline, CR-008 thin orchestrator). Keep agreement with `brainstorm-procedure.md`
    (Phase 3) on the OK/UNAVAILABLE branch.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** — insert pre-brainstorm setup + research block
  - Anchor: end of the decomposition scope-check paragraph, Phase 2 (line 84)
  - Current:
    ```
    84  **Before the first question — scope check.** Assess whether the piece as described covers multiple independent subsystems ... Propose the decomposition, let the user confirm the sub-piece ordering, and brainstorm only the first sub-piece.
    85
    86  **YAGNI throughout.** ...
    ```
  - Target: Immediately after line 84 (after the scope-check, before YAGNI/L-10/questions), insert a new
    bolded block, e.g. `**[Pre-brainstorm setup — worktree + research]** *(runs after the scope-check,
    before any question)*:` containing, in order:
    1. **gitignore check** — "Check if `worktrees/` is in `.gitignore` — add it if missing." (moved
       verbatim from Phase 3 step 1, line 140.)
    2. **slug validation** — the full slug-validation step (moved verbatim from Phase 3 step 2, line 141;
       cites `reference/slug-validator.md`, same refusal contract).
    3. **worktree/branch creation** — the full `feature_branch:` logic (moved verbatim from Phase 3 step
       3, lines 142-151), including both `git worktree add {{worktree_root}} -b piece/<prd-slug>-<piece-slug> [<feature_branch>]` branches.
    4. **research dispatch** — dispatch the `research` agent into the worktree:
       ```
       Agent({ name: "research", model: "opus", prompt: <self-contained: this piece's PRD sections + the manifest piece description + the resolved charter>, ... })
       ```
       The schema/markers/return/≤2K contract live in `plugins/spec-flow/reference/research-artifact.md`
       — cite it; do not restate it.
    5. **OK path** — if the agent returns `STATUS: OK` and `research.md` is present and non-empty: commit
       it on the piece branch BEFORE any spec write:
       ```bash
       git add docs/prds/<prd-slug>/specs/<piece-slug>/research.md
       git commit -m "research: add <prd-slug>/<piece-slug> codebase research"
       ```
       The brainstorm then leads with the digest's inferences (the existing "lead with your understanding"
       pattern, step 3, seeded by the digest), and the Charter Constraint Identification Protocol's
       Conventions Block consumes `research.md`'s `## Codebase Conventions` (per `brainstorm-procedure.md`).
    6. **UNAVAILABLE path** — emit `[RESEARCH-UNAVAILABLE: <reason>]` and fall back **non-blocking** when
       ANY of these three triggers holds: the agent returns `STATUS: BLOCKED`; the dispatch errors; or
       `research.md` is missing or zero-length after dispatch. On this path commit NO `research.md`, and
       run the standalone L-10 convention scan (whose output the Conventions Block then consumes, exactly
       as today). Cite `reference/research-artifact.md` for the marker definition.
  - Pattern (git-commit fence idiom already in the skill, from `spec/SKILL.md:204-208`):
    ```
    3. Commit spec on worktree branch:
       ```bash
       git add docs/prds/<prd-slug>/specs/<piece-slug>/spec.md
       git commit -m "spec: add <prd-slug>/<piece-slug> specification"
       ```
    ```
  - Done: a pre-brainstorm block exists after line 84 with all six elements; the `research.md` commit is
    a distinct commit; all three UNAVAILABLE triggers are enumerated; the block cites
    `reference/research-artifact.md`.
  - Verify: see `[Verify]` (commit-ordering + triggers + citation).

  **T-2: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** — make the Phase-2 L-10 step conditional
  - Anchor: `**[Convention context]** *(L-10 — runs before any questions)*` (lines 88-91)
  - Current:
    ```
    88  **[Convention context]** *(L-10 — runs before any questions)*: Run the L-10 Convention Context Scan
    89  specified in `plugins/spec-flow/reference/brainstorm-procedure.md` per the reference doc's
    90  "## Core Brainstorm Building Blocks" section ("### L-10: Convention Context Scan"). Outputs:
    91  conventions list surfaced in step 1a.
    ```
  - Target: Rewrite to make L-10 conditional: "*(L-10 — runs only on the `[RESEARCH-UNAVAILABLE]`
    path)*: On the OK path, the conventions list comes from `research.md`'s `## Codebase Conventions`
    section (written by the pre-brainstorm research pass), and the standalone L-10 scan is skipped. Only
    on the `[RESEARCH-UNAVAILABLE]` path, run the L-10 Convention Context Scan specified in
    `plugins/spec-flow/reference/brainstorm-procedure.md` ...". Keep the "Outputs: conventions list
    surfaced in step 1a" tail.
  - Pattern: (same `[Convention context]` block above)
  - Done: the L-10 step is explicitly conditional, naming research.md as the OK-path source and L-10 as
    the UNAVAILABLE-path source.
  - Verify: `grep -n 'RESEARCH-UNAVAILABLE' spec/SKILL.md` matches in the `[Convention context]` region.

  **T-3: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** — strip moved steps from Phase 3 + retitle
  - Anchor: `### Phase 3: Create Worktree and Write Spec` (lines 138-151)
  - Current:
    ```
    138  ### Phase 3: Create Worktree and Write Spec
    139
    140  1. Check if `worktrees/` is in `.gitignore` — add it if missing
    141  2. **Validate slugs before any branch or worktree creation.** ...
    142  3. Create worktree (before writing, so all work lives on the feature branch). ...
    ...  (143-151: feature_branch branches + git worktree add)
    152  4. Write `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/spec.md` ...
    ```
  - Target: Retitle to `### Phase 3: Write Spec`. REMOVE steps 1-3 (gitignore, slug validation, worktree
    creation — now performed pre-brainstorm in Phase 2 via T-1). Renumber the remaining steps so the
    former step 4 (write spec.md, line 152) becomes step 1 and the former step 5 (template, line 157)
    becomes step 2. Add a one-line note at the top: "The worktree/branch already exist (created
    pre-brainstorm in Phase 2); this phase only writes `spec.md`." Leave the dependency-triage branching
    (former step 4 body, lines 152-156) intact.
  - Pattern: (n/a — deletion + renumber)
  - Done: Phase 3 heading reads "Write Spec"; no gitignore/slug/worktree steps remain in Phase 3; the
    spec-write + template steps survive, renumbered; a note points back to the Phase-2 setup.
  - Verify: `grep -n '### Phase 3' spec/SKILL.md` shows "Write Spec"; `git worktree add` no longer appears in the Phase 3 region.

- [x] **[Verify]** Confirm the reorder, the commit ordering, and the UNAVAILABLE contract
  **Per-change checks:**
  - T-1 (setup moved before brainstorm): LLM-agent-step — read `spec/SKILL.md` and confirm the
    worktree-creation step (`git worktree add`), the slug-validation step, and the research-dispatch step
    all appear in Phase 2 BEFORE brainstorm step 1 (line ~104 "State the piece scope"). — Expected: all
    three precede the first brainstorm question.
  - T-1 (commit ordering, AC-1): Run: `grep -nE 'git commit -m "research:|git commit -m "spec:' plugins/spec-flow/skills/spec/SKILL.md` — Expected: the `research:` commit line number is LESS THAN the `spec:` commit line number (research.md is committed before spec.md in skill order).
  - T-1 (UNAVAILABLE triggers): LLM-agent-step — read the pre-brainstorm block and confirm
    `[RESEARCH-UNAVAILABLE: <reason>]` is emitted on ALL THREE triggers (STATUS: BLOCKED; dispatch error;
    missing/zero-length research.md), is non-blocking, and commits no research.md. — Expected: all three
    triggers enumerated; non-blocking; no commit on this path.
  - T-1 (citation, AC-3 #2): Run: `grep -l 'reference/research-artifact.md' plugins/spec-flow/skills/spec/SKILL.md` — Expected: the file path (citation #2 present).
  - T-2 (L-10 conditional): Run: `grep -n 'RESEARCH-UNAVAILABLE' plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥2 matches (pre-brainstorm block + `[Convention context]` step).
  - T-3 (Phase 3 retitled, steps moved): Run: `grep -n 'git worktree add' plugins/spec-flow/skills/spec/SKILL.md` — Expected: the match(es) are in the Phase-2 region, NOT under `### Phase 3`. And `grep -n '### Phase 3: Write Spec' spec/SKILL.md` — Expected: 1 match.
  **Phase-level check:**
  - LLM-agent-step: read `spec/SKILL.md` Phase 2–3 and `brainstorm-procedure.md` (Phase 3 of this plan)
    together and confirm both branches (OK / UNAVAILABLE) are enumerated and agree on the Conventions-Block
    input source. — Expected: consistent across both files.
  - Failure: research commit after spec commit; any UNAVAILABLE trigger missing; worktree step still under Phase 3.

- [x] **[Refactor]** (optional) Tidy renumbering / cross-references introduced by the move
  - Check for: stale "Phase 3 creates the worktree" references elsewhere in `spec/SKILL.md`; broken step
    numbers after the deletion.
  - Constraint: only modify `plugins/spec-flow/skills/spec/SKILL.md`.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-4 (spec/SKILL.md half), AC-3 (citation #2)
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 5: Plan-skill consume — CONSUMED / ABSENT branch
**Exit Gate:** `plan/SKILL.md` Phase 1 branches on `research.md` existence: on CONSUMED it emits
`[RESEARCH-CONSUMED: <N> files, <M> re-read]`, seeds `introspection.md` by structural copy of
`research.md` (skipping the full per-cluster sweep), targeted-tops-up non-covered spec target files, and
re-reads stale covered files via the `git log`/`git diff` anchor; on ABSENT it emits
`[RESEARCH-ABSENT: running full exploration]` and runs the legacy sweep unchanged. Phase 2's reader is
unchanged on both paths. A concrete worked example of the N/M seeding algorithm is present.
**ACs Covered:** AC-5 (CONSUMED), AC-6 (ABSENT), AC-3 (citation #3 of 3)
**In scope:** MODIFY `plugins/spec-flow/skills/plan/SKILL.md` Phase 1 — insert the CONSUMED/ABSENT branch
after the introspection.md introduction (after line 91) and before cluster identification (line 93); cite
`reference/research-artifact.md`.
**NOT in scope:** Phase 2's section-by-section reader (must stay byte-for-byte unchanged); spec-skill
edits (Phase 4); version bump (Phase 6).
<!-- P2/P3 below: plan/SKILL.md is a multi-step orchestration file (### Phase 1–4). -->
**Steps traversed (P2):** the new CONSUMED branch inserts inside Phase 1, after the "Exploration
Deliverable: Code Introspection Report → introspection.md" intro (line 91) and before "Cluster
identification" (line 93); it traverses / gates the existing per-cluster exploration loop (95-103, which
becomes the ABSENT-path body) and the Resume paragraph (105-107); it feeds the unchanged Phase 2 reader
(113). It does NOT alter Phase 1 step 1a dependency check (63-65) or the charter-drift check (67-68).
**Dispatch sites (P3):** none — plan Phase 1 exploration runs in the main thread and dispatches no agents;
the research agent is dispatched only by `spec/SKILL.md` (Phase 4), never by plan.
**Charter constraints honored in this phase:**
- NN-C-003 (backward compatibility within a major): the ABSENT path reproduces today's behavior exactly
  (legacy per-cluster sweep + unchanged Phase 2 reader); a piece specced before this feature still plans
  correctly (additive). This is the piece's NFR-2 / PRD NFR-003 carrier.

- [x] **[Implement]** Insert the CONSUMED/ABSENT branch
  - Order: file-existence branch + markers → CONSUMED seeding algorithm + worked example → ABSENT legacy
    pointer → citation. Each is a clean checkpoint.
  - Architecture constraints: the four-block per-cluster-H2 schema in `research.md` is IDENTICAL to the
    existing `introspection.md` schema (so the seed is a copy, not a translation — ADR-2); the Phase 2
    reader must not change; cite `reference/research-artifact.md` for the schema, markers, and covered-file
    definition rather than restating them.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/plan/SKILL.md`** — CONSUMED/ABSENT branch
  - Anchor: between the introspection.md introduction (line 91) and "Cluster identification" (line 93)
  - Current:
    ```
    89  #### Exploration Deliverable: Code Introspection Report → `introspection.md`
    90
    91  Phase 1 writes exploration findings incrementally to `introspection.md` in the piece's working directory (alongside plan.md). The file is a working artifact — not committed, not gitignored, just untracked.
    92
    93  **Cluster identification.** Before exploring, group the spec's target files by functional cohesion ...
    ```
  - Target: Immediately after line 91 (before "Cluster identification"), insert a new bolded
    **research-source branch** that gates the per-cluster sweep below it on the existence of `research.md`
    on the piece branch. Encode the branch precisely:
    - **CONSUMED path (research.md exists on the piece branch):**
      1. Emit `[RESEARCH-CONSUMED: <N> files, <M> re-read]`.
      2. **Seed `introspection.md` by structural copy** of `research.md`'s cluster-grouped sections —
         state explicitly: "do not run the full per-cluster sweep below when `research.md` is present."
      3. For each spec target file that is **not a covered file** (per the covered-file definition in
         `reference/research-artifact.md`), perform a **narrow targeted read (not a full sweep)** and
         append its four-block entry to `introspection.md`.
      4. Resolve the research commit: `git log -1 --format=%H -- research.md`; for each covered file
         changed since that commit (`git diff <commit>..HEAD -- <file>` non-empty), re-read it and update
         its `introspection.md` entry.
      5. Define the counts: `N` = covered files; `M` = files re-read via steps 3 + 4.
    - **ABSENT path (research.md does not exist on the piece branch):**
      1. Emit `[RESEARCH-ABSENT: running full exploration]`.
      2. Run the existing per-cluster sweep (the "Cluster identification" + "Per-cluster exploration loop"
         below) **unchanged**.
    - State, in both branches, that **Phase 2 then reads the resulting `introspection.md` section-by-section
      with no change to its reader.**
    - **Worked example (REQUIRED — dense-algorithm guard).** Immediately after the CONSUMED step list,
      include a concrete inline trace with ACTUAL values, e.g. as an HTML comment or fenced block:
      ```
      <!-- Example: spec targets = [a.md, b.md, c.md, d.md]. research.md File Inventory blocks cover
      [a.md, b.md, c.md] (N=3). d.md is not covered → targeted read of d.md, append its four-block entry.
      `git log -1 --format=%H -- research.md` = e4f1a2c; `git diff e4f1a2c..HEAD -- a.md` is non-empty
      (a.md changed since research) → re-read a.md, update its entry. b.md, c.md unchanged → skipped.
      Re-reads = {d.md (top-up), a.md (staleness)} → M=2. Emit: [RESEARCH-CONSUMED: 3 files, 2 re-read]. -->
      ```
  - Pattern (marker + bolded-step idiom already used in plan Phase 1; the per-cluster loop, lines 95-103):
    ```
    **Per-cluster exploration loop.** For each cluster, in dependency order (inner-most first):
    1. **Explore** — read the cluster's files, resolve callers/callees, scan test coverage.
    2. **Append** — write four sections to `introspection.md` under an H2 heading for the cluster: ...
    ```
  - Done: a file-existence branch gates the sweep; both markers present with exact format; the CONSUMED
    seeding algorithm (seed → top-up → staleness) is spelled out with the `git log`/`git diff` anchors and
    the N/M definitions; the worked example with real values is present; both branches state the Phase 2
    reader is unchanged.
  - Verify: see `[Verify]`.

  **T-2: MODIFY `plugins/spec-flow/skills/plan/SKILL.md`** — citation
  - Anchor: the new branch text (from T-1)
  - Current: (new text from T-1)
  - Target: ensure the new branch cites `plugins/spec-flow/reference/research-artifact.md` for the schema,
    the three markers, and the covered-file definition (single-source discipline).
  - Pattern: existing reference-citation idiom, e.g. `per `plugins/spec-flow/reference/<doc>.md``.
  - Done: `reference/research-artifact.md` is cited in plan/SKILL.md (AC-3 citation #3).
  - Verify: `grep -l 'reference/research-artifact.md' plugins/spec-flow/skills/plan/SKILL.md`.

- [x] **[Verify]** Confirm the branch, the seeding algorithm, and the unchanged reader
  **Per-change checks:**
  - T-1 (markers): Run: `grep -nE 'RESEARCH-CONSUMED: <N> files, <M> re-read|RESEARCH-ABSENT: running full exploration' plugins/spec-flow/skills/plan/SKILL.md` — Expected: both marker strings present.
  - T-1 (no-sweep instruction): Run: `grep -niE 'do not run the full per-cluster sweep|seed .*introspection.md.* from .*research.md' plugins/spec-flow/skills/plan/SKILL.md` — Expected: ≥1 match (explicit seed-not-sweep instruction).
  - T-1 (staleness anchor): Run: `grep -nE 'git log -1 --format=%H -- research.md' plugins/spec-flow/skills/plan/SKILL.md` — Expected: 1 match. And `grep -nE 'git diff .*\.\.HEAD' plugins/spec-flow/skills/plan/SKILL.md` — Expected: ≥1 match in the CONSUMED branch.
  - T-1 (worked example present — dense-algorithm guard): Run: `grep -nE 'RESEARCH-CONSUMED: 3 files, 2 re-read' plugins/spec-flow/skills/plan/SKILL.md` — Expected: 1 match (the concrete N/M trace with actual values). [If the executor uses different example values, the LLM-agent-step below confirms a concrete trace exists.]
  - T-1 (Phase 2 reader unchanged): LLM-agent-step — read plan/SKILL.md `### Phase 2: Generate Plan` opening (line ~111-114) and confirm its "reading section-by-section" instruction is UNCHANGED from the pre-edit text (`git diff` of that region is empty). — Expected: no change to the Phase 2 reader.
  - T-2 (citation, AC-3 #3): Run: `grep -l 'reference/research-artifact.md' plugins/spec-flow/skills/plan/SKILL.md` — Expected: the file path.
  **Cross-phase schema-consistency check (ADR-2 / plan §2d):**
  - LLM-agent-step: read the four bold block labels in `plugins/spec-flow/reference/research-artifact.md`
    (Phase 1) and the four-block list in plan/SKILL.md's per-cluster loop (lines 99-102) and confirm they
    are the SAME four labels in the SAME order (`File Inventory`, `Dependency Map`, `Test Landscape`,
    `Pattern Catalog`) — proving the CONSUMED-path structural copy is valid, not a translation. — Expected:
    identical four labels + per-cluster H2 grouping in both files.
  - Run: `grep -c -e 'File Inventory' -e 'Dependency Map' -e 'Test Landscape' -e 'Pattern Catalog' plugins/spec-flow/reference/research-artifact.md plugins/spec-flow/skills/plan/SKILL.md` — Expected: both files report ≥4 (schema present in both).
  **Phase-level check:**
  - LLM-agent-step: read plan/SKILL.md Phase 1 and confirm the file-existence branch is unambiguous
    (present → CONSUMED; absent → ABSENT) and that the ABSENT path preserves the legacy sweep text verbatim.
    — Expected: clean two-way branch; ABSENT == legacy.
  - Failure: a marker missing/mis-formatted; the seed-not-sweep instruction absent; the Phase 2 reader changed; the four labels diverging between the two files.

- [x] **[QA]** Phase review
  - Review against: AC-5, AC-6, AC-3 (citation #3), NFR-2
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

### Phase 6: Path convention + version sync (5.3.0)
**Exit Gate:** `v3-path-conventions.md` references `research.md` (file) not `research/` (directory); all
four version-bearing files read `5.3.0`; `.claude-plugin/plugin.json` == `marketplace.json`; CHANGELOG has
a new `## [5.3.0]` section with ≥1 bullet; all three `reference/research-artifact.md` citations (agent +
both skills) are present.
**ACs Covered:** AC-7 (path + version), AC-3 (final citation cross-check)
**In scope:** MODIFY `plugins/spec-flow/reference/v3-path-conventions.md`; bump `plugins/spec-flow/plugin.json`,
`plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (spec-flow entry) to
`5.3.0`; prepend a `## [5.3.0]` section to `plugins/spec-flow/CHANGELOG.md`.
**NOT in scope:** any further structural change to the root vs `.claude-plugin` plugin.json beyond setting
both to 5.3.0 (the bump itself resolves the prior skew — see ADR-3); content of Phases 1-5.
<!-- P2/P3 omitted: no file edited in this phase is a multi-step orchestration SKILL.md. -->
**Charter constraints honored in this phase:**
- NN-C-001 (plugin/marketplace version sync): `.claude-plugin/plugin.json` and the `marketplace.json`
  spec-flow entry are set to the same `5.3.0`.
- NN-C-009 (always bump; all version-bearing files): all four files in `releasing.md` are bumped to 5.3.0.
- NN-C-007 (CHANGELOG present, Keep a Changelog): a new `## [5.3.0] — <date>` section is prepended.
- CR-007 (config keys documented inline): no new config key is added; the existing inline-comment
  discipline in the touched JSON/MD files is retained (N/A-but-honored).

- [x] **[Implement]** Path edit + four-file version bump + CHANGELOG
  - Order: path-convention edit → plugin.json ×2 → marketplace.json → CHANGELOG. CHANGELOG last so it
    describes the whole piece.
  - Architecture constraints: all four version strings MUST match exactly (NN-C-001/009); the new version
    is `5.3.0` (minor — new capability, additive, NN-C-003). Consult `plugins/spec-flow/docs/releasing.md`
    — it is the authoritative four-file list.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/reference/v3-path-conventions.md`**
  - Anchor: layout diagram, line 21
  - Current:
    ```
    20  │               ├── plan.md
    21  │               ├── research/
    22  │               ├── learnings.md
    ```
  - Target: change line 21 from `│               ├── research/` to `│               ├── research.md`
    (directory → file). No path-table row exists for research (table lines 31-42), so the diagram is the
    only edit.
  - Pattern: (n/a — single token edit)
  - Done: the bare `research/` directory entry is gone; `research.md` appears in the diagram.
  - Verify: `grep -n 'research.md' v3-path-conventions.md` matches; `grep -nE '├── research/$' v3-path-conventions.md` returns nothing.

  **T-2: MODIFY `plugins/spec-flow/plugin.json`** (Copilot CLI descriptor — version-bearing file #1)
  - Anchor: `"version"` field (line 4)
  - Current:
    ```
    4    "version": "5.2.0",
    ```
  - Target: `"version": "5.3.0",` (this file was at 5.2.0 — the prior skew; the bump brings it current).
  - Pattern: (n/a — value edit)
  - Done: `jq -r .version plugins/spec-flow/plugin.json` → `5.3.0`.
  - Verify: `jq -r .version plugins/spec-flow/plugin.json` — Expected: `5.3.0`.

  **T-3: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`** (Claude Code descriptor — file #2)
  - Anchor: `"version"` field (line 4)
  - Current:
    ```
    4    "version": "5.2.1",
    ```
  - Target: `"version": "5.3.0",`
  - Done: `jq -r .version plugins/spec-flow/.claude-plugin/plugin.json` → `5.3.0`.
  - Verify: `jq -r .version plugins/spec-flow/.claude-plugin/plugin.json` — Expected: `5.3.0`.

  **T-4: MODIFY `.claude-plugin/marketplace.json`** (root marketplace registry — file #3)
  - Anchor: the `spec-flow` entry's `"version"` field
  - Current: `"version": "5.2.1",` (within the `name: spec-flow` object)
  - Target: `"version": "5.3.0",` for the spec-flow entry only.
  - Done: the spec-flow entry version is 5.3.0.
  - Verify: `jq -r '.plugins[]|select(.name=="spec-flow").version' .claude-plugin/marketplace.json` — Expected: `5.3.0`.

  **T-5: MODIFY `plugins/spec-flow/CHANGELOG.md`** (file #4)
  - Anchor: top of file, immediately below `## [Unreleased]` (lines 5-6) and above `## [5.2.1] — 2026-06-06`
  - Current:
    ```
    5  ## [Unreleased]
    6
    7  ## [5.2.1] — 2026-06-06
    ```
  - Target: insert a new section between `## [Unreleased]` and `## [5.2.1]`:
    ```
    ## [5.3.0] — <today's date YYYY-MM-DD>

    ### Added
    - **research agent + artifact contract:** new isolated Opus `research` agent (`agents/research.md`)
      and `reference/research-artifact.md` (the research.md schema, the `[RESEARCH-CONSUMED/ABSENT/UNAVAILABLE]`
      marker contract, the ≤2K return contract, and the covered-file definition).

    ### Changed
    - **One gathering pass per piece:** the `spec` skill now creates the worktree and dispatches the
      research agent before brainstorm (committing `research.md` before `spec.md`); L-10 becomes the
      `[RESEARCH-UNAVAILABLE]` fallback. The `plan` skill Phase 1 seeds `introspection.md` from
      `research.md` on the `[RESEARCH-CONSUMED]` path (skipping the full sweep) and falls back to the
      legacy sweep on `[RESEARCH-ABSENT]`. `v3-path-conventions.md` now lists `research.md` (file) not
      `research/` (directory).

    ### Fixed
    - **Version-bearing file sync:** the root `plugins/spec-flow/plugin.json` (Copilot descriptor) was at
      5.2.0 while the other descriptors were 5.2.1; this release brings all four files to 5.3.0 (NN-C-009).
    ```
    Use the actual current date for `<today's date>` (the orchestrator/operator supplies it at execute time).
  - Pattern (Keep a Changelog section, from CHANGELOG.md head):
    ```
    ## [5.2.1] — 2026-06-06

    ### Changed
    - **Execute pre-flight model check ...**
    ```
  - Done: a `## [5.3.0]` section exists at the top with ≥1 non-empty grouping.
  - Verify: `head -12 CHANGELOG.md` shows `## [5.3.0]` directly under `## [Unreleased]`.

- [x] **[Verify]** Confirm path edit, version sync, CHANGELOG, citations, and no superseded residue
  **Per-change checks:**
  - T-1: Run: `grep -c 'research.md' plugins/spec-flow/reference/v3-path-conventions.md` — Expected: ≥1; and `grep -nE '── research/$' plugins/spec-flow/reference/v3-path-conventions.md` — Expected: **no output**.
  - T-2/T-3/T-4 (versions): Run: `jq -r .version plugins/spec-flow/plugin.json; jq -r .version plugins/spec-flow/.claude-plugin/plugin.json; jq -r '.plugins[]|select(.name=="spec-flow").version' .claude-plugin/marketplace.json` — Expected: three lines, all `5.3.0`.
  - NN-C-001 sync: Run: `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[]|select(.name=="spec-flow").version' .claude-plugin/marketplace.json)` — Expected: **no output** (identical).
  - T-5 (CHANGELOG): Run: `grep -nE '^## \[5\.3\.0\]' plugins/spec-flow/CHANGELOG.md` — Expected: 1 match; and LLM-agent-step: confirm the 5.3.0 section sits directly under `## [Unreleased]` and has ≥1 bullet. — Expected: yes.
  **Superseded-ordinal anti-drift sweep (plan §2e):**
  - Sweep for superseded version strings in the three JSON descriptors (must be fully replaced):
    Run: `grep -nE '"version": "5\.2\.[01]"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json` — Expected: **no output** (no 5.2.0/5.2.1 version field survives in any descriptor).
  - Note: `CHANGELOG.md` legitimately RETAINS the historical `## [5.2.1]` / `## [5.2.0]` sections — do NOT sweep those away; the sweep targets only the live `"version":` fields in the three descriptors.
  **Cross-phase citation cross-check (AC-3, all three citations):**
  - Run: `grep -l 'reference/research-artifact.md' plugins/spec-flow/agents/research.md plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/skills/plan/SKILL.md` — Expected: all THREE file paths printed (agent + both skills cite the contract).
  **Phase-level check:**
  - Run (releasing.md four-file consistency): `grep -h '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` then compare to marketplace — Expected: all 5.3.0.
  - Failure: any descriptor not at 5.3.0; sync diff non-empty; a 5.2.x version field surviving in a descriptor; fewer than three citation files; `research/` still in the diagram.

- [x] **[QA]** Phase review
  - Review against: AC-7, AC-3 (final citation cross-check)
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

---

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | `research.md` written + committed before `spec.md` on the OK path; UNAVAILABLE commits none | COVERED | Phase 4 |
| AC-2 | `agents/research.md`: `name: research`, `model: opus`, ≤2K return + STATUS, no history, no secrets, no sub-dispatch | COVERED | Phase 2 |
| AC-3 | `reference/research-artifact.md` defines schema + markers + return + covered-file; agent & both skills cite it | COVERED | Phase 1 (schema), Phase 2/4/5 (citations), Phase 6 (cross-check) |
| AC-4 | spec skill reorders setup+research before brainstorm; UNAVAILABLE triggers + L-10-only-on-fallback + Conventions dual-source | COVERED | Phase 3 (brainstorm-procedure), Phase 4 (spec/SKILL.md) |
| AC-5 | plan Phase 1 CONSUMED: seed introspection.md, targeted top-up, staleness re-read; Phase 2 reader unchanged | COVERED | Phase 5 |
| AC-6 | plan Phase 1 ABSENT: legacy sweep + unchanged Phase 2 reader (backward-compat) | COVERED | Phase 5 |
| AC-7 | `v3-path-conventions.md` → `research.md`; minor version bump synced across files + CHANGELOG | COVERED | Phase 6 |

All ACs COVERED — no forward pointers required.

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `grep -nE 'git commit -m "research:\|git commit -m "spec:' plugins/spec-flow/skills/spec/SKILL.md` | `research:` line number < `spec:` line number |
| AC-1 | agent-step | Read `spec/SKILL.md` and confirm the UNAVAILABLE path commits no `research.md` | UNAVAILABLE path commits nothing |
| AC-2 | shell | `grep -E '^name:[[:space:]]*research$' plugins/spec-flow/agents/research.md && grep -E '^model:[[:space:]]*opus$' plugins/spec-flow/agents/research.md` | both match (one line each) |
| AC-2 | shell | `grep -niE 'as discussed\|from the brainstorm above\|you already know\|per my previous' plugins/spec-flow/agents/research.md; grep -nE 'Agent\(' plugins/spec-flow/agents/research.md` | no output for both (no history, no sub-dispatch) |
| AC-3 | shell | `grep -l 'reference/research-artifact.md' plugins/spec-flow/agents/research.md plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/skills/plan/SKILL.md` | all three paths printed |
| AC-3 | shell | `grep -c -e '## Brainstorm Inference Digest' -e '## Codebase Conventions' plugins/spec-flow/reference/research-artifact.md` | `2` |
| AC-4 | shell | `grep -n 'RESEARCH-UNAVAILABLE' plugins/spec-flow/skills/spec/SKILL.md` | ≥2 matches |
| AC-4 | agent-step | Read `spec/SKILL.md`: worktree/slug/research steps precede brainstorm step 1; all 3 UNAVAILABLE triggers enumerated; L-10 conditional | all true |
| AC-5 | shell | `grep -nE 'RESEARCH-CONSUMED: <N> files, <M> re-read' plugins/spec-flow/skills/plan/SKILL.md && grep -nE 'git log -1 --format=%H -- research.md' plugins/spec-flow/skills/plan/SKILL.md` | both match |
| AC-5 | agent-step | Read plan/SKILL.md: "seed introspection.md / do not run the full sweep when research.md present" + worked N/M example present; Phase 2 reader unchanged | all true |
| AC-6 | shell | `grep -nE 'RESEARCH-ABSENT: running full exploration' plugins/spec-flow/skills/plan/SKILL.md` | 1 match |
| AC-6 | agent-step | Read plan/SKILL.md: file-existence branch gates CONSUMED vs ABSENT; ABSENT preserves legacy sweep | both true |
| AC-7 | shell | `grep -c 'research.md' plugins/spec-flow/reference/v3-path-conventions.md; grep -nE '── research/$' plugins/spec-flow/reference/v3-path-conventions.md` | ≥1; and no output |
| AC-7 | shell | `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[]\|select(.name=="spec-flow").version' .claude-plugin/marketplace.json)` | no output (synced at 5.3.0) |
| AC-7 | shell | `grep -nE '^## \[5\.3\.0\]' plugins/spec-flow/CHANGELOG.md` | 1 match |

## Contracts

No TDD-track phases in this plan (all phases use the Implement track; `tdd: false`) — this section is
present for forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs.

The cross-component seam (`research.md`) is a **data schema**, not a boundary-crossing code interface; its
contract is centralized in `reference/research-artifact.md` (Phase 1) and guarded by the cross-phase
schema-consistency `[Verify]` in Phase 5 — see ADR-2.

## Parallel Execution Notes

All six phases run **serial**. Phase 1 → Phase 2 (the agent implements Phase 1's schema). Phase 3 → Phase
4 (`spec/SKILL.md` cites the updated `brainstorm-procedure.md`). Phase 5 depends only on Phase 1's schema.
Phase 6 is last (the version bump + CHANGELOG capture all prior changes).

Phases 4 (spec stage) and 5 (plan stage) touch **disjoint** file scopes (`skills/spec/SKILL.md` +
`reference/brainstorm-procedure.md` vs `skills/plan/SKILL.md`) and both depend only on the Phase 1/2
artifact contract, so they *could* form a Phase Group. They are kept **serial by deliberate choice** (see
Phase 4 `Why serial:`): the operator selected Standard mode (`fast: false`) so the load-bearing spec-skill
reorder receives per-phase Opus QA rather than group-deferred review. The wall-clock cost of serializing a
handful of markdown edits is negligible against the audit value.

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, the phase's `[Implement]` Change Specs (T-N), spec ACs, the phase's `[Verify]` commands, arch constraints, pattern blocks, and `introspection.md` (Dependency Map + Pattern Catalog for the phase's files) | Spec rationale, brainstorming history |
| Verify | The phase's `[Verify]` grep/jq/git output + LLM-agent-step results, spec ACs | Implementation reasoning |
| QA | Phase diff, spec, plan, PRD sections (FR-001, NFR-001, NFR-003, G-1) | Any agent conversation history |
| Refactor (Phase 4 only) | Current `spec/SKILL.md` (phase file only), the `[Verify]` commands, quality principles | Prior agent conversations |
