# Research — sonnet-coord (exec-ready PRD)

## Brainstorm Inference Digest

**Piece purpose.** Generalize the single execute-start "Model Check" prompt (bbcf58c, the Pre-flight section) into a **per-stage model policy** that (a) reports the model assigned to each stage, (b) flags only exceptions (FR-005 spike path; operator override), and (c) never silently upgrades a non-`[SPIKE]` phase to Opus (NN-P-005). Make the Final Review circuit-breaker limit (currently a hard-coded "3 full review cycles maximum") **configurable via `.spec-flow.yaml`** with a documented default that differs for doc-as-code vs TDD pieces (fixes the pi-011 hard-3 defect). Strengthen NFR-002: make all resume-critical coordinator state re-derivable from disk, emitting `[STATE-INCOMPLETE: <field>]` and escalating instead of guessing when a field is missing. Bump the plugin version in all four version-bearing files. The "5.2.1 plugin.json skew" the PRD cites is already corrected.

**Design constraints.**
- spec-flow is markdown + YAML + JSON only — no runtime deps, no test suite (charter-tools). All work lands in `skills/execute/SKILL.md`, `templates/pipeline-config.yaml`, the four version files, CHANGELOG, and possibly a new/edited `reference/*.md`.
- Additive / backward-compatible within the major (NN-C-003): new config keys must default to current behavior when absent. The model policy and configurable breaker are opt-out.
- Config keys are documented inline with comments in `templates/pipeline-config.yaml` (CR-007); execute reads keys at Step 0 with a "if absent → default" fallback.
- Agent frontmatter `name:` stays bare; agent prompts stay self-contained (NN-C-004 / NN-C-008). This piece edits the orchestrator skill, not agents — model is chosen at the `Agent({...})` dispatch site via the `model:` field, not in agent frontmatter.
- Bump version in ALL four files per `docs/releasing.md` (`plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md`) — new capability ⇒ minor bump (NN-C-009).

**Open ambiguities for the spec author.**
1. **Config key names + shape.** No precedent for a per-stage model map. Decide: a single scalar (e.g. `model_policy: sonnet|opus`) vs a per-stage map (`models: {coordinator: sonnet, implementer: sonnet, ...}`) vs leaving model assignment hard-coded at dispatch sites and only making the *policy report* + *exception flagging* the new behavior. The piece description says "assigns Sonnet by default … flags only exceptions" — this is mostly already true at dispatch sites (all mechanic agents are already `model: "sonnet"`; all thinking/QA agents are already `model: "opus"`). The new surface may be primarily the *reporting* and the *generalized exception-flag* rather than new wiring.
2. **Final Review breaker key.** Name + default. Current hard value is `3`. pi-011 says 3 is wrong for doc-as-code. Decide one key with a single default vs a per-track default (doc-as-code higher, TDD = 3). Note three *other* independent 3-iter breakers exist (mid-piece Opus pass, per-phase qa-phase, the SKILL-self-lint loop) plus a 2-attempt oracle budget — the spec must scope which breaker(s) become configurable (the PRD names only the Final Review one).
3. **`[STATE-INCOMPLETE: <field>]` surface.** What is the canonical list of resume-critical fields? Candidates: phase progress (plan.md checkboxes), Phase Group journal fields, amendment counters, `.orchestra-state.json` mid-piece-pass flag, model assignments, triage decisions (`.discovery-log.md`). Decide which are mandatory-on-disk vs recoverable-by-recompute, and where the escalation check runs.
4. **Where model assignments are persisted on disk.** AC-1 + AC-4 imply model assignments must not live only in transcript. Today the model is implicit in the SKILL text (deterministic per stage), so it IS re-derivable from disk (the skill file) — the spec must decide whether anything beyond the deterministic SKILL mapping needs persisting (e.g. an operator override of the model for the session).

## Codebase Conventions

