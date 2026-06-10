# Brainstorm Procedure

Invocation order:
1. Charter Context Loading Protocol — run first; outputs `charter_root`, `charter_snapshot`, `integration_cfg`
2. Research pass — the spec skill creates the worktree and dispatches the research agent before any questions; on `STATUS: OK` its `## Codebase Conventions` section supplies conventions; emits `[RESEARCH-UNAVAILABLE: <reason>]` if the agent returns `STATUS: BLOCKED`, errors, or `research.md` is missing or zero-length
3. **Deliberation pass** — after the research commit (or the `[RESEARCH-UNAVAILABLE]` fallback), the calling skill dispatches the 5-phase deliberation protocol (Phase A coordinator → Phase B parallel per-cluster viability [barrier] → Phase C synthesis [skipped when ≤1 cluster] → Phase D parallel adversarial board [barrier] → Phase E convergence), commits `deliberation.md`, and emits `[DELIBERATION-UNAVAILABLE: <phase>-<reason>]` on any of the 5 fatal triggers (falling back to current brainstorm). Depth resolved per `reference/deliberation-depth.md`; on `off`, emit `[DELIBERATION-SKIPPED: depth=off]` and run the current brainstorm. See `reference/deliberation-artifact.md` for markers/return contract.
4. L-10 Convention Context Scan — runs only on the `[RESEARCH-UNAVAILABLE]` path (fallback when research did not produce conventions)
5. Charter Constraint Identification Protocol — its Conventions Block consumes `research.md`'s `## Codebase Conventions` on the OK path, or L-10's output on the `[RESEARCH-UNAVAILABLE]` path
6. Remaining Core Brainstorm Building Blocks (C-2 always-run, C-3, Approach+Tradeoffs) — run during brainstorm session

## Charter Context Loading Protocol

### Algorithm
1. [shared] Resolve `charter_root` (`.github` or `.claude`) per `plugins/spec-flow/reference/charter-location.md`. If no `charter-*/SKILL.md` files exist under either root, set `charter_root = null` (a pre-charter project).
2. [shared] When `charter_root` is set, read the charter skill set: `<charter_root>/skills/charter-{architecture,non-negotiables,tools,processes,flows,coding-rules,integrations}/SKILL.md` (each when present).
3. [shared] Capture `charter_snapshot`: run `git log -1 --format=%ci` against each present `<charter_root>/skills/charter-<domain>/SKILL.md`. When `charter_root = null`, omit `charter_snapshot`.
4. [spec-only] Preserve the PRD-side product constraint source for later enumeration: `docs/prds/<prd-slug>/prd.md` `## Non-Negotiables (Product)` remains the authoritative `NN-P` source; small-change runs with no PRD-derived `NN-P` source.
5. [shared] As the final load step, read `.spec-flow.yaml` `integrations.issue_tracker`; when enabled, read `charter-integrations` from `<charter_root>/skills/charter-integrations/SKILL.md`, then resolve the hierarchy and sibling fields into `integration_cfg`; when disabled or absent, set `integration_cfg = null`.

<!-- Example: charter under .claude
  Input: project root contains .claude/skills/charter-non-negotiables/SKILL.md
  Step 1 [shared]: resolve per charter-location.md → charter_root = ".claude"
  Step 2 [shared]: read .claude/skills/charter-{architecture,non-negotiables,tools,processes,flows,coding-rules,integrations}/SKILL.md
  Step 3 [shared]: git log -1 --format=%ci .claude/skills/charter-architecture/SKILL.md → "2026-05-07"
                   repeat per domain → charter_snapshot = {architecture: "2026-05-07", non-negotiables: "2026-05-07", ...}
  Step 4 [shared]: read integrations.issue_tracker from .spec-flow.yaml; read .claude/skills/charter-integrations/SKILL.md
                   → integration_cfg = {enabled: true, project_key: "EIT", base_url: "https://...", hierarchy: [...]}
  Output: charter_root = ".claude", charter_snapshot = {...7 dates...}, integration_cfg = {...}
-->

### Fallback Behavior
- If no charter skills are present under either root, set `charter_root = null`, skip charter reads, and continue with `charter_snapshot` omitted.
- If `.spec-flow.yaml` is absent, default `docs_root = "docs"`, `worktrees_root = "worktrees"`, and `integration_cfg = null` unless the caller injects equivalent defaults.
- If `git log -1 --format=%ci` returns no history for a charter skill file, omit that domain from `charter_snapshot` and continue; if the integrations charter file is missing, keep `.spec-flow.yaml` values and fall back to the built-in defaults described by `plugins/spec-flow/reference/integration-capability-check.md`.

