# Learnings — shared/pi-010-discovery (v3.2.0 — synchronous discovery triage)

## Patterns that worked well

**Phase Group dispatch for reflection agents.** Phase Group B ran two reflection agents (process-retro and future-opportunities) as concurrent sub-phases with disjoint file scopes. The group-level QA caught the schema isolation violation that QA-lite missed, confirming that the two-tier QA model (narrow sub-phase + deep group) does the right job — narrow is fast, deep is thorough.

**Sentinel detection with two conditions.** The empty-findings sentinel for reflection agents required both a prefix check (`(no concrete items surfaced`) AND an absence of `### Finding` subheadings. A prefix-only check produced false positives when a genuine finding's body happened to begin with the sentinel string. Adding the subheading guard made the rule unambiguous. The pattern generalizes: whenever a sentinel string can appear legitimately inside non-sentinel content, add a structural guard.

**Explicit commit content lists for all resolution paths.** Specifying exactly which files land in which commit (defer skill stages both backlog + discovery-log; amend path stages plan + discovery-log; fork path stages manifest + discovery-log) eliminated an entire class of audit-trail gaps. Every resolution commit is now self-contained: the backlog write and the audit row travel together.

**Structured invocation skipping confirmation.** The defer skill's structured invocation path skips the operator confirmation step because the upstream triage flow already collected operator intent. Final Review caught a prose error in the closing sentence that listed "step 6 to step 8" (skipping step 7), which would have caused an implementation to silently skip the discovery-log row. The two-condition description ("from step 4 → step 6 → step 7 → step 8 → step 9") is now unambiguous.

**Per-finding `.discovery-log.md` source-phase tokens.** Using literal string tokens (`final-review`, `step-4.5-reflection`) for end-of-piece triage events instead of numeric phase IDs means the log remains readable even when amendment phases shift numeric IDs. This is the right model for any triage event that doesn't correspond to a specific plan phase.

## Issues QA caught

**Write-before-confirm ordering bug in defer/SKILL.md.** The original workflow had step 5 (operator confirmation) listed after step 6 (file append). A structured invocation following the steps in order would have appended to the backlog before the operator could cancel. The fix swapped the steps; the closing sentence was also updated to list all steps explicitly so the "skip step 5" carve-out for structured invocations couldn't be misread as skipping step 7.

**Missing `.discovery-log.md` integration in defer and amend/fork paths.** The initial implementation of amend dispatch (Step 6c) staged `plan.md` and committed — but omitted `.discovery-log.md` from the `git add` line. The same omission appeared in the fork dispatch path. Both were caught by Final Review iter-1. The pattern: any resolution that produces a commit must stage the audit-trail row in the same commit.

**G9c fork-halt needed explicit G10 guard.** Step G9c (Group Discovery Triage) specified that a fork discovery halts execute, but the G10 description didn't state the inverse — that G10 only runs when G9c completes without a fork. Without the explicit guard, an implementation could interpret G10 as running unconditionally after G9c regardless of outcome. The fix added a single sentence to G10's precondition.

**Sentinel false-positive on leading blank line.** The first sentinel detection spec said "if the section body begins with `(no concrete items surfaced`" — but the agent's output can have a leading blank line before the sentinel. Stripping leading/trailing blank lines before the prefix check, and requiring the stripped result to be exactly one line, made the check robust.

**plan-amend/spec-amend env preconditions were agent-internal only.** Both agent templates described the environment as "no runtime required" without distinguishing between the agent's own runtime needs and the orchestrator's requirements. The fix added explicit `git ≥ 2.5` and `POSIX shell` entries under "required by the orchestrator that consumes this agent's diff" — making the contract readable from both sides.

**Step 1b stale description.** execute/SKILL.md's pre-flight section said "reflection agents themselves own the writes" — the pre-v3.2.0 pattern. The fix updated the description to match v3.2.0 routing: agents emit structured findings, the orchestrator routes each through Step 6c, and only the operator-chosen defer resolution writes to the target path via `/spec-flow:defer`.

## Recommendations for future specs

**Split at behavioral boundary, not LOC.** Phases 8 and 9 were the two retry-heavy phases. In both cases, the root cause was multiple distinct behavioral areas (AC matrix routing, deferred-finding surfacing, Build oracle escalations) bundled into a single Implement block. Future plans should treat each AC cluster as a phase boundary, even when the total LOC fits within budget. The plan skill brainstorm should ask "how many behaviors does this [Implement] block cover?" rather than "is this under 150 LOC?"

**Validate new mechanisms end-to-end during the piece that introduces them.** Step 6c was fully implemented but never exercised during this piece's own phases — no per-phase discoveries surfaced. The validation came via Final Review, not actual runtime exercise. For future pieces introducing new triage mechanisms, consider authoring a synthetic discovery (e.g., a plan note that intentionally cites a prerequisite that will be missing) so the new flow is dog-food validated before shipping.

**Attach sibling sub-phase schemas to QA-lite prompts.** Phase Group B.2's QA-lite approved a schema that used inline agent context from sibling sub-phase B.1 — a cross-contamination that violated the spec's isolation rule. The narrow reviewer had no visibility into the sibling's output contract. For Phase Groups, QA-lite dispatches should include the sibling sub-phases' declared output shapes in the prompt context.

**Consider a pre-filter Opus pass after iter-1 Final Review when must-fix count ≥ 5.** This piece had 9 must-fix findings in Final Review iter-1. The fix diff was then re-reviewed by all 5 reviewers in iter-2, which caught 4 more findings — most of which were fixable before the re-review if the fix diff had been pre-filtered. A lightweight pre-filter (Opus reads only the fix diff + the iter-1 findings, confirms all were addressed) could prevent re-submitting a fix diff with obvious remaining issues to 5 fresh reviewers.

**Upstream agents need `Estimated absorption size:` in their output.** Step 6c's auto-mode threshold cannot compute the absorption ratio when the discovery report lacks this field. All three key templates (qa-phase.md, implementer.md, AC matrix contract) should instruct agents to emit this field. This is the enabling work for auto-mode to actually auto-resolve small amendments without operator prompts in practice.
