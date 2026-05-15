---
charter_snapshot:
  architecture: 2026-04-21
  non-negotiables: 2026-05-01
  tools: 2026-04-21
  processes: 2026-04-21
  flows: 2026-04-21
  coding-rules: 2026-04-21
---

# Spec: pi-013-goal-exec

**PRD Sections:** FR-004, G-2, NFR-003
**Charter:** docs/charter/ (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** specced
**Dependencies:** pi-010-discovery, pi-012-single-branch

## Goal

Wire four Claude Code v2.1.139+ capabilities — `/goal` long-running sessions, background agent dispatch, `PushNotification` mobile alerts, and `Monitor` plan-progress streaming — into the spec-flow execute skill so a single operator-initiated run completes all phases, QA gates, review, and mandatory finding remediation without human intervention, stopping only at the merge gate.

## In Scope

- **GoalCreate integration in execute Step 0:** When `GoalCreate` is available, `execute` sets a goal at startup. The goal's completion condition is "Step 5 (Capture Learnings) committed on the piece branch." The goal runs autonomously through all phase loops, QA iterations, discovery triage (Step 6c), and Final Review fix-up. The merge gate (Step 5.5 / post-Final-Review human sign-off) is the hard stop — the goal does NOT auto-merge.
- **Background review-board agents:** All twelve review-board agent files (six `.md` + six `.agent.md` variants — see Technical Approach) gain `background: true` in their YAML frontmatter. The execute Final Review step is updated to describe TeammateIdle-based aggregation: dispatch all six review-board agents concurrently (already the current pattern), then arm a `TeammateIdle` handler that collects results and advances the orchestrator when the last background agent completes. A 10-minute timeout fallback fires as a hard stop if TeammateIdle never arrives.
- **PushNotification wiring:** Two notification classes:
  - *Informational (goal continues):* Step 6c discovery triage fires a push notification summarizing the discovery and chosen resolution (auto-mode proceeds without stopping).
  - *Action-required (goal stops):* Merge gate fires an action-required push notification prompting the operator to manually merge; the four hard-stop conditions each fire an action-required push notification before pausing.
- **Monitor for plan.md progress:** When `Monitor` is available, execute arms a monitor on `plan.md` at Step 0. The monitor emits one-line notifications per checkbox transition (`[ ]` → `[x]`). Rapid back-to-back writes are debounced (≥1 second between notifications for the same write session).
- **Backward-compat / capability detection:** A four-way independent capability probe at Step 0 detects GoalCreate, PushNotification, Monitor, and background agent support. Probe results are stored in orchestrator state variables. Each feature silently no-ops when the tool is absent. No behavior changes in environments lacking any or all four tools.
- **Version bump:** Minor version increment across all four version-bearing files (see Technical Approach).

## Out of Scope / Non-Goals

- `isolation: "worktree"` in agent frontmatter — dropped; adds complexity without sufficient benefit for this piece.
- Auto-merge or automated PR creation — the merge gate remains a hard human gate.
- Smoke testing on Claude Code CLI — spec review only (QA is spec-level, not functional).
- Background dispatch for non-review-board agents (implementer, tdd-red, verify, refactor) — only the Final Review board runs in background.
- Jira/issue-tracker integration changes — unrelated to this piece.
- Phase Group parallelism timing changes — deferred (backlog item).
- Final Review review-board triage markers — deferred (backlog item).
- TeammateIdle handling outside the Final Review aggregation context.

## Requirements

### Functional Requirements

- FR-1: When `GoalCreate` is available at execute Step 0, the orchestrator invokes it with the piece slug and a completion condition of "Step 5 (Capture Learnings) committed." The goal persists across turns until the completion condition is met or a hard-stop condition triggers.
- FR-2: The goal runs through all phase loops, QA iterations, Step 6c discovery triage (auto-mode), and Final Review fix-up without requiring operator input except at hard-stop conditions and the merge gate.
- FR-3: All twelve review-board agent files (six `.md` + six `.agent.md`) carry `background: true` in YAML frontmatter. The execute Final Review description specifies TeammateIdle-based aggregation of background reviewer results, including a 10-minute timeout fallback that treats non-arrival as a hard stop.
- FR-4: When `PushNotification` is available (`push_notif_available` probe result, stored at Step 0), Step 6c fires an informational push notification (non-blocking); the merge gate fires an action-required push notification (blocks goal advancement).
- FR-5: When `PushNotification` is available, each of the four hard-stop conditions fires an action-required push notification before halting.
- FR-6: When `Monitor` is available, execute Step 0 arms a monitor on `plan.md`. Each `[ ]` → `[x]` checkbox transition emits a one-line notification. The monitor debounces rapid writes (≥1 second between notifications for the same write session).
- FR-7: Capability detection at Step 0 is a four-way independent probe: GoalCreate, PushNotification, Monitor, and background agent support. Probe results are stored in four orchestrator state variables (`goal_available`, `push_notif_available`, `monitor_available`, `background_available`). Each feature is independently enabled or disabled; no feature depends on another being available.
- FR-8: When none of the four new tools is available, execute behavior is identical to pre-4.7.0 — no degraded-mode warnings, no behavioral change.
- FR-9: All four version-bearing files are incremented to the new minor version: `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and `plugins/spec-flow/CHANGELOG.md`.

### Non-Functional Requirements

- NFR-1: Capability probes at Step 0 add no perceptible overhead to execute startup on environments where tools are absent (NN-C-003: no behavior change when tools absent; all probes follow the "check availability → if available: do X; else: skip silently" pattern).
- NFR-2: Agent frontmatter additions (`background: true`) do not alter agent behavior on hosts that do not support background dispatch — frontmatter keys unknown to the host are ignored (NN-C-002: markdown + config only, no runtime code).
- NFR-3: All skill and agent file edits remain within the 500-LOC-per-file limit (NN-C-001). No new god files.
- NFR-4: The `background: true` addition to agent frontmatter is the only schema change to agent files — no other keys added or removed in this piece.

### Non-Negotiables Honored

**Project (NN-C — from `docs/charter/non-negotiables.md`):**
- NN-C-002 (plugin is markdown + config only): All deliverables are SKILL.md prose edits and agent `.md`/`.agent.md` frontmatter changes — plain markdown files. No runtime code introduced.
- NN-C-003 (backward compat within major version): All four features degrade silently to no-ops when tools are absent. Execute on environments lacking the new tools is behaviorally identical to pre-4.7.0. Ships as a minor version bump.
- NN-C-005 (hooks and probes silently no-op on missing deps): Capability probe at Step 0 follows this rule exactly — absent tool → feature disabled, no warning, no error.
- NN-C-008 (agent prompts self-contained): Review-board agent files already carry full context. Adding `background: true` to frontmatter does not change the prompt body. Execute SKILL.md additions reference agent file names (the self-contained unit), not external context.
- NN-C-009 (version bump on changes): All four version-bearing files updated in sync per `plugins/spec-flow/docs/releasing.md`: `plugin.json`, `.claude-plugin/plugin.json`, `marketplace.json`, `CHANGELOG.md`.

**Product (NN-P — from `docs/prds/shared/prd.md`):**
- NN-P-001 (all pipeline artifacts are plain markdown or YAML): All deliverables are SKILL.md prose edits and agent frontmatter changes in plain markdown files. The `background: true` key is a YAML value in a markdown frontmatter block. No binary formats or non-text artifacts introduced.
- NN-P-002 (two mandatory human gates — per-phase QA + end-of-piece review board): The GoalCreate integration explicitly documents Step 4 (Human Sign-Off) and the merge gate (Step 5.5) as hard stops where the goal pauses. The goal does NOT auto-merge and does NOT bypass per-phase QA gates. FR-2 captures this constraint; the PushNotification at Step 4 (added by this piece) surfaces the halt to the operator.
- NN-P-003 (backward compat within major version): Echoes NN-C-003 at the product level — same honor.

### Coding Rules Honored

- CR-001 (agent frontmatter schema — `name` + `description` in YAML): Adding `background: true` to all twelve review-board agent files. Existing `name:` and `description:` required keys are preserved; `background: true` is an additional optional key alongside the existing `model:` and `tools:` keys already permitted by CR-001.
- CR-004 (conventional-commits format with plugin scope): All commits produced during implementation use `feat(spec-flow):` or `chore(spec-flow):` prefix per conventional-commits format (e.g., `feat(spec-flow): wire GoalCreate, background agents, PushNotification, Monitor into execute`).
- CR-006 (CHANGELOG format — Keep a Changelog): The `CHANGELOG.md` update prepends a new `## [4.7.0] — YYYY-MM-DD` section in Keep a Changelog format, listing Added items for all four features.
- CR-008 (separation of concerns — thin-orchestrator skills, narrow-executor agents): All changes to execute SKILL.md remain within the orchestrator role. Capability probes, GoalCreate invocation, TeammateIdle registration, PushNotification calls, and Monitor arming are orchestration logic. No implementation detail added to the skill. Review-board agents are not modified beyond the `background: true` frontmatter key.
- CR-009 (markdown section headings follow semantic hierarchy): SKILL.md edits preserve the existing heading hierarchy (H2 for top-level steps, H3 for sub-steps). No heading levels are added, removed, or skipped.

## Acceptance Criteria

AC-1: Given execute runs on a Claude Code host where `GoalCreate` is available, When execute Step 0 completes, Then `GoalCreate` has been called with the piece slug and a completion condition of "Step 5 (Capture Learnings) committed."
  Independent Test: Read execute SKILL.md Step 0 block; confirm GoalCreate invocation prose is present with completion-condition language.

AC-2: Given execute runs on a host where `GoalCreate` is NOT available, When execute Step 0 completes, Then no GoalCreate call is made and execute proceeds identically to pre-4.7.0 with no warning emitted.
  Independent Test: Read execute SKILL.md Step 0 block; confirm capability probe and silent-fallback branch are present.

AC-3: Given the goal is active, When Step 6c discovery triage fires in auto-mode, Then an informational PushNotification is sent (if `push_notif_available` is true) and the goal continues without pausing.
  Independent Test: Read execute SKILL.md Step 6c block; confirm "informational" push notification call is present with non-blocking semantics.

AC-4: Given the goal is active, When the merge gate is reached (post-Final-Review, Step 5.5), Then an action-required PushNotification is sent (if `push_notif_available` is true) and goal execution halts awaiting operator action.
  Independent Test: Read execute SKILL.md merge-gate / Step 5.5 block; confirm action-required push notification and goal-stop semantics.

AC-5: Given the goal is active, When any of the four hard-stop conditions fires (QA 3-iter circuit breaker; amendment budget of 2/piece exhausted; auto-mode cannot resolve discovery; Final Review 3-iter circuit breaker), Then an action-required PushNotification is sent (if `push_notif_available` is true) and goal execution halts.
  Independent Test: Read execute SKILL.md for each of the four hard-stop locations; confirm action-required push notification and halt semantics at each.

AC-6: Given execute runs on a host where `PushNotification` is NOT available (`push_notif_available` is false), When Step 6c or a hard-stop condition or the merge gate fires, Then no PushNotification call is made and behavior is identical to pre-4.7.0.
  Independent Test: Read execute SKILL.md; confirm capability probe at Step 0 setting `push_notif_available` and silent-fallback (`if push_notif_available:` guard) at each notification site.

AC-7: Given execute runs on a host where `Monitor` is available, When execute Step 0 completes, Then a monitor is armed on `plan.md` for the active piece.
  Independent Test: Read execute SKILL.md Step 0 block; confirm Monitor arming prose is present with plan.md as the target.

AC-8: Given the Monitor is armed, When a `[ ]` → `[x]` checkbox transition is written to plan.md, Then a one-line notification is emitted within the monitor event stream. Rapid writes within the same session are debounced with a ≥1-second minimum between notifications.
  Independent Test: Read execute SKILL.md Monitor section; confirm notification-per-transition semantics with ≥1-second debounce described.

AC-9: Given execute runs on a host where `Monitor` is NOT available, When execute Step 0 completes, Then no monitor is armed and execute proceeds identically to pre-4.7.0.
  Independent Test: Read execute SKILL.md Step 0 block; confirm capability probe and silent-fallback branch are present.

AC-10: Given any review-board agent file (all twelve — six `.md` and six `.agent.md`), When its frontmatter is read, Then `background: true` is present.
  Independent Test: Read each of the twelve review-board agent files; verify `background: true` in YAML frontmatter for each; verify existing `name:` and `description:` keys are preserved.

AC-11: Given execute Final Review step description, When the TeammateIdle aggregation pattern is described, Then the SKILL.md prose specifies: dispatch all review-board agents concurrently, arm TeammateIdle handler, collect results when last background agent completes, then advance the orchestrator.
  Independent Test: Read execute SKILL.md Final Review section; confirm TeammateIdle aggregation prose is present.

AC-12: Given the SKILL.md Step 0 capability probe block, When the four probes are read, Then each probe is independent — the `goal_available`, `push_notif_available`, `monitor_available`, and `background_available` orchestrator state variables are set by separate branches that do not depend on each other.
  Independent Test: Read execute SKILL.md Step 0; confirm four separate if-available branches producing four distinct state variables.

AC-13: Given `plugin.json`, `.claude-plugin/plugin.json`, `marketplace.json`, and `CHANGELOG.md`, When all four are read, Then the version number in each has been incremented by a minor version relative to 4.6.2 (expected: 4.7.0), and all four values match exactly.
  Independent Test: Run the verification commands from `plugins/spec-flow/docs/releasing.md` (grep version fields + head CHANGELOG); confirm all four show 4.7.0.

AC-14: Given the execute Final Review step, When the TeammateIdle event has not fired within 10 minutes of the last review-board agent dispatch, Then the orchestrator treats this as a hard stop — an action-required PushNotification is sent (if `push_notif_available` is true) and goal execution halts awaiting operator action.
  Independent Test: Read execute SKILL.md Final Review section; confirm 10-minute timeout fallback prose is present alongside the TeammateIdle aggregation description, with hard-stop and action-required notification semantics.

## Technical Approach

**Files changed:**

1. `plugins/spec-flow/skills/execute/SKILL.md` — primary change surface:
   - **Step 0 additions (capability probe block):** Four independent probes executed at Step 0 startup. Results stored in orchestrator state:
     ```
     # Capability probe — four independent checks; results stored in state
     goal_available = (GoalCreate tool is available)
     push_notif_available = (PushNotification tool is available)
     monitor_available = (Monitor tool is available)
     background_available = (background agent dispatch is supported by the host)

     if goal_available:
       invoke GoalCreate(piece=<slug>, completion="Step 5 (Capture Learnings) committed on piece branch")
       record goal_id in orchestrator state
     # else: skip silently

     if monitor_available:
       arm monitor on docs/prds/<prd-slug>/specs/<piece-slug>/plan.md
       emit one-line notification per [ ] → [x] transition; debounce ≥1 second between events for same write session
     # else: skip silently
     ```
   - **Step 6c additions:** After auto-mode discovery resolution:
     ```
     if push_notif_available:
       send informational notification: "Discovery resolved: <summary> — goal continues"
     # goal does NOT stop here
     ```
   - **Step 5.5 / merge gate:** After Final Review board sign-off, before any merge action:
     ```
     if push_notif_available:
       send action-required notification: "<piece-slug> ready to merge — operator action required"
     # goal halts here; no auto-merge
     ```
   - **Hard-stop conditions (4 locations):** QA 3-iter circuit breaker, amendment budget (2/piece) exhausted, auto-mode escalation (cannot resolve discovery), Final Review 3-iter circuit breaker — each gets:
     ```
     if push_notif_available:
       send action-required notification: "Hard stop: <reason> — <piece-slug> needs operator attention"
     ```
   - **Final Review step:** Update concurrent dispatch description to include TeammateIdle aggregation and timeout fallback: "Dispatch all six review-board agents concurrently. Arm a TeammateIdle handler. When the last background agent completes and TeammateIdle fires, collect all results and advance the orchestrator. If TeammateIdle has not fired within 10 minutes of the last dispatch, treat as a hard stop: send action-required push notification (if available) and halt awaiting operator."

2. `plugins/spec-flow/agents/review-board-*.md` and `plugins/spec-flow/agents/review-board-*.agent.md` — all twelve files (architecture, blind, edge-case, prd-alignment, security, spec-compliance × 2 naming variants): Add `background: true` to YAML frontmatter. No prompt body changes. The `.agent.md` files are the Claude Code canonical format; the `.md` files are the Copilot CLI co-ship format. Both receive the key — Copilot CLI hosts that do not support background dispatch will ignore the unknown key per NN-C-002/CR-008.

3. Version bump across all four version-bearing files per `plugins/spec-flow/docs/releasing.md`:
   - `plugins/spec-flow/plugin.json` — `"version"`: 4.6.2 → 4.7.0 (Copilot CLI descriptor)
   - `plugins/spec-flow/.claude-plugin/plugin.json` — `"version"`: 4.6.2 → 4.7.0 (Claude Code descriptor)
   - `.claude-plugin/marketplace.json` — spec-flow entry `"version"`: current → 4.7.0 (note: this file may show drift from the plugin version; reconcile to 4.7.0)
   - `plugins/spec-flow/CHANGELOG.md` — prepend `## [4.7.0] — YYYY-MM-DD` section

**Capability probe pattern:**

The probe follows the established NN-C-005 pattern used by execute's existing pre-flight checks (e.g., model check). Each probe: check tool availability; if available, set state variable to `true`; else set to `false`. The probe emits no user-visible output on the absent path. Using stored state variables (`push_notif_available`, etc.) at notification sites rather than re-probing is cleaner and aligns with FR-7's intent that all four probes happen at Step 0.

**GoalCreate completion condition design:**

The completion string "Step 5 (Capture Learnings) committed on piece branch" maps to the observable git state: the `learnings:` commit on the `piece/<prd-slug>-<piece-slug>` branch. The goal does NOT complete at the merge gate — merge is operator-authorized only.

**TeammateIdle aggregation pattern:**

The current execute Final Review already dispatches all six reviewers "concurrently (ALL SIX concurrently via parallel Agent() calls, main thread blocks)." With `background: true`, the main thread is freed during dispatch. The TeammateIdle event fires when the last background agent completes. The SKILL.md description makes this explicit so the orchestrator waits for TeammateIdle before collecting results rather than blocking inline. The 10-minute timeout fallback exists because TeammateIdle only fires on successful agent completion — a crashed or timed-out agent may never signal, which would hang the orchestrator indefinitely without the fallback.

**Monitor debounce rationale:**

Plan.md may receive multiple rapid checkbox writes within a single phase commit (e.g., tdd-red + implementer batch-writing several checkboxes). Debouncing at ≥1 second prevents a notification flood while still emitting a timely event for each distinct write session.

**Edge cases:**

- *Pre-complete plan detection:* If execute is resumed on a plan that already has checkboxes checked (piece is being re-run mid-piece), GoalCreate fires anyway — the completion condition is the git commit state of Step 5, not checkbox count. No special handling needed.
- *Background reviewer failure (TeammateIdle timeout):* If a background review-board agent crashes or times out, TeammateIdle will not fire. The 10-minute timeout fallback (AC-14) catches this. The orchestrator fires an action-required push notification and halts. Covered as a hard stop in AC-5 and AC-14.
- *Monitor debounce on rapid writes:* Described above. The ≥1-second gate is a minimum; the monitor implementation may aggregate further. The spec requires "at least one notification per distinct write session," not "exactly one per checkbox."
- *GoalCreate on a partially-completed piece:* Described under pre-complete plan detection — same handling.

## Testing Strategy

- **Spec review only** (no smoke test required for this piece).
- qa-spec adversarial review of this spec.md covers: AC completeness against FRs, NN/CR coverage, backward-compat verifiability, edge case coverage.
- For each AC, the independent test is a prose read of the relevant SKILL.md block or agent frontmatter — verifiable by any reviewer without executing code.

## Resolved Questions

- **Background reviewer failure timeout:** 10 minutes before TeammateIdle fallback fires and triggers hard stop. Documented in SKILL.md prose and AC-14.
- **New version number:** 4.7.0 (minor bump from 4.6.2 per NN-C-009). All four version-bearing files updated.

## Explicitly Out of Scope / Deferred

- **Final Review circuit-breaker triage markers** (backlog item) — the 3-iter circuit breaker itself is an in-scope hard stop, but per-finding triage markers at Final Review are deferred. Rationale: too much scope for this piece; capture for a future PI.
- **Phase Group parallelism timing changes** (backlog item) — background dispatch enables parallel Phase Groups but orchestration changes are out of scope. Future piece.
- **TeammateIdle handler outside Final Review** — only wired for Final Review aggregation in this piece. Other potential uses (e.g., parallel implementer + tdd-red) are deferred.
