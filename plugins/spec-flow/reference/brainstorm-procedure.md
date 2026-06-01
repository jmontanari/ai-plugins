# Brainstorm Procedure

Invocation order:
1. Charter Context Loading Protocol — run first; outputs `charter_variant`, `charter_snapshot`, `integration_cfg`
2. L-10 Convention Context Scan (from Core Brainstorm Building Blocks) — runs before any questions; outputs conventions list
3. Charter Constraint Identification Protocol — runs after L-10; uses L-10 results for conventions block
4. Remaining Core Brainstorm Building Blocks (C-2 always-run, C-3, Approach+Tradeoffs) — run during brainstorm session

## Charter Context Loading Protocol

### Algorithm
1. [shared] Detect `charter_variant`: if `.github/skills/charter-non-negotiables/SKILL.md` exists, set `charter_variant = "v4"`; else if `<docs_root>/charter/` exists, set `charter_variant = "v3"`; else set `charter_variant = "legacy"`.
2. [shared] Read the charter file set for the detected variant: `v4` reads `.github/skills/charter-{architecture,non-negotiables,tools,processes,flows,coding-rules,integrations}/SKILL.md` when present; `v3` reads `<docs_root>/charter/{architecture,non-negotiables,tools,processes,flows,coding-rules,integrations}.md` when present; `legacy` reads `<docs_root>/architecture/` when present.
3. [shared] Capture `charter_snapshot`: for `v4`, run `git log -1 --format=%ci` against each present `.github/skills/charter-<domain>/SKILL.md`; for `v3`, read each charter file's `last_updated:` front-matter; for `legacy`, omit `charter_snapshot`.
4. [spec-only] Preserve the PRD-side product constraint source for later enumeration: `docs/prds/<prd-slug>/prd.md` `## Non-Negotiables (Product)` remains the authoritative `NN-P` source regardless of `charter_variant`; small-change runs with no PRD-derived `NN-P` source.
5. [shared] As the final load step, read `.spec-flow.yaml` `integrations.issue_tracker`; when enabled, read `charter-integrations` from `.github/skills/charter-integrations/SKILL.md` for `v4` or `<docs_root>/charter/<charter_file>.md` for `v3` (default `integrations.md`), then resolve the hierarchy and sibling fields into `integration_cfg`; when disabled or absent, set `integration_cfg = null`.

<!-- Example: v4 project
  Input: project root contains .github/skills/charter-non-negotiables/SKILL.md
  Step 1 [shared]: detect v4 — .github/skills/charter-non-negotiables/SKILL.md exists → charter_variant = "v4"
  Step 2 [shared]: read .github/skills/charter-{architecture,non-negotiables,tools,processes,flows,coding-rules,integrations}/SKILL.md
  Step 3 [shared]: git log -1 --format=%ci .github/skills/charter-architecture/SKILL.md → "2026-05-07"
                   repeat per domain → charter_snapshot = {architecture: "2026-05-07", non-negotiables: "2026-05-07", ...}
  Step 4 [shared]: read integrations.issue_tracker from .spec-flow.yaml; read .github/skills/charter-integrations/SKILL.md
                   → integration_cfg = {enabled: true, project_key: "EIT", base_url: "https://...", hierarchy: [...]}
  Output: charter_variant = "v4", charter_snapshot = {...7 dates...}, integration_cfg = {...}
-->

### Fallback Behavior
- If no v4 or v3 charter files are present, set `charter_variant = "legacy"`, read `docs/architecture/` only when it exists, and continue with `charter_snapshot` omitted.
- If `.spec-flow.yaml` is absent, default `docs_root = "docs"`, `worktrees_root = "worktrees"`, and `integration_cfg = null` unless the caller injects equivalent defaults.
- If `git log -1 --format=%ci` returns no history for a v4 charter file, omit that domain from `charter_snapshot` and continue; if the integrations charter file is missing, keep `.spec-flow.yaml` values and fall back to the built-in defaults described by `plugins/spec-flow/reference/integration-capability-check.md`.