- **Config-key idiom.** Every orchestrator knob is a top-level scalar in `templates/pipeline-config.yaml` with `auto`/`off`/`always`/`never` enums, a leading comment block listing valid values + the default, and a "default when key absent" rule in execute (NN-C-003). Examples: `refactor`, `phase_groups`, `deferred_commit`, `reflection`, `merge_strategy`, `tdd`. Deprecated keys are retained-but-ignored with a comment (`qa_iter2`). Execute reads them at Step 0 ("Read the `<key>` key from `.spec-flow.yaml`… default `<x>` when absent").
- **Model-dispatch pattern.** Model is set per-dispatch in the `Agent({ description, prompt, model })` call. **Sonnet** for all mechanics: `tdd-red` (411), `qa-tdd-red` (455), `implementer` (509), `verify` (688), `refactor` (749), `fix-code` (in QA/review loops), `qa-phase-lite` (1230). **Opus** for all thinking/deep-review: mid-piece QA pass (312), per-phase `qa-phase` full review (828), the 8–9 Final Review board agents (1520-1551), reflection agents (~1675). This already matches G-3 / NN-P-005 — the piece formalizes and *reports* it rather than rewiring it.
- **Circuit-breaker pattern.** Hard-coded integer caps stated inline as prose ("N iterations maximum / max", "2-attempt budget"), each escalating to human (never auto-advancing) on exhaustion. Canonical loop semantics live in `reference/qa-iteration-loop.md` (3-iter breaker = escalate on iter-3 must-fix; never iter-4). Breakers are NOT currently config-driven — making one configurable is a new pattern.
- **Version-bump convention.** Four files, all must print the same version (`docs/releasing.md` table); minor bump for new capability; CHANGELOG prepends `## [X.Y.Z] — YYYY-MM-DD` under `## [Unreleased]`. Current state: all four at **5.5.0, in sync** (verified). `/release spec-flow` cuts the tag *after* manual bump.
- **No automated tests.** Behavior is verified by the in-pipeline QA agents (qa-plan, qa-spec, the review board), by reading the SKILL prose for self-consistency, and by manual smoke runs of execute. There is no `tests/` dir for the plugin.

## Execute Model Policy & Pre-flight

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/execute/SKILL.md` (1863 lines) — the sole edit target for model policy. Key anchors: `## Pre-flight: Model Check` (lines 13–47, the bbcf58c Sonnet-class gate with the Override/Change-now/Cancel `ask_user` prompt + "Why Sonnet" rationale at 47); `## The Orchestrator Role` (112–121, "PURE CONDUCTOR"). Sonnet dispatch sites: 411, 455, 509, 688, 749, 1230. Opus dispatch sites: 312 (mid-piece QA), 828 (per-phase qa-phase full), 1520-1551 (board), 1550 (board model line), 1675-1676 (reflection). NN-P payload re-injection at 305.

### Dependency Map
**Dependency Map:** Pre-flight gate depends only on self-introspection of the active model (Claude Code) or the `<model_information>` system tag (Copilot CLI) — see lines 19–20; no config read. Mechanic agents (`agents/tdd-red.md`, `implementer.md`, `verify.md`, `refactor.md`, `fix-code.md`, `qa-phase-lite.md`) are dispatched Sonnet; deep-review agents (`qa-phase.md`, the 8 `review-board-*.md`, `reflection-*.md`) Opus. The API-encapsulation rule (108–110) makes execute the sole dispatcher of these agents — so a model policy declared here governs every dispatch. FR-005 spike path (not in this worktree yet) is the named exception that would dispatch a `[SPIKE]` phase on Opus.

### Test Landscape
**Test Landscape:** No automated tests. The model policy is verified by: (a) qa-plan/review-board reading the SKILL for internal consistency; (b) manual inspection that every `model:` field matches the declared policy; (c) the Pre-flight gate is exercised at every execute start. A spec author should add an explicit "policy table" in the SKILL that a reviewer can diff against the dispatch sites.

### Pattern Catalog
**Pattern Catalog:**
```
## Pre-flight: Model Check
Before any other step, verify the active model is a Sonnet-class model.
...
If the active model name does **not** contain `sonnet` (case-insensitive):
1. Use `ask_user` to block and prompt the user:
   > ⚠️ **Model mismatch.** Execute is tuned for a Sonnet-class model ...
   Choices:
   - "Override — proceed on [model-name]"
   - "Change now — I'll switch models"
   - "Cancel execute"
```
```
Agent({
  description: "Implement (Mode: TDD|Implement): Phase N",
  prompt: <composed, with Mode: flag on line 1>,
  model: "sonnet"
})
```
```
Agent({
  description: "QA: review Phase N (iter 1, full)",
  prompt: <composed blocks above, with "Input Mode: Full" on line 1>,
  model: "opus"
})
```

