## Brainstorm Inference Digest

**Piece purpose.** `spec-preresearch` adds a pre-brainstorm *deliberation* pass to the spec skill, introducing a new requirement FR-009 to the exec-ready PRD. Before the spec skill asks the user any brainstorm question, an isolated Opus deliberation agent evaluates 2–3 candidate approaches against the piece's PRD constraints, codebase conventions (from `research.md`), and charter rules — marking each VIABLE or NON-VIABLE with explicit reasoning. It writes a durable `deliberation.md` artifact containing: an evaluated-approaches block, an approach recommendation, a validated-open-questions list (questions NOT answerable from PRD/research/codebase), and an answered-by-investigation list (questions the agent resolved itself). The spec brainstorm then seeds step 1b (approach framing) from the recommendation rather than framing live, and restricts the questions it asks to the validated-open-questions list. Fallback marker `[DELIBERATION-UNAVAILABLE: <reason>]` runs spec in degraded mode (no grounded questions). This closes the gap between `research.md` (codebase facts, FR-001) and the user-facing Socratic dialogue (design decisions).

**Design constraints inferred (PRD + charter).**
- The deliberation agent is the **direct structural sibling of the existing `research` agent** (`plugins/spec-flow/agents/research.md`): isolated Opus pass, no sub-agents (CR-008), self-contained prompt with no conversation history (NN-C-008), durable artifact under `docs/prds/<prd-slug>/specs/<piece-slug>/`, structured ≤2K return digest with a `STATUS: OK | BLOCKED` final line, non-blocking fallback marker emitted by the spec skill.
- **Sequencing:** deliberation depends on `research.md` (dep: research-unify). It must run AFTER the research dispatch+commit (Phase 2 pre-brainstorm setup steps 4–6) and BEFORE step 1b approach framing / step 3 sub-areas. The agent consumes `research.md`'s `## Codebase Conventions` and cluster facts plus the PRD sections + charter.
- **Charter:** markdown + config only, no runtime deps (NN-C-002, NN-P implied via charter-tools); additive / backward-compatible within v5 major (NN-C-003); agent `name:` bare, no plugin prefix (NN-C-004, CR-001); always bump plugin version (NN-C-009 — currently 5.7.0 → 5.8.0); thin-orchestrator skill / narrow-executor agent split (CR-008); human sign-off on spec is never removed (NN-P-001) — deliberation pre-answers and validates questions but never replaces operator approval; thinking on Opus, mechanics on Sonnet (NN-P-005) — the deliberation agent is a thinking pass, so it MUST be `model: opus`.
- **A new reference contract doc is the likely seam.** Mirroring `reference/research-artifact.md` (the single source of truth for the research artifact), `spec-preresearch` will likely add a `reference/deliberation-artifact.md` defining the `deliberation.md` schema, the `[DELIBERATION-UNAVAILABLE]` marker, the VIABLE/NON-VIABLE block, and the return contract — cited (not restated) by both the agent and the spec skill, exactly as the research artifact is cited today.