## Charter Constraint Identification Protocol

### Read Charter Files
1. [shared] Read all `NN-C-*` entries from `.github/skills/charter-non-negotiables/SKILL.md` when `charter_variant = "v4"`, from `<docs_root>/charter/non-negotiables.md` when `charter_variant = "v3"`, or skip when `charter_variant = "legacy"`. Do not present the full list to the user.
2. [shared] Read all `CR-*` entries from `.github/skills/charter-coding-rules/SKILL.md` when `charter_variant = "v4"`, from `<docs_root>/charter/coding-rules.md` when `charter_variant = "v3"`, or skip when `charter_variant = "legacy"`. Do not present the full list to the user.
3. [spec-only] Read all `NN-P-*` entries from the `## Non-Negotiables (Product)` section of `docs/prds/<prd-slug>/prd.md`. Skip entirely for small-change (no PRD source).

### Infer Applicability from Brainstorm Context
1. [shared] Using the brainstorm discussion as context — what the change touches, what it creates, what systems it interacts with — determine which entries are genuinely applicable. An entry applies when its scope statement overlaps with the work described. An entry does not apply when the work clearly falls outside its scope. Mark as `[ambiguous]` only when applicability cannot be determined from brainstorm context alone.

### Present Concluded Set
1. [shared] Present only the **applicable set** — not the full charter list. For each entry in the set, show the ID and a one-line rationale connecting it to the work (e.g., "NN-C-009 — this change bumps the plugin version"). For any `[ambiguous]` entry, ask one targeted question to resolve it. Close with a single question: "Anything to add or remove?" Do not ask the user to enumerate, review, or confirm entries where applicability is already clear from context.

### Recording to Artifact Sections
1. [shared] Record the confirmed constraints into `### Non-Negotiables Honored` and `### Coding Rules Honored` in the output artifact (`spec.md` or `brief.md`), placing confirmed `NN-C` and any spec-only `NN-P` entries in the first section and confirmed `CR` entries in the second.

### Conventions Block
1. [shared] Surface the L-10 convention scan results before confirmation closes, ask the user whether those empirical conventions should be required, and record confirmed conventions in `### Codebase Conventions`; this protocol assumes L-10 has already run.

### Fallback Behavior
- If charter files are absent, infer from session context alone; present any entries that are clearly applicable and ask "Anything to add?" rather than presenting an empty list.
- If the PRD has no `## Non-Negotiables (Product)` section or exposes no `NN-P-*` entries, record no `NN-P` items and continue.
- If applicability remains genuinely ambiguous after one targeted question, include the entry conservatively and note it as included by default.

## Core Brainstorm Building Blocks

### L-10: Convention Context Scan
[shared] Before the first brainstorm question, dispatch an explore agent to scan 2–3 peer components of the same type and extract empirical conventions such as file structure, wrappers, naming patterns, and shared config idioms. Surface the resulting conventions list during charter-constraint confirmation. If no peer component exists, skip L-10 silently.

### C-2: Security Sub-Block (always-run)
[shared] This is an always-run sub-block: never silently skip it, and treat its five prompts as additive — they run after coverage is established and do not count toward or affect the completion criteria for either track.

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

### Fallback Behavior
- If the explore agent is unavailable for L-10, do a manual repo scan of 2–3 peer components with the normal search tools; if no relevant peers exist, continue with an empty conventions list.
- If inference concludes the work touches none of the C-2 dimensions (e.g., a config file or documentation change), state the N/A assessment and record it — no user confirmation required. If the work type is ambiguous, ask one targeted question to resolve it before stating the profile.
- If no meaningful alternative approaches exist because the piece is narrowly constrained, present the single viable approach, explain why alternatives collapsed, and still perform the end-of-session trade-off confirmation.