## Charter Constraint Identification Protocol

### Read Charter Files
1. [shared] Read all `NN-C-*` entries from `<charter_root>/skills/charter-non-negotiables/SKILL.md` when `charter_root` is set, or skip when `charter_root = null`. Do not present the full list to the user.
2. [shared] Read all `CR-*` entries from `<charter_root>/skills/charter-coding-rules/SKILL.md` when `charter_root` is set, or skip when `charter_root = null`. Do not present the full list to the user.
3. [spec-only] Read all `NN-P-*` entries from the `## Non-Negotiables (Product)` section of `docs/prds/<prd-slug>/prd.md`. Skip entirely for small-change (no PRD source).

### Infer Applicability from Brainstorm Context
1. [shared] Using the brainstorm discussion as context — what the change touches, what it creates, what systems it interacts with — determine which entries are genuinely applicable. An entry applies when its scope statement overlaps with the work described. An entry does not apply when the work clearly falls outside its scope. Mark as `[ambiguous]` only when applicability cannot be determined from brainstorm context alone.

### Present Concluded Set
1. [shared] Present only the **applicable set** — not the full charter list. For each entry in the set, show the ID and a one-line rationale connecting it to the work (e.g., "NN-C-009 — this change bumps the plugin version"). For any `[ambiguous]` entry, ask one targeted question to resolve it. Close with a single question: "Anything to add or remove?" Do not ask the user to enumerate, review, or confirm entries where applicability is already clear from context.

### Recording to Artifact Sections
1. [shared] Record the confirmed constraints into `### Non-Negotiables Honored` and `### Coding Rules Honored` in the output artifact (`spec.md` or `brief.md`), placing confirmed `NN-C` and any spec-only `NN-P` entries in the first section and confirmed `CR` entries in the second.

### Conventions Block
1. [shared] Surface the convention scan results before confirmation closes — on the research OK path these come from `research.md`'s `## Codebase Conventions` section; on the `[RESEARCH-UNAVAILABLE]` path they come from the standalone L-10 scan. Ask the user whether those empirical conventions should be required, and record confirmed conventions in `### Codebase Conventions`.

### Fallback Behavior
- If charter files are absent, infer from session context alone; present any entries that are clearly applicable and ask "Anything to add?" rather than presenting an empty list.
- If the PRD has no `## Non-Negotiables (Product)` section or exposes no `NN-P-*` entries, record no `NN-P` items and continue.
- If applicability remains genuinely ambiguous after one targeted question, include the entry conservatively and note it as included by default.

## Core Brainstorm Building Blocks

### L-10: Convention Context Scan
**Runs only on the `[RESEARCH-UNAVAILABLE]` path** — when the research agent produced no `research.md` (its `## Codebase Conventions` section is the OK-path source). On the `[RESEARCH-UNAVAILABLE]` path: before the first brainstorm question, dispatch an explore agent to scan 2–3 peer components of the same type and extract empirical conventions such as file structure, wrappers, naming patterns, and shared config idioms. Surface the resulting conventions list during charter-constraint confirmation. If no peer component exists, skip L-10 silently.

### C-2: Security Sub-Block (always-run)
[shared] This is an always-run sub-block: never silently skip it, and treat its five prompts as additive — they run after coverage is established and do not count toward or affect the completion criteria for either track.

**Amendment (v5.8.0, investigation-first):** a mandatory block (C-1, C-2, H-4 NFR sub-block, M-7 migration) MAY be auto-skipped ONLY when (a) deliberation explicitly concludes N/A for that dimension with reasoning logged in `deliberation.md` §Answered by Investigation AND (b) the calling skill surfaces the block name + N/A rationale to the user as a one-line note. Auto-skip is NOT silent skip — the user always sees the block name and rationale. When deliberation cannot conclude N/A, the block runs as **confirmation, not open discovery**: present deliberation's partial answer as a prefacing statement, then ask the confirmation question.

Inference-first: based on the brainstorm discussion, assess what the work touches across the five dimensions below and state the security profile. For dimensions where the work clearly doesn't apply, state "N/A — [reason]" without asking. Ask only about dimensions where applicability is genuinely ambiguous from the brainstorm context. Close with a single question: "Does this security profile look right?" rather than asking each dimension individually.