**Open ambiguities for the brainstorm to resolve.**
1. **Artifact persistence.** `research.md` is committed to the piece branch before any spec write. Is `deliberation.md` also a committed durable artifact, or worktree-only/uncommitted? (FR-009 says "durable" — likely committed, with its own `git add`/commit step and a commit-failure trigger like research's trigger (d).)
2. **Marker name + emitter.** FR-009 specifies `[DELIBERATION-UNAVAILABLE: <reason>]`, emitted by the **spec** skill (parallel to `[RESEARCH-UNAVAILABLE]`). Confirm the four trigger conditions (BLOCKED, dispatch error, missing/zero-length artifact, commit failure) mirror research's marker contract verbatim.
3. **Interaction with existing step 1b and the L-10 / Approach+Tradeoffs building blocks.** Step 1b ("Approach framing", H-6) and the brainstorm-procedure "Approach + Tradeoffs Confirmation" block currently do *live* 2–3-approach framing. FR-009 says step 1b *reads the recommendation* instead. The brainstorm must decide how the deliberation recommendation supersedes/seeds these without removing the end-of-session trade-off confirmation (step 5 / M-8) or the human anchor choice.
4. **Question restriction scope.** "Questions asked are restricted to the validated-open-questions list" must be reconciled with always-run sub-blocks the spec skill cannot skip: C-1 PRD assumption audit, C-2 Security (always-run), C-3 floor checks, charter-constraint confirmation, NFR/migration sub-blocks. The brainstorm must clarify whether "validated-open-questions" filters only the *design* questions or also gates these always-run blocks.
5. **Degraded-mode behavior.** On `[DELIBERATION-UNAVAILABLE]`, does spec fall back to the *current* live step-1b framing (today's behavior), exactly as `[RESEARCH-UNAVAILABLE]` falls back to L-10? Likely yes — degraded mode = pre-FR-009 spec behavior.
6. **PRD authorship.** This piece "Adds FR-009 to the exec-ready PRD." FR-009 is NOT yet present in `docs/prds/exec-ready/prd.md` (confirmed via grep — 0 matches). The spec must cover writing the FR-009 section + AC into prd.md, mirroring FR-001's structure, AND wiring the agent + skill + reference doc.
7. **qa-spec / qa-plan touch.** Does any QA agent gain a new criterion (e.g., a surviving `[DELIBERATION-UNAVAILABLE]` is informational, not must-fix — unlike `[NEEDS CLARIFICATION]`)? Brainstorm should confirm whether markers are scanned by qa-spec.

## Codebase Conventions

Confirmed empirically by scanning peer agents (`research.md`, `spike.md`, `qa-spec.md`, `fix-doc.md`) and their reference contracts:

- **Isolated-Opus-agent file shape.** New thinking agents (`agents/research.md`, `agents/spike.md`) are single `.md` files with YAML frontmatter `name:` (bare, no prefix — NN-C-004/CR-001) + `description:` (starts "Internal agent — dispatched by spec-flow:<skill>. Do NOT call directly.") + `model: opus`. Body sections follow a fixed rhythm: `## Role / Single Task` → `## Injected Inputs (No History)` → `## Procedure`/`## Gathering Procedure` → `## Output Contract — Write <artifact>` → `## No Secrets` → `## Return Contract` ending with the `STATUS: OK | BLOCKED` final-line rule.
- **Dual-file twin convention is LEGACY-only.** Older agents ship both `<name>.md` and an identical `<name>.agent.md` twin (confirmed byte-identical via `cmp`). The two NEWEST agents — `research.md` and `spike.md` — ship ONLY the `.md` form, no `.agent.md` twin. Per `README.md` (Copilot CLI section), Copilot's loader scans both `*.md` and `*.agent.md` and dedupes by basename, so a twin is unnecessary. A new `deliberation.md` agent should ship as a single `.md` file (follow research/spike, not the legacy twins).
- **Reference-contract-as-single-source-of-truth idiom.** Each isolated agent has a paired `reference/<artifact>-contract` doc (`reference/research-artifact.md` for research; `reference/spike-agent.md` for spike) that is "the single source of truth" for the artifact location, schema, marker contract, and return contract. The agent file and the consuming skill both *cite, do not restate* this doc. Expect `spec-preresearch` to add `reference/deliberation-artifact.md` following this idiom.
- **Artifact location pattern.** All per-piece artifacts live at `docs/prds/<prd-slug>/specs/<piece-slug>/<artifact>.md` (research.md, spec.md, plan.md), with `<prd-slug>`/`<piece-slug>` resolved from `manifest.yaml`. Spikes nest one deeper: `.../specs/<piece-slug>/spikes/<id>.md`.
- **Marker convention.** Bracketed inline markers `[MARKER-NAME: <reason>]` emitted by the *skill* (not the agent) in orchestrator progress output, never written into the artifact. Each marker has exactly one designated emitter and a closed set of trigger conditions documented in the reference contract. `[RESEARCH-UNAVAILABLE]` is non-blocking (logs + falls back); `[NEEDS CLARIFICATION]`/`[PENDING-DECISION]` (open-bracket, no close) are must-fix by qa-spec.
- **Skill = thin orchestrator (CR-008).** The spec skill dispatches agents, evaluates the `STATUS` line, commits artifacts (`git add` + `git commit`), and branches on markers — it contains no design logic. The pre-brainstorm setup in `skills/spec/SKILL.md` Phase 2 (steps 1–6: gitignore, slug-validate, worktree, research dispatch, OK-path commit, UNAVAILABLE fallback) is the exact insertion site for the deliberation dispatch.
- **Versioning.** `plugins/spec-flow/plugin.json` and `.claude-plugin/plugin.json` both carry `version:` (currently `5.7.0`) and MUST stay in sync (NN-C-001) and be bumped on any change (NN-C-009). Each agent-adding piece bumps the minor (research-unify→5.3.0, spike-agent→5.7.0); this piece → likely 5.8.0.
- **Plan skill / `[RESEARCH-CONSUMED]`.** The plan skill counts "covered files" from `research.md` File Inventory blocks. `deliberation.md` is a spec-stage artifact; nothing indicates the plan skill consumes it (it consumes `research.md`). Confirm in brainstorm that deliberation is spec-only.

## Deliberation Agent + Artifact Contract Cluster

### File Inventory
**File Inventory:** The structural pattern to clone for the new deliberation agent and its contract:
- `plugins/spec-flow/agents/research.md` (5.8K) — the closest sibling; isolated Opus codebase-gathering agent. Section skeleton, frontmatter, and ≤2K/STATUS return contract are the template for a new `agents/deliberation.md`.
- `plugins/spec-flow/agents/spike.md` (2.9K) — second isolated-Opus precedent; shows the *mode*/*procedure*/*cite-don't-restate* compact form and BLOCKED-writes-no-artifact rule.
- `plugins/spec-flow/reference/research-artifact.md` — the single-source-of-truth contract (Location, structure, Marker contract, Return contract, Covered file). The template for a new `reference/deliberation-artifact.md`.
- `plugins/spec-flow/reference/brainstorm-procedure.md` — defines invocation order (research pass at step 2, L-10 at step 3, Approach+Tradeoffs block). FR-009's deliberation pass inserts here as a new step between research and the brainstorm building blocks.
- (new, to create) `plugins/spec-flow/agents/deliberation.md`, `plugins/spec-flow/reference/deliberation-artifact.md`, and the FR-009 section in `docs/prds/exec-ready/prd.md`.

### Dependency Map
**Dependency Map:** `agents/research.md` → cites `reference/research-artifact.md` for schema/markers/return-contract (defers all definitions to it). `skills/spec/SKILL.md` Phase 2 → dispatches the research agent, reads its `STATUS` line, commits `research.md`, branches on `[RESEARCH-UNAVAILABLE]`, and feeds `## Codebase Conventions` into the brainstorm-procedure Charter Constraint Conventions Block. The new deliberation agent will sit downstream of research (consumes `research.md` + PRD + charter), upstream of step 1b. `reference/research-artifact.md` is cited by the agent + spec skill + plan skill — the new `deliberation-artifact.md` would be cited by the deliberation agent + spec skill (NOT the plan skill — deliberation is spec-stage only). Charter dependency: agent + skill + reference doc all bind to NN-C-002/003/004/008/009, CR-001/008, NN-P-001/005 from `.claude/skills/charter-*/SKILL.md` (charter root is `.claude`; `charter-integrations` is absent).

### Test Landscape
**Test Landscape:** No automated unit/integration test harness exists for agent or skill markdown — this is a markdown-and-config plugin (charter-tools: markdown/YAML/JSON/POSIX bash only; NN-C-002 no runtime deps). The only executable test in the tree is `plugins/spec-flow/hooks/tests/test-lint-skill-coherence.sh` (a bash skill-coherence linter). Verification of doc-as-code pieces is therefore: (1) `qa-spec` / `qa-plan` adversarial review, (2) structural assertions (frontmatter present per CR-001, heading hierarchy per CR-009, marker grep, version-sync between the two `plugin.json` files per NN-C-001), and (3) branch-enumeration ACs for every conditional in the deliverable prose (FR-002 doc-as-code rule). Expect the plan to be doc-as-code "Implement" track phases with branch-enumeration ACs for the OK / DELIBERATION-UNAVAILABLE / commit-failure paths, not TDD-red phases. Precedent: research-unify shipped with `spec.md` + `plan.md` only (no committed `research.md` in its own spec dir), confirming these pieces are documentation+config edits verified by QA, not code with a test suite.

### Pattern Catalog
**Pattern Catalog:** The isolated-Opus-agent frontmatter + return-contract pattern to replicate (from `agents/research.md`):

```markdown
---
name: research
description: "Internal agent — dispatched by spec-flow:spec before brainstorm. Do NOT call directly. Isolated Opus codebase-gathering pass: ... returns a ≤2K-token structured digest. Dispatches no sub-agents."
model: opus
---
```

The mandatory final-line STATUS rule every isolated agent ends with (from `agents/research.md` / `agents/spike.md`):

```markdown
The **FINAL line** of your return must be exactly one of:

STATUS: OK
STATUS: BLOCKED

On `STATUS: BLOCKED`, include the reason before the status line and do NOT write a partial artifact.
```

The reference-contract marker block to mirror for `[DELIBERATION-UNAVAILABLE]` (from `reference/research-artifact.md`):

```markdown
### `[RESEARCH-UNAVAILABLE: <reason>]`
Emitted by the **spec** skill. Triggers when ANY of the following occur:
- The research agent returns `STATUS: BLOCKED` in its digest.
- The dispatch itself errors (agent process error, timeout, or other non-clean exit).
- `research.md` is missing or zero-length on the piece branch after a nominally successful dispatch.
- The `git add`/`git commit` of `research.md` fails ...
The marker is **non-blocking**: the spec skill logs it inline and continues with the ... fallback path.
```

## Spec Skill Brainstorm-Integration Cluster

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/spec/SKILL.md` (the orchestrator to modify) — Phase 2 pre-brainstorm setup block (steps 1–6: gitignore, slug-validation, worktree creation, research dispatch, OK-path commit, UNAVAILABLE fallback) is the insertion point for the deliberation dispatch. Brainstorm step 1b "Approach framing (H-6)" and step 3 sub-areas are what FR-009 re-seeds.
- `plugins/spec-flow/reference/brainstorm-procedure.md` — the invocation-order doc; its "Approach + Tradeoffs Confirmation" building block and L-10 scan are the procedures FR-009 must reconcile against.
- `plugins/spec-flow/agents/qa-spec.md` — review criteria; criterion 7 treats `[NEEDS CLARIFICATION]`/`[PENDING-DECISION]` as must-fix. A new marker contract must clarify `[DELIBERATION-UNAVAILABLE]` is informational/non-blocking (NOT must-fix), like `[RESEARCH-UNAVAILABLE]`.
- `plugins/spec-flow/templates/spec.md` — the spec output template (Goal / In-Scope / FR / NFR / Non-Negotiables Honored / Coding Rules Honored / AC / Technical Approach / Integration Coverage / Open Questions). Unchanged by this piece unless a new spec section is needed.
- `docs/prds/exec-ready/prd.md` — gains the FR-009 section (currently absent).
- `docs/prds/exec-ready/manifest.yaml` — the spec-preresearch piece entry (status `open`, dependencies `[research-unify]`).

### Dependency Map
**Dependency Map:** `skills/spec/SKILL.md` Phase 2 → today dispatches `agents/research.md`, commits `research.md`, then runs the brainstorm-procedure building blocks (Charter Constraint Identification, L-10 on the UNAVAILABLE path, C-1/C-2/C-3, step 1b H-6 approach framing, step 5 trade-off confirmation). FR-009 inserts a deliberation dispatch after the research OK/UNAVAILABLE branch and rewires step 1b to READ `deliberation.md`'s recommendation instead of framing live, and restricts step-3 design questions to the validated-open-questions list. The dispatch reads `research.md` (`## Codebase Conventions` + clusters), the piece PRD sections, and the charter — the exact same self-contained injection bundle the research agent receives (NN-C-008). `qa-spec.md` is downstream (reviews the resulting spec.md); its marker-scanning criterion 7 must be reconciled so the new non-blocking marker is not falsely flagged must-fix. Charter binding: NN-P-001 (sign-off preserved), NN-P-005 (deliberation = Opus thinking pass).

### Test Landscape
**Test Landscape:** Same as the prior cluster — no code test suite. Verification is `qa-spec` adversarial review of the modified `skills/spec/SKILL.md` prose plus the new agent/reference docs, structural lint, and branch-enumeration ACs for each conditional path the skill edits (research-OK→deliberation-dispatch, DELIBERATION-OK→seed-step-1b, DELIBERATION-UNAVAILABLE→degraded-live-framing). The existing QA iteration loop (`reference/qa-iteration-loop.md`, iter-until-clean with a 3-iter circuit breaker) and `agents/fix-doc.md` (targeted doc fixes, emits a `## Diff of changes`, does not commit) are the doc-fix mechanism. No new test infrastructure is introduced.

### Pattern Catalog
**Pattern Catalog:** The exact pre-brainstorm dispatch+commit+fallback pattern the deliberation step must mirror (from `skills/spec/SKILL.md` Phase 2, OK path):

```markdown
5. **OK path** — if the agent returns `STATUS: OK` and `research.md` is present and non-empty: commit it on the piece branch BEFORE any spec write:
   git add docs/prds/<prd-slug>/specs/<piece-slug>/research.md
   git commit -m "research: add <prd-slug>/<piece-slug> codebase research"
   ... If `git add` stages zero files ... treat this as trigger (d) of the UNAVAILABLE path below.
```

The non-blocking-fallback pattern to clone for `[DELIBERATION-UNAVAILABLE]` (from `skills/spec/SKILL.md` Phase 2):

```markdown
6. **UNAVAILABLE path** — surface `[RESEARCH-UNAVAILABLE: <reason>]` to the user ... and fall back **non-blocking** when ANY of these four triggers holds: (a) the agent returns `STATUS: BLOCKED`; (b) the dispatch errors; (c) research.md is missing or zero-length after dispatch; (d) the git add/git commit of research.md fails ...
```

The existing step-1b approach-framing block FR-009 rewires to read the recommendation (from `skills/spec/SKILL.md`):

```markdown
1b. **Approach framing** *(H-6)*: Propose 2-3 lightweight approaches and ask the user to choose one. This is not a deep trade-off discussion — just enough framing to know which approach to design for. The chosen approach becomes the design anchor for step 3; full trade-off analysis happens in step 5.
```