## Circuit Breakers (Final Review + peers)

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/execute/SKILL.md` — breakers: **Final Review fix loop** line 1580 "Circuit breaker: 3 full review cycles maximum" (this is the one pi-011 flags; the PRD's configurable-breaker target); mid-piece Opus pass line 320 "3 iterations maximum"; per-phase qa-phase line 794 / 846 "3-iter circuit breaker" / "3 iterations max, then escalate"; SKILL self-lint line 1514 "3-iteration circuit breaker"; Group Deep QA line 1278 "3-iter circuit breaker"; qa-phase-lite line 1230 "3-iter circuit breaker"; oracle "2-attempt budget" (422, 460, 520, 522, 535, 666, 715). Escalation Rules summary at 1815-1824. Canonical loop: `plugins/spec-flow/reference/qa-iteration-loop.md`.

### Dependency Map
**Dependency Map:** All breakers are independent inline integer caps; only the Final Review one (1580) is named for config-ization by the PRD. The per-phase/Group/lite/mid-piece breakers all defer to `reference/qa-iteration-loop.md` for *semantics* (escalate on iter-3 must-fix) but each states its own integer locally. If the spec makes the limit a config key, the Step 0 config-load section (lines 91, 230-236, 727) is where it would be read; the value must thread into the Step 3 Final Review fix loop (1566-1581). Decision needed: whether qa-iteration-loop.md's "3-iter" prose also becomes parameterized or stays the default for the per-phase gates.

### Test Landscape
**Test Landscape:** Verified by reading the SKILL + qa-iteration-loop.md for consistency and by the review board. pi-011 finding (hard-3 wrong for doc-as-code) is the empirical signal motivating the change; the spec should cite it. No runtime test — correctness is "the limit read from config threads to the loop, defaults to current behavior when absent."

### Pattern Catalog
**Pattern Catalog:**
```
- Re-triage the new findings (still deduplicate across reviewers).
- **Circuit breaker:** 3 full review cycles maximum.
- If the fix agent returns `Diff of changes: (none)` (all blocked), escalate.
```
```
The **3-iter circuit breaker** fires when iter-3 returns ≥ 1 must-fix finding. At that point
the orchestrator escalates to the human with the iter-3 must-fix list intact and does NOT
dispatch iter-4.
```
```
Read the `deferred_commit` key from `.spec-flow.yaml` ... (valid values: `auto`, `off`;
default `auto` when the key is absent or unset — per NN-C-003 backward-compat).
```

## File-based / Resume State (NFR-002)

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/execute/SKILL.md` `## Session Resumability` (1826-1841) + `## Escalation Rules` (1815-1824); `plugins/spec-flow/reference/deferred-commit-journal.md` (journal schema Tier 1, resume algorithm, recovery recipe). On-disk state sources: **plan.md `[x]` checkboxes** (phase/step progress — 1828-1832); **git HEAD / `git rev-parse HEAD`** (phase-start SHA recovery — 1832, 340); **Phase Group journal** (single fixed-filename JSON: `group_start_sha`, `group_letter`, `anchor`, `sub_phases[].status∈{pending,red-done,green,failed}`, `red_manifest_hashes` — journal.md lines 17-36); **`.orchestra-state.json`** (`{mid_piece_opus_pass_dispatched, at_phase}` — 277); **marker commit** secondary source (278); **amendment counters** recovered by counting committed amendments in branch history (1080); **`.discovery-log.md`** triage rows. The temp manifest `/tmp/spec-flow/phase-N-red-manifest.json` (436) is a non-durable clobber-detection aid.

### Dependency Map
**Dependency Map:** Resume re-derives position with NO transcript: plan.md checkboxes → first unchecked → resume; HEAD → phase-start SHA; journal → mid-group sub-phase status (1835-1841). Explicitly NOT persisted today (restart-from-scratch on resume): mid-QA-iteration fix diffs (1833 — restart iter-1), pre-flight snapshot/pre-decisions (1834 — re-run Step 1b, cheap). Amendment counters: not persisted in-memory but **recomputed from git history** (1080). The PRD's NFR-002 gap to close: ensure NOTHING resume-critical is transcript-only, and add the `[STATE-INCOMPLETE: <field>]` escalation when a required on-disk field is missing (today a missing journal is treated as fresh-start (1837), and missing fields are handled with defensive defaults at 932 — the spec must reconcile "defensive default + continue" vs "STATE-INCOMPLETE + escalate", since these conflict for some fields).