1. Trust boundaries — who calls this, from where, and with what trust level?
2. Sensitive data inventory — what data enters, exits, or is stored, and does any of it include PII, credentials, or regulated data?
3. Input validation surface — what user-controlled or external data enters the system, and where is it validated?
4. Auth/authz model — how is caller identity established, and how are permissions checked?
5. Secrets handling — are API keys, tokens, or credentials involved, and how are they managed?

### C-3: Floor Check Pattern
[shared] After each design sub-area, verify that the discussion contains one concrete example and one failure mode. Example: "A webhook payload enters the handler, is validated, then produces a normalized event for downstream processing." Failure mode: "The signature is missing or invalid, so the handler rejects the payload and records the rejection path." If either half is missing, ask one targeted follow-up and stop there; allow at most one follow-up per sub-area, and accept explicit `N/A` without pushback.

### Approach + Tradeoffs Confirmation
[shared] Before broad design exploration, propose 2–3 lightweight approaches and ask the user to choose a design anchor. After the design is complete, revisit the full trade-offs, confirm the chosen approach still stands, and explicitly call out any PRD-untraced scope the chosen approach introduces.

### Tier 2: Answer-Validation Loop [shared]
Active whenever a `deliberation.md` exists (depth ≠ off / not UNAVAILABLE / not SKIPPED). When no `deliberation.md` exists, Tier 2 does not fire.

1. After the operator answers a brainstorm question with **free-form input** (not selecting a presented option), **the calling skill itself** (the Opus authoring session, not a separate classifier agent) classifies the answer against `deliberation.md` §Viability Analysis path labels + §Answered by Investigation. **Decision rule:** it is a NEW ASSERTION when it names a design path/assumption/technology absent — verbatim or as a clear referent — from both. **Default bias toward NOT firing:** on an ambiguous match, treat as covered and do not fire (the cheaper miss is under-trigger).
2. On a new assertion, auto-fire (no confirmation prompt) `deliberation-validate` (see `agents/deliberation-validate.md`), scoped to that single assertion. The agent is dispatched with four injected inputs (per `agents/deliberation-validate.md` `## Injected Inputs`): (1) the verbatim operator assertion; (2) `deliberation.md`'s `## Viability Analysis` path labels + `## Answered by Investigation`; (3) applicable charter/NN constraints; (4) PRD/cross-FR context for the piece.
3. Branch on the verdict: **CONFIRM** → fold with cited evidence; **FLAG-HARD** → charter/NN violation, operator MUST revise, **no override**; **FLAG-SOFT** → operator MAY override → record the rationale.
4. Append `### Validation Round <n>` under `## Validation Rounds` in `deliberation.md` (cite `reference/deliberation-artifact.md` for schema); new conflicts become VOQ-tagged validated open questions feeding the brainstorm.
5. The loop is **human-paced**: it continues until the operator introduces no new assertion and signs off; **no artificial round cap** (NN-P-001).

<!-- Example: deliberation.md §Viability Analysis path labels = {"reuse research.md agent shape",
"greenfield agent"}; §Answered by Investigation covers {security: N/A}. Operator answers a question
with free-form "let's store deliberation.md in a Postgres table instead of the piece branch."
"Postgres table" is in neither set → NEW ASSERTION → auto-fire deliberation-validate.
Verdict = FLAG-HARD (violates NN-C-002 no-runtime-deps) → operator must revise, no override;
append Validation Round 1 (assertion / FLAG-HARD / NN-C-002 evidence / resolution: revised to piece-branch file).
Verdict = FLAG-SOFT example: operator answers "let's add a sync fallback for slow networks — adds ~2 weeks scope."
FLAG-SOFT (scope expansion, no NN violation) → operator may override; operator says "yes, include it, the deadline was already soft."
append Validation Round 2 (assertion / FLAG-SOFT / scope risk evidence / resolution: overridden-with-rationale).
Counter-example: operator answers "use the greenfield agent path" → matches a §Viability Analysis
label → accepted, no validation fires. Ambiguous answer "the simpler one" → bias: accept, do not fire. -->

### Fallback Behavior
- If the explore agent is unavailable for L-10, do a manual repo scan of 2–3 peer components with the normal search tools; if no relevant peers exist, continue with an empty conventions list.
- If inference concludes the work touches none of the C-2 dimensions (e.g., a config file or documentation change), state the N/A assessment and record it — no user confirmation required. If the work type is ambiguous, ask one targeted question to resolve it before stating the profile.
- If no meaningful alternative approaches exist because the piece is narrowly constrained, present the single viable approach, explain why alternatives collapsed, and still perform the end-of-session trade-off confirmation.