### Test Landscape
**Test Landscape:** Verified by reasoning over the resume algorithm in journal.md + the Session Resumability section, and by manual `/clear`-then-resume smoke runs. The acceptance check (AC-2) is operational: "a coordinator started in a fresh context after /clear resumes from the last clean checkpoint using only on-disk state, re-running no passing phase." No automated harness — the spec should phrase ACs as inspectable invariants (e.g. "for each resume-critical field X, name its on-disk home").

### Pattern Catalog
**Pattern Catalog:**
```
## Session Resumability
Progress tracked via [x] checkboxes in plan.md:
- Resume reads plan.md, finds first unchecked checkbox
- Completed phases skip
- In-progress phase resumes from first unchecked step
- Phase-start SHA is recovered on resume via `git rev-parse HEAD` ...
- Mid-QA-iteration state (fix diffs from prior iterations) is NOT persisted.
```
```
1. **Session-state file** (primary, survives history rewrites): read
   `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.orchestra-state.json`. If it contains
   {"mid_piece_opus_pass_dispatched": true, "at_phase": <N>}, the dispatch already fired ...
```
```
| `status` | One of `pending` | `red-done` | `green` | `failed`. ... |
| `red_manifest_hashes` | Map of path → git blob SHA (git hash-object -w) ... |
```
Defensive-default precedent that the spec must reconcile against STATE-INCOMPLETE (line 932):
```
**Defensive defaults.** ... Step 6c MUST handle missing fields defensively: when `source_agent`
is absent or empty, substitute the literal string `unknown` ... Do NOT halt or escalate on
missing fields — the operator can still triage the discovery from `row_text` alone.
```

## Config Schema & Version-bearing Files

### File Inventory
**File Inventory:** `plugins/spec-flow/templates/pipeline-config.yaml` (135 lines — the schema/template; new keys go here with CR-007 inline comments). NO root `.spec-flow.yaml` exists in this worktree (execute falls back to documented defaults). Version files (all currently **5.5.0, in sync** — no skew): `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (spec-flow entry; qa entry is 1.1.1, unrelated). `plugins/spec-flow/CHANGELOG.md` (`## [Unreleased]` then `## [5.5.0] — 2026-06-07`). `plugins/spec-flow/docs/releasing.md` (the four-file bump table + verify recipe). No `plugins/spec-flow/templates/charter/` config relevant here.

### Dependency Map
**Dependency Map:** execute Step 0 (line 91) reads `.spec-flow.yaml` from project root; per-key reads at 230 (`phase_groups`), 236 (`deferred_commit`), 727/1249 (`refactor`), 1666 (`reflection`), 1773 (`merge_strategy`), 1486 (`default_branch`). New keys (model policy + Final Review breaker limit) would be added to `templates/pipeline-config.yaml` AND read in execute at Step 0 with absent-default fallback. CHANGELOG version header must match all three plugin.json/marketplace versions (post-CHANGELOG re-verify rule at 1583-1599 enforces this during fix loops). `/release spec-flow` (the `release` skill) tags after manual bump.

### Test Landscape
**Test Landscape:** Version sync verified by the `grep '"version"'` recipe in releasing.md (lines 26-33) and by the post-CHANGELOG re-verification step (1597). Config-key correctness verified by qa-plan reading template + SKILL consistency. The "5.2.1 skew" the PRD asserts is STALE — all four files already read 5.5.0; the spec should drop the skew-fix as a no-op or re-scope it to "verify sync on touch."

### Pattern Catalog
**Pattern Catalog:**
```
# refactor: controls Step 5 (Refactor) dispatch
#   auto    — skip when Build reports oracle clean on first attempt ... (default)
#   always  — always run Refactor
#   never   — never run Refactor (useful for repetitive-pattern tracks like adapters)
refactor: auto
```
```
# deferred_commit: controls Phase Group commit model (new in v5.0.0)
#   auto — serial git-free section + ONE deferred work-commit at the group barrier; ... (default)
#   off  — pre-5.0.0 behavior ...
deferred_commit: auto
```
Version-bump table (docs/releasing.md):
```
| 1 | plugins/spec-flow/plugin.json              | "version" field → new version |
| 2 | plugins/spec-flow/.claude-plugin/plugin.json | "version" field → new version |
| 3 | .claude-plugin/marketplace.json            | spec-flow entry "version" → new version |
| 4 | plugins/spec-flow/CHANGELOG.md             | Prepend ## [X.Y.Z] — YYYY-MM-DD section |
```
